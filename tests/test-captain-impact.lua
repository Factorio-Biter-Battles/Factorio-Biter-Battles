-- Run from the scenario root with Lua 5.2: lua tests/test-captain-impact.lua
-- Uses the real model, recorder and Captain event handlers with mocked Factorio services.
local function deepcopy(value)
    if type(value) ~= 'table' then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = deepcopy(child)
    end
    return copy
end
table.deepcopy = deepcopy
local noop = function() end
local hooks, messages, events, exports = {}, {}, {}, {}
local fail_file, fail_export = false, false
local players = {}
local checks = 0
local function check(condition, message)
    assert(condition, message)
    checks = checks + 1
end
local function near(a, b)
    return math.abs(a - b) < 1e-12
end
local function stub(extra)
    return setmetatable(extra or {}, {
        __index = function()
            return noop
        end,
    })
end

storage = { special_games_variables = {} }
game = {
    tick = 100,
    ticks_played = 100,
    players = players,
    connected_players = {},
    surfaces = { bb = { map_gen_settings = { seed = 123456 } } },
    print = noop,
    get_player = function(name)
        return players[name]
    end,
}
log = function(message)
    messages[#messages + 1] = message
end
helpers = {
    table_to_json = function(event)
        events[#events + 1] = deepcopy(event)
        return '{}'
    end,
    write_file = function(path, data, append, target)
        assert(path == 'bb-captain-impact/events.jsonl' and append and target == 0 and data == '{}\n')
        if fail_file then
            error('injected file failure')
        end
    end,
}
defines = {
    events = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
    }),
    input_action = setmetatable({}, {
        __index = function(_, key)
            return key
        end,
    }),
}
commands = { add_command = noop }
package.loaded['utils.event'] = stub({
    add = function(name, fn)
        hooks[name] = fn
    end,
    on_nth_tick = function(_, fn)
        hooks.on_nth_tick = fn
    end,
})
package.loaded['utils.server'] = {
    events = { on_server_started = 'server_started' },
    get_time_data_raw = function()
        return { secs = 1789000000, tick = 1 }
    end,
    on_data_set_changed = noop,
    try_get_all_data = noop,
    set_data = function(data_set, key, value)
        assert(data_set == 'captain_impact_v1_games' and type(key) == 'string' and value.match_id == key)
        if fail_export then
            error('injected datastore failure')
        end
        exports[#exports + 1] = deepcopy(value)
    end,
}
package.loaded['utils.player'] = stub()
package.loaded['utils.token'] = {
    get_counter = function()
        return 0
    end,
    register = function()
        return 1
    end,
}
package.loaded['utils.utils'] = stub({
    safe_wrap_cmd = function(fn)
        return fn
    end,
    ternary = function(c, a, b)
        if c then
            return a
        else
            return b
        end
    end,
})
for _, name in ipairs({
    'comfy_panel.special_games.captain_task_group',
    'comfy_panel.special_games.captain_ui',
    'comfy_panel.special_games.captain_impact_trust',
    'comfy_panel.special_games.captain_impact_explain',
    'comfy_panel.special_games.captain_roles',
    'utils.ui.closable_frame',
    'utils.color_presets',
    'maps.biter_battles_v2.difficulty_vote',
    'utils.gui',
    'comfy_panel.player_list',
    'utils.datastore.session_data',
    'maps.biter_battles_v2.tables',
    'utils.task',
}) do
    package.loaded[name] = stub()
end
package.loaded['comfy_panel.group'] = {
    is_cpt_group_tag = function(tag)
        return tag:sub(1, 5) == '[cpt_'
    end,
}
package.loaded['maps.biter_battles_v2.functions'] = stub({
    get_ticks_since_game_start = function()
        return game.tick
    end,
})
package.loaded['maps.biter_battles_v2.team_manager'] = stub({
    switch_force = function(name, force)
        storage.chosen_team[name] = force
        players[name].force = { name = force }
    end,
})
local Impact = require('comfy_panel.special_games.captain_impact_model')
local Data = require('comfy_panel.special_games.captain_impact_data')
local Captain = require('comfy_panel.special_games.captain')
Captain.update_all_captain_player_guis = noop

-- Exercise private production functions via their actual event-handler closures.
local function find_upvalue(fn, wanted, seen)
    seen = seen or {}
    if seen[fn] then
        return
    end
    seen[fn] = true
    local i = 1
    while true do
        local name, value = debug.getupvalue(fn, i)
        if not name then
            return
        end
        if name == wanted then
            return value
        end
        if type(value) == 'function' then
            local found = find_upvalue(value, wanted, seen)
            if found then
                return found
            end
        end
        i = i + 1
    end
end
local assign = assert(find_upvalue(hooks.on_gui_click, 'assign_player'))
local sort_list = assert(find_upvalue(hooks.on_gui_click, 'get_sorted_pick_list'))
local group_auto = assert(find_upvalue(hooks.on_gui_click, 'auto_pick_all_of_group'))
local switch_team = assert(find_upvalue(hooks.on_gui_click, 'switch_team_of_player'))
local timeout = assert(find_upvalue(hooks.on_tick, 'force_assign_player'))

local function reset(mode)
    events, exports, messages = {}, {}, {}
    fail_file, fail_export = false, false
    for name in pairs(players) do
        players[name] = nil
    end
    for _, name in ipairs({ 'north_captain', 'south_captain', '99Names', 'unrated', 'late', 'observer' }) do
        players[name] = {
            name = name,
            valid = true,
            connected = true,
            print = noop,
            force = { name = 'spectator' },
            tag = '',
            gui = { screen = {} },
        }
    end
    local special = {
        draftFormat = mode or 'impact_dynamic',
        captainList = { 'north_captain', 'south_captain' },
        listPlayers = { '99Names', 'unrated', 'late' },
        player_effort = {},
        playerPickedAtTicks = {},
        player_info = {},
        captainGroupAllowed = true,
        groupLimit = 3,
        pickingPhase = false,
        initialPickingPhaseFinished = false,
        initialPickingPhaseStarted = false,
        prepaPhase = false,
        next_pick_force = 'north',
        nextAutoPicksFavor = { north = 0, south = 0 },
        autoPickIntervalTicks = 100,
        stats = { northPicks = {}, southPicks = {} },
        teamAssignmentSeed = 45678,
        captain_pick_timer = { north = 100, south = 100 },
        captain_pick_timer_gain = 10,
        captain_pick_timer_sma_last_tick = { north = 0, south = 0 },
        captain_pick_timer_pause_duration = 0,
        captain_pick_timer_sma_count = { north = 0, south = 0 },
        captain_pick_timer_sma_samples = { north = {}, south = {} },
        captain_pick_timer_sma_sum = {},
    }
    storage = {
        special_games_variables = { captain_mode = special },
        active_special_games = { captain_mode = true },
        chosen_team = {},
        total_time_online_players = { ['99Names'] = 100, unrated = 10, late = 500 },
        bb_surface_name = 'bb',
    }
    Data.begin_match(special.draftFormat)
    switch_team('north_captain', 'north')
    switch_team('south_captain', 'south')
    return special
end

local s = reset()
check(Impact.get_effort_percent('99Names') == 100, 'default effort')
check(Impact.set_effort_percent('99Names', 0), 'signup effort is editable')
Impact.lock_draft_efforts()
s.pickingPhase = true
Data.record_draft_started()
local before = Impact.predict_current_draft_rosters(0).p_north
check(not Impact.set_effort_percent('99Names', 100), 'unpicked candidate is locked during draft')
local slider = { name = 'captain_player_effort_slider', valid = true, slider_value = 100 }
hooks.on_gui_value_changed({ element = slider, player_index = '99Names' })
check(slider.slider_value == 0 and slider.enabled == false, 'stale effort GUI is restored and disabled')
s.player_effort['99Names'] = 100
check(Impact.get_effort_percent('99Names') == 0, 'draft snapshot protects balance from declaration mutation')
check(not Impact.can_change_effort('north_captain'), 'captain effort frozen by assignment')
assign('99Names', 'north_captain', 'manual')
local current = storage.captain_impact_history.current
local pick = current.picks[1]
check(#pick.available_candidates == 3, 'chosen player remains in pre-pick candidate pool')
check(
    pick.chosen_player.player_name == '99Names' and pick.effort_percent == 0,
    'chosen uses declared effort snapshot including zero'
)
check(pick.rank == 33 and pick.amwi_pp == Impact.get_amwi_pp('99Names'), 'rank and AMWI captured')
check(
    pick.picker == 'north_captain' and pick.captain == 'north_captain' and pick.captain_choice,
    'manual captain attribution'
)
check(pick.captains.south == 'south_captain', 'opposing captain captured')
check(near(pick.draft_balance_before_pick, before), 'pre-pick probability captured before mutation')
check(
    near(pick.draft_balance_after_pick, Impact.predict_current_draft_rosters(0).p_north),
    'post-pick draft probability'
)
check(#pick.rosters_before_pick.north == 1 and #pick.rosters_after_pick.north == 2, 'pre/post rosters')
s.player_effort['99Names'] = 100
s.listPlayers[1] = 'late'
check(
    #pick.available_candidates == 3 and pick.available_candidates[1].effort_percent == 0,
    'record is immutable after pool/declaration changes'
)
s.pickingPhase = false
s.draft_effort_snapshot = nil
storage.chosen_team['99Names'] = nil
check(
    not Impact.can_change_effort('99Names') and Impact.get_effort_percent('99Names') == 0,
    'drafted effort remains frozen after removal'
)
storage.chosen_team['99Names'] = 'north'
check(Impact.set_effort_percent('late', 25), 'undrafted late signup may declare effort between drafts')
s.listPlayers = { 'late', 'unrated' }
Impact.lock_draft_efforts()
s.pickingPhase = true
s.initialPickingPhaseFinished = true
Data.record_draft_started()
timeout()
check(
    current.picks[2].selection_type == 'timeout'
        and current.picks[2].picker == false
        and not current.picks[2].captain_choice,
    'timeout is not captain-choice evidence'
)
check(current.picks[2].draft_round == 2 and current.picks[2].phase == 'in_game', 'later round and phase captured')

-- Paused, stopped, duplicate and observer GUI picks must not assign or record.
local count = #current.picks
s.captain_pick_timer_paused = true
assign('unrated', 'north_captain', 'manual')
check(#current.picks == count, 'paused pick rejected')
s.captain_pick_timer_paused = false
hooks.on_gui_click({
    player_index = 'observer',
    element = { valid = true, name = 'captain_player_picked_unrated', tags = { name = 'unrated' } },
})
check(#current.picks == count, 'observer pick rejected by server handler')
s.pickingPhase = false
assign('unrated', 'north_captain', 'manual')
check(#current.picks == count, 'stopped draft pick rejected')
s.pickingPhase = true
assign('99Names', 'north_captain', 'manual')
check(#current.picks == count, 'already assigned pick rejected')

-- Group flags and pre-existing tags cannot affect Impact; Classic still auto-picks.
s = reset()
players['99Names'].tag, players.unrated.tag = '[cpt_same]', '[cpt_same]'
check(sort_list()[1] == 'late', 'Impact default order ignores groups')
local toggle = { name = 'captain_enable_groups_switch', valid = true, switch_state = 'left' }
hooks.on_gui_switch_state_changed({ element = toggle })
check(
    not s.captainGroupAllowed and toggle.switch_state == 'right' and not toggle.enabled,
    'Impact group toggle cannot enable groups'
)
s.captainGroupAllowed = true -- corrupt/legacy state must still be safe
Impact.lock_draft_efforts()
s.pickingPhase = true
assign('99Names', 'north_captain', 'manual')
group_auto('99Names')
check(storage.chosen_team.unrated == nil and #s.listPlayers == 2, 'Impact blocks both group auto-pick paths')
s = reset('classic_122')
players['99Names'].tag, players.unrated.tag = '[cpt_same]', '[cpt_same]'
check(sort_list()[1] == '99Names', 'Classic group ordering preserved')
check(not Impact.set_effort_percent('99Names', 0), 'Impact effort event does not mutate Classic')
toggle = { name = 'captain_enable_groups_switch', valid = true, switch_state = 'right' }
hooks.on_gui_switch_state_changed({ element = toggle })
check(not s.captainGroupAllowed, 'Classic referee may disable groups')
toggle.switch_state = 'left'
hooks.on_gui_switch_state_changed({ element = toggle })
check(s.captainGroupAllowed, 'Classic referee may enable groups')
s.pickingPhase = true
assign('99Names', 'north_captain', 'manual')
check(
    storage.chosen_team.unrated == 'north' and #s.listPlayers == 1 and s.next_pick_force == 'south',
    'Classic group auto-pick and turn allocation preserved'
)
check(
    storage.captain_impact_history.current.picks[2].selection_type == 'group_auto_pick',
    'group assignment recorded separately'
)

-- Frozen start state, roles, model parameters, cancellation, retries and idempotence.
s = reset()
Data.record_role('north_captain', 'north', 'main_builder', 'flexible')
Data.lock_starting_roster()
current = storage.captain_impact_history.current
local locked = current.prediction
check(
    current.starting_captains.north == 'north_captain' and current.starting_captains.south == 'south_captain',
    'both starting captains explicit'
)
check(
    current.starting_roster.north[1].secondary_role_credit == 1 / 3
        and current.starting_roster.north[1].primary_role_credit == 1,
    'role weights preserved'
)
check(
    current.model_snapshot.count_coefficient == Impact.get_seed().count_coefficient
        and current.model_snapshot.players == nil,
    'model coefficients captured without unrelated seed players'
)
switch_team('late', 'north')
Data.lock_starting_roster()
check(
    current.prediction == locked and #current.starting_roster.north == 1,
    'starting prediction and roster lock only once'
)
Data.finish_match('invalid')
check(storage.captain_impact_history.current == current, 'invalid winner does not become a South win')
fail_export, fail_file = true, true
Data.finish_match('north')
local history = storage.captain_impact_history
check(
    history.current == nil and #history.games == 1 and history.games[1].winner == 'north',
    'match archived despite export failure'
)
check(
    history.pending_exports[current.match_id] ~= nil and #history.failed_events > 0 and #messages > 0,
    'failed exports retained and logged'
)
check(
    current.final_roster.north[2] == 'north_captain' and current.starting_roster.north[1].player_name == 'north_captain',
    'late roster change does not rewrite starting roster'
)
check(Data.get_live_metrics().games == 1, 'one live outcome scored')
Data.finish_match('north')
check(#history.games == 1 and Data.get_live_metrics().games == 1, 'duplicate completion does not double-count')
fail_export, fail_file = false, false
hooks.server_started()
check(
    next(history.pending_exports) == nil and #history.failed_events == 0 and #exports == 1,
    'server start retries failed outputs'
)
check(
    exports[1].model_snapshot.model_version == Impact.get_seed().model_version
        and exports[1].starting_roles.north_captain.primary_role == 'main_builder',
    'datastore receives full model/role record'
)
check(
    events[#events].match.winner == 'north' and events[#events].match.starting_roster ~= nil,
    'JSONL finish contains complete match'
)
game.tick = game.tick + 1
Data.begin_match('impact_dynamic')
local next_id = history.current.match_id
Data.cancel_match('test_cancel')
check(
    #history.cancelled_games == 1 and history.cancelled_games[1].cancel_reason == 'test_cancel',
    'cancellation retained and exported'
)
check(next_id ~= current.match_id and #exports == 2, 'distinct match keys and cancelled record submitted')
Data.record_role('late', 'north', 'flexible')
check(history.current == nil, 'stale role event cannot create a phantom match')

-- Classic 1-2-2 and later alternating turns, independent of Impact ratings.
s = reset('classic_122')
s.captainGroupAllowed = false
s.pickingPhase = true
s.listPlayers = {}
for i = 1, 6 do
    local name = 'classic_' .. i
    players[name] = {
        name = name,
        valid = true,
        connected = true,
        print = noop,
        force = { name = 'spectator' },
        tag = '',
        gui = { screen = {} },
    }
    s.listPlayers[i] = name
end
for i, force in ipairs({ 'north', 'south', 'south', 'north', 'north' }) do
    check(s.next_pick_force == force, 'Classic 1-2-2 pick ' .. i)
    assign('classic_' .. i, force .. '_captain', 'manual')
end
s.initialPickingPhaseFinished = true
assign('classic_6', 'south_captain', 'manual')
check(not s.pickingPhase and s.initialPickingPhaseFinished, 'Classic draft still completes normally')

-- Exercise the real community draft path; automatic assignments are not human choices.
s = reset('classic_122')
storage.chosen_team = {}
s.captainList = {}
s.stats.northPicks, s.stats.southPicks = {}, {}
s.communityPickingMode = true
s.communityPicksConfirmed = { voter = true }
s.communityPickOrder = { voter = deepcopy(s.listPlayers) }
s.captain_pick_timer_base = 100
table_size = function(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end
table.size = table_size
local start_round = assert(find_upvalue(hooks.on_gui_click, 'start_picking_phase'))
start_round()
check(
    #s.listPlayers == 0 and not s.pickingPhase and s.stats.communityPickInfo ~= nil,
    'Classic community picking still assigns the pool'
)
for _, row in ipairs(storage.captain_impact_history.current.picks) do
    check(
        row.selection_type == 'community_assignment' and not row.captain_choice,
        'community assignment classification'
    )
end

-- Validate real UI row/header counts and reject obsolete group-sort state.
s = reset()
s.pickingPhase = true
local UI = assert(loadfile('comfy_panel/special_games/captain_ui.lua'))()
local draw_row = assert(find_upvalue(UI.draw_picking_ui, 'draw_picking_ui_entry'))
local draw_header = assert(find_upvalue(UI.draw_picking_ui, 'draw_picking_ui_list_header'))
local function widget()
    local w = { children = {}, style = {}, valid = true }
    w.add = function(spec)
        local child = widget()
        for key, value in pairs(spec) do
            if key ~= 'style' then
                child[key] = value
            end
        end
        child.parent = w
        w.children[#w.children + 1] = child
        if child.name then
            w[child.name] = child
        end
        return child
    end
    w.clear = function()
        w.children = {}
    end
    w.destroy = function()
        w.valid = false
    end
    return w
end
local row_ui, header_ui = widget(), widget()
draw_row(row_ui, '99Names', '[cpt_same]', '1 minute', players.observer)
draw_header(header_ui, players.observer)
check(#row_ui.children == 7 and #header_ui.children == 7, 'Impact table has seven matching columns')
check(row_ui.children[1].children[1].name == 'container', 'observer has no pick button')
check(
    not UI.handle_pick_sort_click(players.observer, { valid = true, name = 'captain_pick_sort_group' }),
    'obsolete group sort rejected'
)
s.draftFormat = 'classic_122'
row_ui, header_ui = widget(), widget()
draw_row(row_ui, '99Names', '[cpt_same]', '1 minute', players.north_captain)
draw_header(header_ui, players.north_captain)
check(
    #row_ui.children == 4 and #header_ui.children == 4 and row_ui.children[2].caption == '[cpt_same]',
    'Classic keeps four columns and group tag'
)

-- Groups UI and stale create/join events are disabled for Impact only.
s.draftFormat = 'impact_dynamic'
local group_frame = widget()
group_frame.name = 'Groups'
package.loaded['comfy_panel.main'] = {
    comfy_panel_get_active_frame = function()
        return group_frame
    end,
}
package.loaded['utils.global'] = { register = noop }
comfy_panel_tabs = {}
assert(loadfile('comfy_panel/group.lua'))()
comfy_panel_tabs.Groups.gui(players.observer, group_frame)
check(
    #group_frame.children == 1 and group_frame.children[1].caption:find('disabled'),
    'Impact Groups UI explains disabled state'
)
hooks.on_gui_click({ element = { valid = true, player_index = 'observer', name = 'create_new_group' } })
check(#group_frame.children == 1, 'stale group create event rejected before reading removed controls')

-- Roles reject stale/spectator submissions and stay inactive for Classic.
local Roles = assert(loadfile('comfy_panel/special_games/captain_roles.lua'))()
s.roleSelection = { initial_started = true, required = { observer = true }, selections = {}, locked = false }
players.observer.gui.screen.captain_role_selection_ui = {}
Roles.handle_gui_click({ player_index = 'observer', element = { valid = true, name = 'captain_role_submit' } })
check(s.roleSelection.selections.observer == nil, 'spectator cannot submit stale role GUI')
s.draftFormat = 'classic_122'
s.roleSelection = nil
Roles.start_initial_selection()
check(s.roleSelection == nil, 'Classic has no Impact role gate')

-- Serialize a complete prospective record through the actual current Server.set_data.
local wrapper_message
serpent = require('serpent')
package.loaded['utils.print_override'] = {
    raw_print = function(message)
        wrapper_message = message
    end,
}
package.loaded['utils.event'].generate_event_name = function(name)
    return name
end
local Server = assert(loadfile('utils/server.lua'))()
local record = exports[1] or current
Server.set_data('captain_impact_v1_games', record.match_id, record)
check(
    wrapper_message:sub(1, 10) == '[DATA-SET]' and wrapper_message:find('starting_roster', 1, true),
    'actual wrapper serializes the full record with three-argument signature'
)

print('Captain Impact regression checks passed: ' .. checks)
