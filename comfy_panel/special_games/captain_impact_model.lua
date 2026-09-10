local Seed = require('comfy_panel.special_games.captain_impact_seed')

local Public = {}

local function active_snapshot()
    -- Keep the model module independent from the persistence module at load
    -- time.  The store is required lazily after all control-stage handlers
    -- have registered, avoiding a require cycle with match recording.
    local ok, Store = pcall(require, 'comfy_panel.special_games.captain_impact_store')
    if not ok or not Store or not Store.get_snapshot then
        return nil
    end
    local snapshot = Store.get_snapshot()
    if snapshot and snapshot.seed_version == Seed.model_version and snapshot.live_leaderboard then
        return snapshot
    end
    return nil
end

local function active_rating(player_name)
    local snapshot = active_snapshot()
    return snapshot and snapshot.ratings and snapshot.ratings[player_name], snapshot
end

local function ensure_runtime()
    storage.captain_impact_runtime = storage.captain_impact_runtime or {}
    local runtime = storage.captain_impact_runtime
    runtime.completed_games_by_player = runtime.completed_games_by_player or {}
    runtime.player_skill_delta = runtime.player_skill_delta or {}
    runtime.promoted_model_version = runtime.promoted_model_version or Seed.model_version
    return runtime
end

local function resolve_player_row(player_name)
    return Seed.players[player_name], player_name
end

local function logistic(x)
    x = tonumber(x) or 0
    if x >= 0 then
        local z = math.exp(-x)
        return 1 / (1 + z)
    end
    local z = math.exp(x)
    return z / (1 + z)
end

local function experience_basis(prior_games)
    local n = math.max(0, tonumber(prior_games) or 0)
    return -math.exp(-n / Seed.experience_tau)
end

function Public.get_seed()
    return Seed
end

function Public.get_player(player_name)
    local row = resolve_player_row(player_name)
    return row
end

function Public.get_rank(player_name)
    local row = active_rating(player_name)
    if row and row.rank then
        return row.rank
    end
    row = resolve_player_row(player_name)
    return row and row.rank or nil
end

function Public.get_amwi_pp(player_name)
    local row = active_rating(player_name)
    if row and row.amwi_pp ~= nil then
        return row.amwi_pp
    end
    row = resolve_player_row(player_name)
    return row and row.amwi_pp or nil
end

function Public.get_display(player_name)
    local live_row = active_rating(player_name)
    if live_row and live_row.amwi_pp ~= nil then
        local rank = live_row.rank and tostring(live_row.rank) or 'NR'
        local amwi = string.format('%+.1f pp', live_row.amwi_pp)
        local interval = string.format(
            '%.1f to %.1f pp',
            live_row.amwi_low_pp or live_row.amwi_pp,
            live_row.amwi_high_pp or live_row.amwi_pp
        )
        return {
            rank = rank,
            amwi = amwi,
            tooltip = string.format(
                'Prospective AMWI %s (approximate uncertainty %s); %d Captain Games, %d prospective.',
                amwi,
                interval,
                live_row.games or 0,
                live_row.prospective_games or 0
            ),
        }
    end
    local row = resolve_player_row(player_name)
    if not row then
        return {
            rank = 'NR',
            amwi = 'Unrated',
            tooltip = 'No published active-player AMWI rating. The runtime model uses the neutral skill prior plus the experience adjustment.',
        }
    end

    local rank = row.rank and tostring(row.rank) or 'NR'
    local amwi = row.amwi_pp and string.format('%+.1f pp', row.amwi_pp) or 'Unrated'
    local tooltip
    if row.amwi_pp then
        tooltip = string.format(
            'AMWI %+.1f pp (95%% bootstrap %.1f to %.1f pp); likely rank %.0f-%.0f; seed games %d',
            row.amwi_pp,
            row.amwi_low_pp or row.amwi_pp,
            row.amwi_high_pp or row.amwi_pp,
            row.rank_low or row.rank,
            row.rank_high or row.rank,
            row.games or 0
        )
    else
        tooltip = string.format('Not in the published active Top 100; seed games %d', row.games or 0)
    end
    return { rank = rank, amwi = amwi, tooltip = tooltip }
end

function Public.prior_captain_games(player_name)
    local runtime = ensure_runtime()
    local row = resolve_player_row(player_name)
    local seed_games = row and row.games or 0
    local local_games = runtime.completed_games_by_player[player_name] or 0
    local snapshot = active_snapshot()
    local shared_games = snapshot
            and snapshot.completed_games_by_player
            and snapshot.completed_games_by_player[player_name]
        or 0
    -- The local match is also present in the shared journal after export.  max
    -- prevents double counting while still allowing another server's games to
    -- advance the experience curve immediately after synchronization.
    return seed_games + math.max(local_games, shared_games)
end

function Public.base_skill_logodds(player_name)
    local row = resolve_player_row(player_name)
    return row and row.skill_logodds or Seed.default_skill_logodds
end

function Public.current_skill_logodds(player_name)
    local runtime = ensure_runtime()
    local snapshot = active_snapshot()
    local delta = snapshot and snapshot.player_skill_delta and snapshot.player_skill_delta[player_name]
        or runtime.player_skill_delta[player_name]
        or 0
    return Public.base_skill_logodds(player_name) + delta
end

function Public.experience_adjustment_logodds(player_name, prior_games)
    local n = prior_games
    if n == nil then
        n = Public.prior_captain_games(player_name)
    end
    return Seed.experience_penalty_logodds * experience_basis(n)
end

function Public.get_rating_breakdown(player_name)
    local row, source_name = resolve_player_row(player_name)
    local live_row = active_rating(player_name)
    local games = Public.prior_captain_games(player_name)
    local persistent = Public.current_skill_logodds(player_name)
    local experience = Public.experience_adjustment_logodds(player_name, games)
    local current = persistent + experience
    local reference = Seed.reference_current_skill_logodds or 0
    return {
        player_name = player_name,
        source_name = source_name,
        games = games,
        persistent_skill_logodds = persistent,
        experience_adjustment_logodds = experience,
        current_skill_logodds = current,
        reference_current_skill_logodds = reference,
        advantage_vs_reference_logodds = current - reference,
        amwi_pp = live_row and live_row.amwi_pp or row and row.amwi_pp or nil,
        amwi_low_pp = live_row and live_row.amwi_low_pp or row and row.amwi_low_pp or nil,
        amwi_high_pp = live_row and live_row.amwi_high_pp or row and row.amwi_high_pp or nil,
        rank = live_row and live_row.rank or row and row.rank or nil,
        rank_low = live_row and live_row.rank_low or row and row.rank_low or nil,
        rank_high = live_row and live_row.rank_high or row and row.rank_high or nil,
        reliability = live_row and live_row.reliability or row and row.reliability or nil,
    }
end

function Public.effective_player_logodds(player_name, prior_games)
    local n = prior_games
    if n == nil then
        n = Public.prior_captain_games(player_name)
    end
    return Public.current_skill_logodds(player_name) + Seed.experience_penalty_logodds * experience_basis(n)
end

-- The historical outcome model decomposes a player's roster contribution into
-- an extra-body term plus a player-specific residual.  In the extreme lower
-- tail (especially a completely new player with the shared newcomer penalty),
-- that fitted decomposition can extrapolate below zero.  That is acceptable as
-- a statistical residual but is a bad draft policy: selecting a human must not
-- make them "free" or award unlimited extra picks.
--
-- Impact Dynamic therefore uses a transparent POSITIVE MARGINAL VALUE floor
-- for turn allocation only.  AMWI and raw outcome prediction remain unchanged.
function Public.established_average_marginal_logodds()
    return Seed.count_coefficient + (Seed.reference_current_skill_logodds or 0)
end

function Public.minimum_draft_marginal_logodds()
    local average = Public.established_average_marginal_logodds()
    local fraction = tonumber(Seed.draft_min_player_fraction_of_established_average) or 0.5
    local floor = average * fraction
    -- Defensive fallback in case a future seed changes centering drastically.
    if floor <= 0 then
        floor = math.max(0.01, Seed.count_coefficient * fraction)
    end
    return floor
end

function Public.raw_player_marginal_logodds(player_name, prior_games)
    return Seed.count_coefficient + Public.effective_player_logodds(player_name, prior_games)
end

function Public.get_effort_percent(player_name)
    local special = storage.special_games_variables and storage.special_games_variables.captain_mode
    local effort = special and special.player_effort and special.player_effort[player_name]
    if special and special.draftFormat == 'impact_dynamic' then
        local frozen = special.frozen_player_effort and special.frozen_player_effort[player_name]
        local round = special.draft_effort_snapshot and special.draft_effort_snapshot[player_name]
        if frozen ~= nil then
            effort = frozen
        elseif special.pickingPhase and round ~= nil then
            effort = round
        end
    end
    effort = tonumber(effort) or 100
    effort = math.floor(effort + 0.5)
    if effort < 0 then
        effort = 0
    end
    if effort > 100 then
        effort = 100
    end
    return effort
end

function Public.can_change_effort(player_name)
    local special = storage.special_games_variables and storage.special_games_variables.captain_mode
    return special ~= nil
        and special.draftFormat == 'impact_dynamic'
        and not special.pickingPhase
        and not (special.frozen_player_effort and special.frozen_player_effort[player_name] ~= nil)
        and not (special.playerPickedAtTicks and special.playerPickedAtTicks[player_name] ~= nil)
        and not (storage.chosen_team and storage.chosen_team[player_name])
end

function Public.set_effort_percent(player_name, effort)
    if not Public.can_change_effort(player_name) then
        return false
    end
    local special = storage.special_games_variables.captain_mode
    special.player_effort = special.player_effort or {}
    special.player_effort[player_name] = math.max(0, math.min(100, math.floor((tonumber(effort) or 100) + 0.5)))
    return true
end

function Public.freeze_effort(player_name)
    local special = storage.special_games_variables and storage.special_games_variables.captain_mode
    if not special or special.draftFormat ~= 'impact_dynamic' then
        return
    end
    local effort = Public.get_effort_percent(player_name)
    special.frozen_player_effort = special.frozen_player_effort or {}
    if special.frozen_player_effort[player_name] == nil then
        special.frozen_player_effort[player_name] = effort
    end
end

-- Called before setting pickingPhase, including every later join draft.
function Public.lock_draft_efforts()
    local special = storage.special_games_variables.captain_mode
    if special.draftFormat ~= 'impact_dynamic' then
        return
    end
    for player_name, force_name in pairs(storage.chosen_team or {}) do
        if force_name == 'north' or force_name == 'south' then
            Public.freeze_effort(player_name)
        end
    end
    local snapshot = {}
    for _, player_name in ipairs(special.listPlayers) do
        snapshot[player_name] = Public.get_effort_percent(player_name)
    end
    special.draft_effort_snapshot = snapshot
end

function Public.get_model_snapshot()
    local snapshot = {}
    for key, value in pairs(Seed) do
        if key ~= 'players' then
            snapshot[key] = type(value) == 'table' and table.deepcopy(value) or value
        end
    end
    snapshot.promoted_model_version = ensure_runtime().promoted_model_version
    snapshot.role_offset_logodds = 0 -- Roles are recorded; no role model is deployed yet.
    local learned = active_snapshot()
    if learned then
        snapshot.active_learning = {
            version = learned.version,
            algorithm_version = learned.algorithm_version,
            games = learned.games,
            promotions = learned.promotions,
            rollbacks = learned.rollbacks,
            live_leaderboard = learned.live_leaderboard,
        }
    end
    return snapshot
end

function Public.draft_player_marginal_logodds(player_name, prior_games)
    local raw = Public.raw_player_marginal_logodds(player_name, prior_games)
    local floor = Public.minimum_draft_marginal_logodds()
    if raw < floor then
        return floor, true, raw, floor
    end
    return raw, false, raw, floor
end

-- Match-specific effort is intentionally conservative until fresh outcome data
-- can calibrate how strongly self-declared effort predicts performance. It does
-- not touch permanent skill or AMWI.
--
-- 100 effort -> 100% of full guarded draft value
--  75 effort ->  90%
--  50 effort ->  80%
--  25 effort ->  70%
--   0 effort ->  60%
--
-- The positive minimum-player floor remains underneath this multiplier, so even
-- an unrated/low-rated player at 0% effort can never become free.
function Public.effort_adjusted_draft_player_marginal_logodds(player_name, prior_games)
    local full_value, floor_applied, raw_value, floor_value =
        Public.draft_player_marginal_logodds(player_name, prior_games)
    local effort = Public.get_effort_percent(player_name)
    local min_multiplier = tonumber(Seed.effort_min_multiplier) or 0.60
    min_multiplier = math.max(0, math.min(1, min_multiplier))
    local multiplier = min_multiplier + (1 - min_multiplier) * (effort / 100)
    local effective = math.max(floor_value, full_value * multiplier)
    return effective, effort, full_value, floor_applied, raw_value, floor_value, multiplier
end

local function team_names(force_name)
    local result = {}
    for player_name, team in pairs(storage.chosen_team or {}) do
        if team == force_name then
            result[#result + 1] = player_name
        end
    end
    table.sort(result)
    return result
end

function Public.predict_names(north_names, south_names, role_offset_logodds)
    local north = north_names or {}
    local south = south_names or {}
    local count_eta = Seed.count_coefficient * (#north - #south)
    local skill_eta = 0
    for _, player_name in ipairs(north) do
        skill_eta = skill_eta + Public.effective_player_logodds(player_name)
    end
    for _, player_name in ipairs(south) do
        skill_eta = skill_eta - Public.effective_player_logodds(player_name)
    end
    local role_eta = tonumber(role_offset_logodds) or 0
    local eta = count_eta + skill_eta + role_eta
    return {
        eta = eta,
        p_north = logistic(eta),
        count_eta = count_eta,
        player_eta = skill_eta,
        role_eta = role_eta,
        north_count = #north,
        south_count = #south,
    }
end

function Public.predict_current_rosters(role_offset_logodds)
    return Public.predict_names(team_names('north'), team_names('south'), role_offset_logodds)
end

-- Draft-balance prediction uses the same raw outcome model plus a per-player
-- positive marginal floor.  For ordinary/strong players this is identical to
-- the raw model.  Only extreme-low / unrated cases receive a positive-policy
-- adjustment so no player can be drafted for zero or negative cost.
function Public.predict_draft_names(north_names, south_names, role_offset_logodds)
    local north = north_names or {}
    local south = south_names or {}
    local raw = Public.predict_names(north, south, role_offset_logodds)
    local floor_eta = 0
    local effort_eta = 0
    local north_floored = 0
    local south_floored = 0
    local north_reduced_effort = 0
    local south_reduced_effort = 0

    local function adjustments(player_name)
        local effective, effort, full_value, floor_applied, raw_value =
            Public.effort_adjusted_draft_player_marginal_logodds(player_name)
        local floor_delta = full_value - raw_value
        local effort_delta = effective - full_value
        return floor_delta, effort_delta, floor_applied, effort
    end

    for _, player_name in ipairs(north) do
        local floor_delta, effort_delta, floor_applied, effort = adjustments(player_name)
        floor_eta = floor_eta + floor_delta
        effort_eta = effort_eta + effort_delta
        if floor_applied then
            north_floored = north_floored + 1
        end
        if effort < 100 then
            north_reduced_effort = north_reduced_effort + 1
        end
    end
    for _, player_name in ipairs(south) do
        local floor_delta, effort_delta, floor_applied, effort = adjustments(player_name)
        floor_eta = floor_eta - floor_delta
        effort_eta = effort_eta - effort_delta
        if floor_applied then
            south_floored = south_floored + 1
        end
        if effort < 100 then
            south_reduced_effort = south_reduced_effort + 1
        end
    end

    local draft_adjustment_eta = floor_eta + effort_eta
    local eta = raw.eta + draft_adjustment_eta
    return {
        eta = eta,
        p_north = logistic(eta),
        raw_eta = raw.eta,
        raw_p_north = raw.p_north,
        count_eta = raw.count_eta,
        player_eta = raw.player_eta,
        role_eta = raw.role_eta,
        draft_floor_eta = floor_eta,
        effort_eta = effort_eta,
        draft_adjustment_eta = draft_adjustment_eta,
        north_floored = north_floored,
        south_floored = south_floored,
        north_reduced_effort = north_reduced_effort,
        south_reduced_effort = south_reduced_effort,
        north_count = raw.north_count,
        south_count = raw.south_count,
    }
end

function Public.predict_current_draft_rosters(role_offset_logodds)
    return Public.predict_draft_names(team_names('north'), team_names('south'), role_offset_logodds)
end

function Public.predict_candidate(player_name, picking_force, role_offset_logodds)
    local north = team_names('north')
    local south = team_names('south')
    if picking_force == 'north' then
        north[#north + 1] = player_name
    elseif picking_force == 'south' then
        south[#south + 1] = player_name
    else
        error('picking_force must be north or south')
    end
    return Public.predict_names(north, south, role_offset_logodds)
end

function Public.predict_draft_candidate(player_name, picking_force, role_offset_logodds)
    local north = team_names('north')
    local south = team_names('south')
    if picking_force == 'north' then
        north[#north + 1] = player_name
    elseif picking_force == 'south' then
        south[#south + 1] = player_name
    else
        error('picking_force must be north or south')
    end
    return Public.predict_draft_names(north, south, role_offset_logodds)
end

-- Candidate-specific consequence for the draft UI.
--
-- This answers the captain's operational question:
--   "If I take this player now, which team receives the NEXT pick?"
--
-- In a pure dynamic draft there is no fixed 1/2-pick round cap. If the same
-- team remains weaker after this pick it keeps the next pick. After that next
-- choice the consequence is recalculated again, so 3+ consecutive picks remain
-- possible if a team repeatedly chooses sufficiently weak players.
function Public.pick_consequence(player_name, picking_force, role_offset_logodds)
    local before = Public.predict_current_draft_rosters(role_offset_logodds)
    local after = Public.predict_draft_candidate(player_name, picking_force, role_offset_logodds)
    local raw_after = Public.predict_candidate(player_name, picking_force, role_offset_logodds)
    local draft_value, effort_percent, full_draft_value, floor_applied, raw_value, floor_value, effort_multiplier =
        Public.effort_adjusted_draft_player_marginal_logodds(player_name)

    local next_force
    if after.p_north < 0.5 then
        next_force = 'north'
    elseif after.p_north > 0.5 then
        next_force = 'south'
    else
        next_force = picking_force == 'north' and 'south' or 'north'
    end

    local p_team_after = picking_force == 'north' and after.p_north or (1 - after.p_north)
    local raw_p_team_after = picking_force == 'north' and raw_after.p_north or (1 - raw_after.p_north)
    return {
        before = before,
        after = after,
        raw_after = raw_after,
        picking_force = picking_force,
        next_force = next_force,
        keeps_next_pick = next_force == picking_force,
        p_picking_team_after = p_team_after,
        raw_p_picking_team_after = raw_p_team_after,
        p_north_after = after.p_north,
        balance_gap_pp = math.abs(after.p_north - 0.5) * 100,
        draft_player_marginal_logodds = draft_value,
        full_draft_player_marginal_logodds = full_draft_value,
        raw_player_marginal_logodds = raw_value,
        draft_floor_logodds = floor_value,
        draft_floor_applied = floor_applied,
        effort_percent = effort_percent,
        effort_multiplier = effort_multiplier,
        effort_adjustment_logodds = draft_value - full_draft_value,
    }
end

function Public.get_pick_consequence_display(player_name, picking_force, role_offset_logodds)
    local consequence = Public.pick_consequence(player_name, picking_force, role_offset_logodds)
    local next_caption = consequence.keeps_next_pick and '2+ PICKS' or '1 PICK'
    local team_percent = consequence.p_picking_team_after * 100
    local raw_percent = consequence.raw_p_picking_team_after * 100
    local guardrail_text = ''
    if consequence.draft_floor_applied then
        guardrail_text = string.format(
            ' Positive-value floor: raw marginal %.3f -> %.3f log-odds.',
            consequence.raw_player_marginal_logodds,
            consequence.full_draft_player_marginal_logodds
        )
    end
    local effort_text = string.format(
        ' Declared effort %d%% uses a provisional %.0f%% value multiplier: full guarded marginal %.3f -> effective draft marginal %.3f log-odds.',
        consequence.effort_percent,
        100 * consequence.effort_multiplier,
        consequence.full_draft_player_marginal_logodds,
        consequence.draft_player_marginal_logodds
    )
    return {
        caption = string.format(
            '%s | %.1f%%%s',
            next_caption,
            team_percent,
            consequence.draft_floor_applied and '*' or ''
        ),
        next_caption = next_caption,
        projected_team_win_percent = team_percent,
        tooltip = string.format(
            'If %s picks %s now: effort-adjusted draft-balance share %.1f%%; raw full-effort outcome-model win chance %.1f%%; next pick: %s (%s).%s%s',
            picking_force,
            player_name,
            team_percent,
            raw_percent,
            consequence.next_force,
            consequence.keeps_next_pick and 'you keep picking' or 'turn passes',
            guardrail_text,
            effort_text
        ),
        consequence = consequence,
    }
end

-- Dynamic-draft rule: whichever currently assembled team has lower guarded
-- draft-balance share receives the next pick. AMWI itself is NOT summed here.
-- The native additive model is used, with the positive marginal-value floor
-- applied only where the raw lower-tail extrapolation would make a player too cheap.
function Public.next_pick_force(previous_force)
    local prediction = Public.predict_current_draft_rosters(0)
    if prediction.p_north < 0.5 then
        return 'north', prediction
    elseif prediction.p_north > 0.5 then
        return 'south', prediction
    end
    return previous_force == 'north' and 'south' or 'north', prediction
end

function Public.mark_completed_game_players(north_names, south_names)
    local runtime = ensure_runtime()
    for _, player_name in ipairs(north_names or {}) do
        runtime.completed_games_by_player[player_name] = (runtime.completed_games_by_player[player_name] or 0) + 1
    end
    for _, player_name in ipairs(south_names or {}) do
        runtime.completed_games_by_player[player_name] = (runtime.completed_games_by_player[player_name] or 0) + 1
    end
end

return Public
