-- Deterministic outcome learner. No Factorio objects, network calls or random numbers.
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local CurrentSeed = require('comfy_panel.special_games.captain_impact_current_seed')
local Public = {}
Public.VERSION = 'online-outcome-v3-current-pick-role-residual'
Public.POLICY = {
    evaluation_games = 24,
    promotion_log_loss_gain = 0.002,
    rollback_log_loss_gap = 0.02,
    learning_rate = 0.16,
    max_player_step = 0.03,
    max_skill_delta = 1,
    shrinkage = 0.002,
    -- A known role shares part of the outcome residual with that role's
    -- player-specific residual. The generic delta keeps most of the signal,
    -- while the role delta is deliberately conservative until it has evidence.
    role_learning_share = 0.35,
    role_secondary_credit = 1 / 3,
    max_role_delta = 0.75,
    role_shrinkage = 0.01,
    min_duration_ticks = 5 * 60 * 60,
    max_roster_size = 128,
    leaderboard_min_games = 20,
    leaderboard_context_games = 20,
    active_window_games = 200,
    pick_learning_share = 1.0,
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
local function model_value(key, impact)
    if impact then
        local value = Seed['impact_' .. key]
        if value ~= nil then
            return value
        end
    end
    return Seed[key]
end
local function pick_state_value(state, name)
    local row = CurrentSeed.players and CurrentSeed.players[name]
    local half_life = tonumber(CurrentSeed.pick_half_life_matches) or 300
    local seed_decay = half_life > 0 and 2 ^ (-(state.games or 0) / half_life) or 1
    local seed_weight = (row and tonumber(row.pick_evidence) or 0) * seed_decay
    local online_weight = state.pick_weights and state.pick_weights[name] or 0
    local total = seed_weight + online_weight
    if total <= 0 then
        return 0.5, 0
    end
    local seed_score = row and tonumber(row.pick_score) or 0.5
    local online_sum = state.pick_sums and state.pick_sums[name] or 0
    return (seed_score * seed_weight + online_sum) / total, total
end

local function idle_matches(state, name)
    local row = CurrentSeed.players and CurrentSeed.players[name]
    local historical = tonumber(CurrentSeed.historical_matches) or 0
    local current_index = historical + (state.games or 0) - 1
    local last_seen = state.last_seen_match_index and state.last_seen_match_index[name]
    local last_index
    if last_seen ~= nil then
        last_index = historical + last_seen - 1
    elseif row and row.last_match_index ~= nil then
        last_index = row.last_match_index
    end
    return last_index and math.max(0, current_index - last_index) or 0
end

local function skill(name, delta, games, impact, state)
    local players = impact and Seed.impact_players or Seed.players
    local row = players and players[name]
    local tau = tonumber(model_value('experience_tau', impact)) or Seed.experience_tau
    local penalty = tonumber(model_value('experience_penalty_logodds', impact)) or Seed.experience_penalty_logodds
    local value = (row and row.skill_logodds or Seed.default_skill_logodds)
        + (delta[name] or 0)
        - penalty * math.exp(-games / tau)
    if not impact then
        return value
    end
    local pick_score = pick_state_value(state or { games = 0 }, name)
    local pick_weight = tonumber(CurrentSeed.direct_pick_weight_logodds) or 0
    local half_life = tonumber(CurrentSeed.inactivity_half_life_matches) or 15
    local freshness = half_life > 0 and 2 ^ (-idle_matches(state or { games = 0 }, name) / half_life) or 1
    return (value + pick_weight * (pick_score - 0.5)) * freshness
end
local function valid_role(role)
    if role == nil then
        return false
    end
    for _, row in ipairs(Seed.roles or {}) do
        if row.key == role then
            return true
        end
    end
    return false
end
local function role_component(row, role_delta)
    if type(row) ~= 'table' or type(role_delta) ~= 'table' then
        return 0
    end
    local primary = valid_role(row.primary_role) and row.primary_role or nil
    local secondary = valid_role(row.secondary_role) and row.secondary_role or nil
    if not primary and not secondary then
        return 0
    end
    local primary_credit = tonumber(row.primary_role_credit) or 1
    local secondary_credit = secondary and (tonumber(row.secondary_role_credit) or Public.POLICY.role_secondary_credit) or 0
    local total = primary_credit + secondary_credit
    if total <= 0 then
        return 0
    end
    local values = role_delta[row.name] or {}
    return ((primary and (values[primary] or 0) or 0) * primary_credit
        + (secondary and (values[secondary] or 0) or 0) * secondary_credit) / total
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
        role_champion = {},
        role_candidate = {},
        counts = {},
        role_counts = {},
        information = {},
        role_information = {},
        last_seen = {},
        evaluation = fresh_eval(),
        rollback_evaluation = fresh_eval(),
        transitions = {},
        promotions = 0,
        rollbacks = 0,
        context_histogram = {},
        pick_sums = {},
        pick_weights = {},
        last_seen_match_index = {},
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
                or (row.primary_role ~= nil and not valid_role(row.primary_role))
                or (row.secondary_role ~= nil and not valid_role(row.secondary_role))
                or (row.primary_role ~= nil and row.secondary_role == row.primary_role)
                or (row.secondary_role ~= nil and row.primary_role == nil)
                or (row.primary_role_credit ~= nil and (not finite(row.primary_role_credit) or row.primary_role_credit < 0))
                or (row.secondary_role_credit ~= nil and (not finite(row.secondary_role_credit) or row.secondary_role_credit < 0))
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
    if o.pick_events ~= nil then
        if type(o.pick_events) ~= 'table' or #o.pick_events > Public.POLICY.max_roster_size then
            return false, 'invalid pick events'
        end
        local pick_seen = {}
        for index, event in ipairs(o.pick_events) do
            if
                type(event) ~= 'table'
                or type(event.name) ~= 'string'
                or #event.name == 0
                or pick_seen[event.name]
                or not finite(event.score)
                or event.score < 0
                or event.score > 1
                or (index > 1 and event.score > o.pick_events[index - 1].score + 1e-12)
            then
                return false, 'invalid pick event'
            end
            pick_seen[event.name] = true
        end
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
            o[force][#o[force] + 1] = {
                name = row.player_name,
                prior_games = row.prior_captain_games,
                effort = row.effort_percent or 100,
                primary_role = row.primary_role,
                secondary_role = row.secondary_role,
                primary_role_credit = row.primary_role_credit,
                secondary_role_credit = row.secondary_role_credit,
            }
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
    local final_names, captain_names = {}, {}
    for _, force in ipairs({ 'north', 'south' }) do
        for _, name in ipairs(match.final_roster[force] or {}) do
            final_names[name] = true
        end
        local captain = match.starting_captains and match.starting_captains[force]
        if captain then
            captain_names[captain] = true
        end
    end
    local picked, pick_names = {}, {}
    for _, pick in ipairs(match.picks or {}) do
        local chosen = pick.chosen_player and pick.chosen_player.player_name
        if
            pick.historical_choice_model
            and pick.captain_choice
            and not pick.community_picking
            and pick.phase == 'initial'
            and chosen
            and final_names[chosen]
            and not captain_names[chosen]
            and not picked[chosen]
        then
            picked[chosen] = true
            pick_names[#pick_names + 1] = chosen
        end
    end
    if #pick_names >= 2 then
        o.pick_events = {}
        for index, name in ipairs(pick_names) do
            o.pick_events[index] = { name = name, score = 1 - (index - 1) / (#pick_names - 1) }
        end
    else
        o.pick_events = {}
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
                .. ':' .. tostring(row.primary_role or '') .. ':' .. tostring(row.secondary_role or '')
        end
    end
    for _, event in ipairs(o.pick_events or {}) do
        parts[#parts + 1] = 'pick:' .. event.name .. ':' .. string.format('%.17g', event.score)
    end
    return table.concat(parts, '|')
end

function Public.predict(delta, o, role_delta)
    local impact = o.draft_regime == 'impact_dynamic'
    local count = tonumber(model_value('count_coefficient', impact)) or Seed.count_coefficient
    local eta = count * (#o.north - #o.south)
    for _, row in ipairs(o.north) do
        eta = eta + skill(row.name, delta, row.prior_games, impact, o._state) + role_component(row, role_delta)
    end
    for _, row in ipairs(o.south) do
        eta = eta - skill(row.name, delta, row.prior_games, impact, o._state) - role_component(row, role_delta)
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
    -- Older persisted states predate the pick signal and match-index maps.
    -- Initialize them before replaying a journal entry so upgrades remain safe.
    state.pick_sums = state.pick_sums or {}
    state.pick_weights = state.pick_weights or {}
    state.last_seen_match_index = state.last_seen_match_index or {}
    local y = o.winner == 'north' and 1 or 0
    o._state = state
    local champion_p, champion_eta = Public.predict(state.champion, o, state.role_champion)
    local candidate_p = Public.predict(state.candidate, o, state.role_candidate)
    o._state = nil
    evaluate(state.evaluation, champion_p, candidate_p, y)
    if state.previous then
        o._state = state
        local previous_p = Public.predict(state.previous, o, state.previous_role)
        o._state = nil
        evaluate(state.rollback_evaluation, champion_p, previous_p, y)
    end
    state.games = state.games + 1
    local pick_half_life = tonumber(CurrentSeed.pick_half_life_matches) or 300
    local pick_decay = pick_half_life > 0 and 2 ^ (-1 / pick_half_life) or 1
    for name, value in pairs(state.pick_sums) do
        state.pick_sums[name] = value * pick_decay
    end
    for name, value in pairs(state.pick_weights) do
        state.pick_weights[name] = value * pick_decay
    end
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
            local has_role = valid_role(row.primary_role) or valid_role(row.secondary_role)
            local role_share = has_role and Public.POLICY.role_learning_share or 0
            local step = clamp(
                rate * (1 - role_share) * (sign * (y - candidate_p) - Public.POLICY.shrinkage * old),
                -Public.POLICY.max_player_step,
                Public.POLICY.max_player_step
            )
            state.candidate[name] = clamp(old + step, -Public.POLICY.max_skill_delta, Public.POLICY.max_skill_delta)
            state.information[name] = information + candidate_p * (1 - candidate_p)
            state.counts[name] = (state.counts[name] or 0) + 1
            state.last_seen[name] = state.games
            state.last_seen_match_index[name] = state.games
            if has_role then
                local values = state.role_candidate[name] or {}
                local primary = valid_role(row.primary_role) and row.primary_role or nil
                local secondary = valid_role(row.secondary_role) and row.secondary_role or nil
                local primary_credit = tonumber(row.primary_role_credit) or 1
                local secondary_credit = secondary
                        and (tonumber(row.secondary_role_credit) or Public.POLICY.role_secondary_credit)
                    or 0
                local total = math.max(primary_credit + secondary_credit, 1)
                local function learn_role(role, credit)
                    if not role or credit <= 0 then
                        return
                    end
                    local role_old = values[role] or 0
                    local role_key = name .. ':' .. role
                    local role_information = state.role_information[role_key] or 0
                    local role_rate = Public.POLICY.learning_rate * role_share * credit / total
                        / math.sqrt(n) / math.sqrt(1 + role_information / 20)
                    local role_step = clamp(
                        role_rate * (sign * (y - candidate_p) - Public.POLICY.role_shrinkage * role_old),
                        -Public.POLICY.max_player_step,
                        Public.POLICY.max_player_step
                    )
                    values[role] = clamp(role_old + role_step, -Public.POLICY.max_role_delta, Public.POLICY.max_role_delta)
                    state.role_information[role_key] = role_information + candidate_p * (1 - candidate_p) * credit / total
                    state.role_counts[role_key] = (state.role_counts[role_key] or 0) + credit
                end
                learn_role(primary, primary_credit)
                learn_role(secondary, secondary_credit)
                state.role_candidate[name] = values
            end
            local offset = sign * champion_eta
                - skill(name, state.champion, row.prior_games, o.draft_regime == 'impact_dynamic', state)
                + Seed.reference_current_skill_logodds
            local bin = clamp(math.floor(offset * 2 + 0.5), -12, 12)
            state.context_histogram[bin] = (state.context_histogram[bin] or 0) + 1 / n
        end
    end
    for _, event in ipairs(o.pick_events or {}) do
        local name = event.name
        state.pick_sums[name] = (state.pick_sums[name] or 0) + event.score * (Public.POLICY.pick_learning_share or 1)
        state.pick_weights[name] = (state.pick_weights[name] or 0) + (Public.POLICY.pick_learning_share or 1)
    end
    local rollback = state.rollback_evaluation
    if state.previous and rollback.games >= Public.POLICY.evaluation_games then
        if
            rollback.champion_loss > rollback.candidate_loss + Public.POLICY.rollback_log_loss_gap * rollback.games
            and rollback.champion_brier > rollback.candidate_brier
        then
            state.champion = table.deepcopy(state.previous)
            state.candidate = table.deepcopy(state.previous)
            state.role_champion = table.deepcopy(state.previous_role or {})
            state.role_candidate = table.deepcopy(state.previous_role or {})
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
            state.previous_role = table.deepcopy(state.role_champion)
            state.champion = table.deepcopy(state.candidate)
            state.role_champion = table.deepcopy(state.role_candidate)
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
        player_role_skill_delta = table.deepcopy(state.role_champion),
        completed_games_by_player = table.deepcopy(state.counts),
        last_seen_match_index = table.deepcopy(state.last_seen_match_index),
        role_evidence = table.deepcopy(state.role_counts),
        pick_evidence = table.deepcopy(state.pick_weights),
        live_leaderboard = live,
        ratings = {},
        leaderboard = {},
        -- A provisional view is kept current from the first completed game.
        -- It is display-only until the confidence gate promotes the live view.
        provisional_leaderboard = {},
        transitions = table.deepcopy(state.transitions),
        validation = table.deepcopy(state.last_evaluation or state.evaluation),
        amwi_basis = live and 'prospective replacement contexts v1' or 'historical seed',
        policy = table.deepcopy(Public.POLICY),
    }
    local names = {}
    for name in pairs(Seed.impact_players) do
        names[name] = true
    end
    for name in pairs(CurrentSeed.players or {}) do
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
        local seed = Seed.impact_players[name]
        local games = (seed and seed.games or 0) + (state.counts[name] or 0)
        local row = {
            player_name = name,
            games = games,
            prospective_games = state.counts[name] or 0,
            role_ratings = {},
        }
        local role_values = state.role_champion[name] or {}
        for _, role in ipairs(Seed.roles or {}) do
            local key = role.key
            local evidence = state.role_counts[name .. ':' .. key] or 0
            row.role_ratings[key] = {
                skill_delta = role_values[key] or 0,
                games = evidence,
                eligible = evidence > 0,
            }
        end
        local pick_score, pick_evidence = pick_state_value(state, name)
        row.pick_score = pick_score
        row.pick_evidence = pick_evidence
        row.idle_matches = idle_matches(state, name)
        local inactivity_half_life = tonumber(CurrentSeed.inactivity_half_life_matches) or 15
        row.freshness_factor = inactivity_half_life > 0
                and 2 ^ (-row.idle_matches / inactivity_half_life)
            or 1
        row.effective_skill_logodds = skill(name, state.champion, games, true, state)
        row.provisional_amwi_pp = amwi(row.effective_skill_logodds - Seed.reference_current_skill_logodds, state.context_histogram)
        local provisional_eligible = (seed and seed.rank ~= nil) or (state.counts[name] or 0) > 0
        if provisional_eligible then
            snapshot.provisional_leaderboard[#snapshot.provisional_leaderboard + 1] = row
        end
        if live then
            local advantage = row.effective_skill_logodds - Seed.reference_current_skill_logodds
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
    table.sort(snapshot.provisional_leaderboard, function(a, b)
        if a.provisional_amwi_pp ~= b.provisional_amwi_pp then
            return a.provisional_amwi_pp > b.provisional_amwi_pp
        end
        return a.player_name < b.player_name
    end)
    for rank, row in ipairs(snapshot.provisional_leaderboard) do
        row.provisional_rank = rank
    end
    return snapshot
end

return Public
