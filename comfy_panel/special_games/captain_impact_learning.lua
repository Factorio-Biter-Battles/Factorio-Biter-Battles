-- Deterministic outcome learner. No Factorio objects, network calls or random numbers.
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local Public = {}
Public.VERSION = 'online-outcome-v1'
Public.POLICY = {
    evaluation_games = 24,
    promotion_log_loss_gain = 0.002,
    rollback_log_loss_gap = 0.02,
    learning_rate = 0.16,
    max_player_step = 0.03,
    max_skill_delta = 1,
    shrinkage = 0.002,
    min_duration_ticks = 5 * 60 * 60,
    max_roster_size = 128,
    leaderboard_min_games = 20,
    leaderboard_context_games = 20,
    active_window_games = 200,
}

local function finite(x)
    return type(x) == 'number' and x == x and x > -math.huge and x < math.huge
end
local function clamp(x, low, high)
    return math.max(low, math.min(high, x))
end
local function logistic(x)
    if x >= 0 then
        return 1 / (1 + math.exp(-x))
    end
    local z = math.exp(x)
    return z / (1 + z)
end
local function skill(name, delta, games)
    local row = Seed.players[name]
    return (row and row.skill_logodds or Seed.default_skill_logodds)
        + (delta[name] or 0)
        - Seed.experience_penalty_logodds * math.exp(-games / Seed.experience_tau)
end
local function fresh_eval()
    return { games = 0, champion_loss = 0, candidate_loss = 0, champion_brier = 0, candidate_brier = 0 }
end

function Public.new_state()
    return {
        algorithm_version = Public.VERSION,
        seed_version = Seed.model_version,
        games = 0,
        champion = {},
        candidate = {},
        counts = {},
        information = {},
        last_seen = {},
        evaluation = fresh_eval(),
        rollback_evaluation = fresh_eval(),
        transitions = {},
        promotions = 0,
        rollbacks = 0,
        context_histogram = {},
    }
end

-- Journal records contain only the observations used by this version of the learner.
function Public.validate_observation(o)
    if type(o) ~= 'table' or o.schema_version ~= 1 or o.seed_version ~= Seed.model_version then
        return false, 'unsupported observation/seed version'
    end
    if
        type(o.match_id) ~= 'string'
        or #o.match_id == 0
        or #o.match_id > 256
        or not finite(o.order)
        or not finite(o.duration_ticks)
        or o.duration_ticks < Public.POLICY.min_duration_ticks
        or (o.winner ~= 'north' and o.winner ~= 'south')
        or (o.draft_regime ~= 'impact_dynamic' and o.draft_regime ~= 'classic_122')
    then
        return false, 'invalid match metadata'
    end
    local seen, count = {}, 0
    for _, force in ipairs({ 'north', 'south' }) do
        local rows = o[force]
        if type(rows) ~= 'table' or #rows == 0 or #rows > Public.POLICY.max_roster_size then
            return false, 'invalid roster'
        end
        for index, row in ipairs(rows) do
            if
                type(row) ~= 'table'
                or type(row.name) ~= 'string'
                or #row.name == 0
                or #row.name > 128
                or seen[row.name]
                or not finite(row.prior_games)
                or row.prior_games < 0
                or row.prior_games > 1000000
                or row.prior_games % 1 ~= 0
                or not finite(row.effort)
                or row.effort < 0
                or row.effort > 100
                or (index > 1 and rows[index - 1].name >= row.name)
            then
                return false, 'invalid/duplicate/unsorted player'
            end
            seen[row.name], count = true, count + 1
        end
        local entries = 0
        for key in pairs(rows) do
            if type(key) ~= 'number' or key % 1 ~= 0 or key < 1 or key > #rows then
                return false, 'sparse roster'
            end
            entries = entries + 1
        end
        if entries ~= #rows then
            return false, 'sparse roster'
        end
    end
    if count > Public.POLICY.max_roster_size then
        return false, 'roster too large'
    end
    return true
end

function Public.observation_from_match(match)
    if type(match) ~= 'table' or match.status ~= 'completed' or match.test_mode then
        return nil, 'not a real completed game'
    end
    if match.draft_regime ~= 'impact_dynamic' then
        return nil, 'automatic learner only processes Impact Dynamic games'
    end
    if
        not match.starting_roster
        or not match.final_roster
        or not finite(match.roster_locked_tick)
        or not finite(match.finished_tick)
    then
        return nil, 'missing locked roster or duration'
    end
    local model = match.starting_model_snapshot or match.model_snapshot
    if not model or model.model_version ~= Seed.model_version then
        return nil, 'different seed model'
    end
    local time = match.server_time_snapshot or {}
    local o = {
        schema_version = 1,
        seed_version = Seed.model_version,
        match_id = match.match_id,
        draft_regime = match.draft_regime,
        winner = match.winner,
        duration_ticks = match.finished_tick - match.roster_locked_tick,
        order = finite(time.secs) and (time.secs + (match.finished_tick - (time.tick or 0)) / 60)
            or match.finished_tick / 60,
        north = {},
        south = {},
    }
    for _, force in ipairs({ 'north', 'south' }) do
        local start, final = match.starting_roster[force], match.final_roster[force]
        if type(start) ~= 'table' or type(final) ~= 'table' or #start > #final then
            return nil, 'roster changed during game'
        end
        local final_names = {}
        for _, name in ipairs(final) do
            final_names[name] = true
        end
        for _, row in ipairs(start) do
            if not final_names[row.player_name] or row.connected == false then
                return nil, 'incomplete starting roster exposure'
            end
            o[force][#o[force] + 1] =
                { name = row.player_name, prior_games = row.prior_captain_games, effort = row.effort_percent or 100 }
        end
        table.sort(o[force], function(a, b)
            return a.name < b.name
        end)
    end
    for _, pick in ipairs(match.picks or {}) do
        if pick.tick and pick.tick > match.roster_locked_tick then
            return nil, 'late assignment without exposure model'
        end
    end
    local ok, reason = Public.validate_observation(o)
    return ok and o or nil, reason
end

function Public.fingerprint(o)
    local parts = {
        o.match_id,
        o.seed_version,
        o.draft_regime,
        o.winner,
        string.format('%.17g', o.order),
        tostring(o.duration_ticks),
    }
    for _, force in ipairs({ 'north', 'south' }) do
        parts[#parts + 1] = force
        for _, row in ipairs(o[force]) do
            parts[#parts + 1] = tostring(#row.name) .. ':' .. row.name .. ':' .. row.prior_games .. ':' .. row.effort
        end
    end
    return table.concat(parts, '|')
end

function Public.predict(delta, o)
    local eta = Seed.count_coefficient * (#o.north - #o.south)
    for _, row in ipairs(o.north) do
        eta = eta + skill(row.name, delta, row.prior_games)
    end
    for _, row in ipairs(o.south) do
        eta = eta - skill(row.name, delta, row.prior_games)
    end
    return logistic(eta), eta
end

local function evaluate(e, champion, candidate, y)
    local function loss(p)
        p = clamp(p, 1e-9, 1 - 1e-9)
        return -(y * math.log(p) + (1 - y) * math.log(1 - p))
    end
    e.games = e.games + 1
    e.champion_loss = e.champion_loss + loss(champion)
    e.candidate_loss = e.candidate_loss + loss(candidate)
    e.champion_brier = e.champion_brier + (champion - y) ^ 2
    e.candidate_brier = e.candidate_brier + (candidate - y) ^ 2
end

local function transition(state, kind, o, evaluation)
    state.transitions[#state.transitions + 1] = {
        kind = kind,
        match_id = o.match_id,
        games = state.games,
        evaluation = table.deepcopy(evaluation),
    }
    if #state.transitions > 32 then
        table.remove(state.transitions, 1)
    end
end

-- Predict first, score the unseen outcome, then train. The held-out comparison
-- measures the online learning policy; it is not an in-sample training score.
function Public.process(state, o)
    local ok, reason = Public.validate_observation(o)
    assert(ok, reason)
    local y = o.winner == 'north' and 1 or 0
    local champion_p, champion_eta = Public.predict(state.champion, o)
    local candidate_p = Public.predict(state.candidate, o)
    evaluate(state.evaluation, champion_p, candidate_p, y)
    if state.previous then
        evaluate(state.rollback_evaluation, champion_p, Public.predict(state.previous, o), y)
    end
    state.games = state.games + 1
    local n = #o.north + #o.south
    for bin, weight in pairs(state.context_histogram) do
        state.context_histogram[bin] = weight * 0.995
    end
    for _, force in ipairs({ 'north', 'south' }) do
        local sign = force == 'north' and 1 or -1
        for _, row in ipairs(o[force]) do
            local name = row.name
            local old = state.candidate[name] or 0
            local information = state.information[name] or 0
            local rate = Public.POLICY.learning_rate / math.sqrt(n) / math.sqrt(1 + information / 20)
            local step = clamp(
                rate * (sign * (y - candidate_p) - Public.POLICY.shrinkage * old),
                -Public.POLICY.max_player_step,
                Public.POLICY.max_player_step
            )
            state.candidate[name] = clamp(old + step, -Public.POLICY.max_skill_delta, Public.POLICY.max_skill_delta)
            state.information[name] = information + candidate_p * (1 - candidate_p)
            state.counts[name] = (state.counts[name] or 0) + 1
            state.last_seen[name] = state.games
            local offset = sign * champion_eta
                - skill(name, state.champion, row.prior_games)
                + Seed.reference_current_skill_logodds
            local bin = clamp(math.floor(offset * 2 + 0.5), -12, 12)
            state.context_histogram[bin] = (state.context_histogram[bin] or 0) + 1 / n
        end
    end
    local rollback = state.rollback_evaluation
    if state.previous and rollback.games >= Public.POLICY.evaluation_games then
        if
            rollback.champion_loss > rollback.candidate_loss + Public.POLICY.rollback_log_loss_gap * rollback.games
            and rollback.champion_brier > rollback.candidate_brier
        then
            state.champion = table.deepcopy(state.previous)
            state.candidate = table.deepcopy(state.previous)
            state.previous = nil
            state.rollbacks = state.rollbacks + 1
            transition(state, 'rollback', o, rollback)
            state.evaluation, state.rollback_evaluation = fresh_eval(), fresh_eval()
            return
        end
        state.rollback_evaluation = fresh_eval()
    end
    local e = state.evaluation
    if e.games >= Public.POLICY.evaluation_games then
        if
            e.candidate_loss < e.champion_loss - Public.POLICY.promotion_log_loss_gain * e.games
            and e.candidate_brier <= e.champion_brier
        then
            state.previous = table.deepcopy(state.champion)
            state.champion = table.deepcopy(state.candidate)
            state.promotions = state.promotions + 1
            state.rollback_evaluation = fresh_eval()
            transition(state, 'promotion', o, e)
        end
        state.last_evaluation = table.deepcopy(e)
        state.evaluation = fresh_eval()
    end
end

local function amwi(advantage, histogram)
    local sum, weight = 0, 0
    for bin = -12, 12 do
        local w = histogram[bin] or 0
        sum = sum + w * (logistic(bin / 2 + advantage) - logistic(bin / 2))
        weight = weight + w
    end
    return weight > 0 and 100 * sum / weight or 100 * (logistic(advantage) - 0.5)
end

function Public.snapshot(state, revision)
    local live = state.games >= Public.POLICY.leaderboard_context_games
    local snapshot = {
        schema_version = 1,
        seed_version = Seed.model_version,
        algorithm_version = Public.VERSION,
        version = Seed.model_version .. '+' .. Public.VERSION .. '-' .. revision,
        revision = revision,
        games = state.games,
        promotions = state.promotions,
        rollbacks = state.rollbacks,
        player_skill_delta = table.deepcopy(state.champion),
        completed_games_by_player = table.deepcopy(state.counts),
        live_leaderboard = live,
        ratings = {},
        leaderboard = {},
        transitions = table.deepcopy(state.transitions),
        validation = table.deepcopy(state.last_evaluation or state.evaluation),
        amwi_basis = live and 'prospective replacement contexts v1' or 'historical seed',
        policy = table.deepcopy(Public.POLICY),
    }
    local names = {}
    for name in pairs(Seed.players) do
        names[name] = true
    end
    for name in pairs(state.counts) do
        names[name] = true
    end
    local sorted = {}
    for name in pairs(names) do
        sorted[#sorted + 1] = name
    end
    table.sort(sorted)
    for _, name in ipairs(sorted) do
        local seed = Seed.players[name]
        local games = (seed and seed.games or 0) + (state.counts[name] or 0)
        local row = { player_name = name, games = games, prospective_games = state.counts[name] or 0 }
        if live then
            local advantage = skill(name, state.champion, games) - Seed.reference_current_skill_logodds
            local precision = 4 + 12 * (seed and seed.reliability or 0) + (state.information[name] or 0)
            local radius = 1.96 / math.sqrt(precision)
            row.amwi_pp = amwi(advantage, state.context_histogram)
            row.amwi_low_pp = amwi(advantage - radius, state.context_histogram)
            row.amwi_high_pp = amwi(advantage + radius, state.context_histogram)
            row.uncertainty_method = 'approximate diagonal information; not bootstrap'
            local active = state.games - (state.last_seen[name] or 0) <= Public.POLICY.active_window_games
            row.eligible = active
                and games >= Public.POLICY.leaderboard_min_games
                and ((seed and seed.rank ~= nil) or (state.counts[name] or 0) > 0)
        elseif seed then
            for _, key in ipairs({
                'rank',
                'rank_low',
                'rank_high',
                'amwi_pp',
                'amwi_low_pp',
                'amwi_high_pp',
                'reliability',
            }) do
                row[key] = seed[key]
            end
            row.eligible = seed.rank ~= nil
        end
        snapshot.ratings[name] = row
        if row.eligible then
            snapshot.leaderboard[#snapshot.leaderboard + 1] = row
        end
    end
    table.sort(snapshot.leaderboard, function(a, b)
        if a.amwi_pp ~= b.amwi_pp then
            return a.amwi_pp > b.amwi_pp
        end
        return a.player_name < b.player_name
    end)
    if live then
        for rank, row in ipairs(snapshot.leaderboard) do
            row.rank = rank
            local best, worst = 1, 1
            for _, other in ipairs(snapshot.leaderboard) do
                if other.player_name ~= row.player_name then
                    if other.amwi_low_pp > row.amwi_high_pp then
                        best = best + 1
                    end
                    if other.amwi_high_pp >= row.amwi_low_pp then
                        worst = worst + 1
                    end
                end
            end
            row.rank_low, row.rank_high = best, worst
        end
    end
    return snapshot
end

return Public
