local Impact = require('comfy_panel.special_games.captain_impact_model')
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local LearningStore = require('comfy_panel.special_games.captain_impact_store')
local Server = require('utils.server')
local Event = require('utils.event')

local Public = {}
local OUTPUT_FILE = 'bb-captain-impact/events.jsonl'
local DATA_SET = 'captain_impact_v1_games'
local SCHEMA_VERSION = 3

local function ensure_history()
    storage.captain_impact_history = storage.captain_impact_history or {}
    local history = storage.captain_impact_history
    history.schema_version = SCHEMA_VERSION
    history.next_match_number = history.next_match_number or 1
    history.games = history.games or {}
    history.cancelled_games = history.cancelled_games or {}
    history.pending_exports = history.pending_exports or {}
    history.failed_events = history.failed_events or {}
    history.persistence_errors = history.persistence_errors or {}
    history.live_metrics = history.live_metrics or { games = 0, log_loss_sum = 0, brier_sum = 0, correct = 0 }
    return history
end

local function report_failure(channel, match_id, err)
    local message = 'Captain Impact ' .. channel .. ' failed for ' .. tostring(match_id) .. ': ' .. tostring(err)
    local errors = ensure_history().persistence_errors
    errors[#errors + 1] = { channel = channel, match_id = match_id, tick = game.tick, error = tostring(err) }
    log(message)
end

local function write_event(event)
    local ok, err = pcall(function()
        local encoded = helpers.table_to_json(event)
        helpers.write_file(OUTPUT_FILE, encoded .. '\n', true, 0)
    end)
    if not ok then
        local failed = ensure_history().failed_events
        failed[#failed + 1] = table.deepcopy(event)
        report_failure('JSONL', event.match_id, err)
    end
end

local function new_event(event_type, payload)
    local event = payload or {}
    local current = ensure_history().current
    event.schema_version = SCHEMA_VERSION
    event.event_type = event_type
    event.tick = game.tick
    if current then
        current.event_index = (current.event_index or 0) + 1
        event.event_index = current.event_index
        event.match_id = current.match_id
        event.model_version = current.model_version
        event.draft_regime = current.draft_regime
    end
    write_event(event)
    return event
end

-- set_data(data_set, key, value) emits a wrapper command and returns no ack.
-- Retain failed submissions in save storage; success means dispatched, not confirmed remotely.
function Public.retry_pending_exports()
    local history = ensure_history()
    local ids = {}
    for match_id in pairs(history.pending_exports) do
        ids[#ids + 1] = match_id
    end
    table.sort(ids)
    for _, match_id in ipairs(ids) do
        local ok, err = pcall(Server.set_data, DATA_SET, match_id, history.pending_exports[match_id])
        if ok then
            history.pending_exports[match_id] = nil
        else
            report_failure('datastore submission', match_id, err)
        end
    end
    local failed = history.failed_events
    history.failed_events = {}
    for _, event in ipairs(failed) do
        write_event(event)
    end
end

local function captains()
    local special = storage.special_games_variables.captain_mode
    return { north = special.captainList[1] or false, south = special.captainList[2] or false }
end

local function roster_names()
    local roster = { north = {}, south = {} }
    for player_name, force_name in pairs(storage.chosen_team or {}) do
        if roster[force_name] then
            roster[force_name][#roster[force_name] + 1] = player_name
        end
    end
    table.sort(roster.north)
    table.sort(roster.south)
    return roster
end

local function player_snapshot(player_name)
    local special = storage.special_games_variables.captain_mode
    local player = game.get_player(player_name)
    local rating = Impact.get_rating_breakdown(player_name)
    local value, effort, full, floored, raw, floor, multiplier =
        Impact.effort_adjusted_draft_player_marginal_logodds(player_name)
    return {
        player_name = player_name,
        connected = player and player.connected or false,
        total_playtime_ticks = (storage.total_time_online_players or {})[player_name] or 0,
        player_info = (special.player_info or {})[player_name],
        group_tag = special.draftFormat ~= 'impact_dynamic' and player and player.tag or nil,
        rank = rating.rank or false,
        amwi_pp = rating.amwi_pp or false,
        effort_percent = effort,
        prior_captain_games = rating.games,
        rating = rating,
        draft_player_marginal_logodds = value,
        full_draft_player_marginal_logodds = full,
        raw_player_marginal_logodds = raw,
        draft_floor_logodds = floor,
        draft_floor_applied = floored,
        effort_multiplier = multiplier,
    }
end

function Public.begin_match(draft_regime)
    local history = ensure_history()
    if history.current then
        return history.current
    end
    Public.retry_pending_exports()
    local n = history.next_match_number
    history.next_match_number = n + 1
    local special = storage.special_games_variables.captain_mode
    local surface = game.surfaces[storage.bb_surface_name]
    local map_seed = surface and surface.map_gen_settings.seed or 0
    -- get_current_time() currently returns nil even when initialized; use the raw synchronized time.
    local time_data = Server.get_time_data_raw()
    local seed = special.teamAssignmentSeed or 0
    history.current = {
        schema_version = SCHEMA_VERSION,
        match_id = table.concat({
            'captain',
            tostring(time_data.secs or 'local'),
            tostring(map_seed),
            tostring(seed),
            tostring(game.tick),
            tostring(n),
        }, '-'),
        model_version = Seed.model_version,
        model_snapshot = Impact.get_model_snapshot(),
        draft_regime = draft_regime or special.draftFormat or 'classic_122',
        started_tick = game.tick,
        server_time_snapshot = table.deepcopy(time_data),
        map_seed = map_seed,
        team_assignment_seed = seed,
        referee = special.refereeName,
        test_mode = special.test_mode or false,
        draft_round = 0,
        picks = {},
        draft_rounds = {},
        captain_events = {},
        role_events = {},
        roles = {},
    }
    new_event('captain_game_started', { match = table.deepcopy(history.current) })
    return history.current
end

function Public.record_captains(decider)
    local current = ensure_history().current
    if not current then
        return
    end
    current.captains = captains()
    current.captain_events = current.captain_events or {}
    local row = { captains = table.deepcopy(current.captains), decider = decider, tick = game.tick }
    current.captain_events[#current.captain_events + 1] = row
    new_event('captains_updated', table.deepcopy(row))
end

function Public.record_draft_started()
    local current = ensure_history().current
    if not current then
        return
    end
    local special = storage.special_games_variables.captain_mode
    current.test_mode = special.test_mode or current.test_mode
    current.draft_round = (current.draft_round or 0) + 1
    Public.record_captains()
    current.draft_captains = current.draft_captains or table.deepcopy(current.captains)
    local row = Public.capture_pick_context(special.next_pick_force, nil, 'round_start')
    row.model_snapshot = Impact.get_model_snapshot()
    row.captain_players = {}
    for _, name in pairs(current.captains) do
        if name then
            row.captain_players[name] = player_snapshot(name)
        end
    end
    current.draft_rounds = current.draft_rounds or {}
    current.draft_rounds[#current.draft_rounds + 1] = row
    new_event('draft_round_started', table.deepcopy(row))
end

-- Capture synchronously BEFORE assignment/removal; never reconstruct alternatives afterwards.
function Public.capture_pick_context(force_name, picker_name, selection_type)
    local special = storage.special_games_variables.captain_mode
    local current = ensure_history().current
    local pool = {}
    for _, player_name in ipairs(special.listPlayers) do
        if not storage.chosen_team[player_name] then
            pool[#pool + 1] = player_snapshot(player_name)
        end
    end
    local prediction = Impact.predict_current_rosters(0)
    local draft_prediction = Impact.predict_current_draft_rosters(0)
    local current_captains = captains()
    return {
        picker = picker_name or false,
        captain = current_captains[force_name] or false,
        captains = current_captains,
        selection_type = selection_type or 'manual',
        captain_choice = selection_type == 'manual'
            and picker_name ~= nil
            and picker_name == current_captains[force_name],
        available_candidates = pool,
        rosters_before_pick = roster_names(),
        prediction_before_pick = prediction.p_north,
        draft_balance_before_pick = draft_prediction.p_north,
        raw_prediction_before = prediction,
        draft_prediction_before = draft_prediction,
        draft_round = current and current.draft_round or 0,
        phase = not special.initialPickingPhaseFinished and 'initial'
            or (special.prepaPhase and 'preparation' or 'in_game'),
        community_picking = special.communityPickingMode or false,
        groups_allowed = special.draftFormat ~= 'impact_dynamic' and special.captainGroupAllowed or false,
        group_limit = special.groupLimit,
        picker_sort = picker_name and special.ui_pick_sort and table.deepcopy(special.ui_pick_sort[picker_name]) or nil,
        tick = game.tick,
    }
end

function Public.record_pick(player_name, force_name, context)
    local current = ensure_history().current
    if not current then
        return
    end
    local row = table.deepcopy(context)
    local chosen = player_snapshot(player_name)
    -- The chosen record uses exactly the values in the pre-pick alternatives when available.
    for _, candidate in ipairs(row.available_candidates) do
        if candidate.player_name == player_name then
            chosen = table.deepcopy(candidate)
            break
        end
    end
    row.chosen_player = chosen
    row.player_name = player_name
    row.force = force_name
    row.pick_index = #current.picks + 1
    row.rank = chosen.rank
    row.amwi_pp = chosen.amwi_pp
    row.effort_percent = chosen.effort_percent
    local prediction = Impact.predict_current_rosters(0)
    local draft_prediction = Impact.predict_current_draft_rosters(0)
    row.prediction_after_pick = prediction.p_north
    row.draft_balance_after_pick = draft_prediction.p_north
    row.raw_prediction_after = prediction
    row.draft_prediction_after = draft_prediction
    row.draft_floor_eta_after_pick = draft_prediction.draft_floor_eta or 0
    row.effort_eta_after_pick = draft_prediction.effort_eta or 0
    row.draft_adjustment_eta_after_pick = draft_prediction.draft_adjustment_eta or 0
    row.rosters_after_pick = roster_names()
    current.picks[#current.picks + 1] = row
    new_event('draft_pick', table.deepcopy(row))
end

function Public.record_role(player_name, force_name, primary_role, secondary_role)
    local current = ensure_history().current
    if not current then
        return
    end
    local row = {
        player_name = player_name,
        force = force_name,
        primary_role = primary_role,
        secondary_role = secondary_role,
        primary_role_credit = Seed.primary_role_credit,
        secondary_role_credit = secondary_role and Seed.secondary_role_credit or 0,
        tick = game.tick,
    }
    current.roles[player_name] = table.deepcopy(row)
    current.role_events[#current.role_events + 1] = row
    new_event('captain_role_selected', table.deepcopy(row))
end

function Public.lock_starting_roster()
    local current = ensure_history().current
    if not current then
        return
    end
    if current.starting_roster then
        return current.starting_roster, current.locked_prediction
    end
    local special = storage.special_games_variables.captain_mode
    local roster = { north = {}, south = {} }
    current.test_mode = special.test_mode or current.test_mode
    for force_name, players in pairs(roster_names()) do
        for _, player_name in ipairs(players) do
            Impact.freeze_effort(player_name)
            local row = player_snapshot(player_name)
            local role = current.roles[player_name]
            row.primary_role = role and role.primary_role or nil
            row.secondary_role = role and role.secondary_role or nil
            row.primary_role_credit = role and role.primary_role_credit or 0
            row.secondary_role_credit = role and role.secondary_role_credit or 0
            roster[force_name][#roster[force_name] + 1] = row
        end
    end
    Public.record_captains()
    current.starting_captains = table.deepcopy(current.captains)
    current.starting_roster = roster
    current.starting_roles = table.deepcopy(current.roles)
    current.roster_locked_tick = game.tick
    current.starting_model_snapshot = Impact.get_model_snapshot()
    current.community_pick_info = table.deepcopy(special.stats.communityPickInfo)
    current.locked_prediction = Impact.predict_current_rosters(0)
    current.locked_draft_prediction = Impact.predict_current_draft_rosters(0)
    current.prediction = current.locked_prediction.p_north
    current.draft_balance_probability = current.locked_draft_prediction.p_north
    new_event('starting_roster_locked', {
        roster = table.deepcopy(roster),
        captains = table.deepcopy(current.starting_captains),
        roles = table.deepcopy(current.starting_roles),
    })
    new_event('prediction_locked', {
        predicted_north_probability = current.prediction,
        raw_prediction = table.deepcopy(current.locked_prediction),
        draft_prediction = table.deepcopy(current.locked_draft_prediction),
        model_snapshot = table.deepcopy(current.starting_model_snapshot),
    })
    return roster, current.locked_prediction
end

local function archive_match(current, cancelled)
    local history = ensure_history()
    local games = cancelled and history.cancelled_games or history.games
    games[#games + 1] = current
    history.pending_exports[current.match_id] = table.deepcopy(current)
    Public.retry_pending_exports()
    history.current = nil
end

function Public.finish_match(winner)
    local history = ensure_history()
    local current = history.current
    if not current then
        return
    end
    if winner ~= 'north' and winner ~= 'south' then
        log('Captain Impact ignored invalid winner: ' .. tostring(winner))
        return
    end
    current.finished_tick = game.tick
    current.winner = winner
    current.status = 'completed'
    current.final_captains = captains()
    current.final_roster = roster_names()
    current.final_model_snapshot = Impact.get_model_snapshot()
    local y = winner == 'north' and 1 or 0
    local p = current.prediction
    if p and not current.test_mode then
        local eps = 1e-9
        p = math.max(eps, math.min(1 - eps, p))
        local m = history.live_metrics
        m.games = m.games + 1
        m.log_loss_sum = m.log_loss_sum - (y * math.log(p) + (1 - y) * math.log(1 - p))
        m.brier_sum = m.brier_sum + (p - y) * (p - y)
        if (p >= 0.5 and 'north' or 'south') == winner then
            m.correct = m.correct + 1
        end
    end
    -- Emit the complete record so JSONL alone contains every model and outcome field.
    new_event(
        'captain_game_finished',
        { winner = winner, predicted_north_probability = current.prediction, match = table.deepcopy(current) }
    )
    if current.starting_roster and not current.test_mode then
        local north, south = {}, {}
        for _, row in ipairs(current.starting_roster.north) do
            north[#north + 1] = row.player_name
        end
        for _, row in ipairs(current.starting_roster.south) do
            south[#south + 1] = row.player_name
        end
        Impact.mark_completed_game_players(north, south)
    end
    local learning_ok, learning_err = pcall(function()
        local learning_result = LearningStore.queue_match(current)
        if not learning_result.accepted and not learning_result.duplicate then
            log(
                'Captain Impact learning skipped match '
                    .. tostring(current.match_id)
                    .. ': '
                    .. tostring(learning_result.reason)
            )
        end
        LearningStore.advance()
    end)
    if not learning_ok then
        log('Captain Impact learning failed for ' .. tostring(current.match_id) .. ': ' .. tostring(learning_err))
    end
    archive_match(current, false)
end

function Public.cancel_match(reason)
    local current = ensure_history().current
    if not current then
        return
    end
    current.cancelled_tick = game.tick
    current.cancel_reason = reason or 'cancelled'
    current.status = 'cancelled'
    new_event('captain_game_cancelled', { reason = current.cancel_reason, match = table.deepcopy(current) })
    archive_match(current, true)
end

function Public.get_live_metrics()
    local m = ensure_history().live_metrics
    if m.games == 0 then
        return { games = 0 }
    end
    return {
        games = m.games,
        log_loss = m.log_loss_sum / m.games,
        brier = m.brier_sum / m.games,
        accuracy = m.correct / m.games,
    }
end

Event.add(Server.events.on_server_started, Public.retry_pending_exports)

return Public
