local ImpactData = require('comfy_panel.special_games.captain_impact_data')
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local gui_style = require('utils.utils').gui_style

local Public = {}
local FRAME_NAME = 'captain_role_selection_ui'

local role_by_caption = {}
local primary_items = { 'Select primary role' }
local secondary_items = { 'None' }
for _, role in ipairs(Seed.roles) do
    role_by_caption[role.caption] = role.key
    primary_items[#primary_items + 1] = role.caption
    secondary_items[#secondary_items + 1] = role.caption
end

local function special()
    return storage.special_games_variables and storage.special_games_variables.captain_mode
end

local function ensure_state()
    local s = special()
    if not s or s.draftFormat ~= 'impact_dynamic' then
        return nil
    end
    s.roleSelection = s.roleSelection
        or {
            initial_started = false,
            initial_finished = false,
            required = {},
            selections = {},
            locked = false,
        }
    return s.roleSelection
end

local function selected_caption(dropdown)
    if not dropdown or dropdown.selected_index == 0 then
        return nil
    end
    return dropdown.items[dropdown.selected_index]
end

function Public.get_roles()
    return Seed.roles
end

function Public.get_selection(player_name)
    local state = ensure_state()
    return state and state.selections[player_name] or nil
end

function Public.try_destroy(player)
    if player and player.valid and player.gui.screen[FRAME_NAME] then
        player.gui.screen[FRAME_NAME].destroy()
    end
end

function Public.draw_if_needed(player)
    local state = ensure_state()
    if not state or state.locked or not state.required[player.name] or state.selections[player.name] then
        return
    end
    if player.force.name ~= 'north' and player.force.name ~= 'south' then
        return
    end
    Public.try_destroy(player)
    local frame = player.gui.screen.add({ type = 'frame', name = FRAME_NAME, direction = 'vertical' })
    frame.auto_center = true
    gui_style(frame, { minimal_width = 420, maximal_width = 520 })
    local title = frame.add({ type = 'label', caption = 'Captain Game role selection', style = 'frame_title' })
    title.tooltip =
        'Primary is your main role for this match (outcome-role credit 1.0). Secondary is optional and receives 1/3 outcome-role credit.'
    local info = frame.add({
        type = 'label',
        caption = 'Choose your primary role for this match. Secondary is optional and counts as 1/3 role evidence.',
    })
    gui_style(info, { single_line = false, bottom_margin = 8 })
    local table_gui = frame.add({ type = 'table', name = 'captain_role_table', column_count = 2 })
    table_gui.add({ type = 'label', caption = 'Primary role' })
    table_gui.add({
        type = 'drop-down',
        name = 'captain_primary_role_dropdown',
        items = primary_items,
        selected_index = 1,
    })
    table_gui.add({ type = 'label', caption = 'Secondary role' })
    table_gui.add({
        type = 'drop-down',
        name = 'captain_secondary_role_dropdown',
        items = secondary_items,
        selected_index = 1,
    })
    local submit = frame.add({ type = 'button', name = 'captain_role_submit', caption = 'Confirm roles' })
    submit.style = 'confirm_button'
end

function Public.start_initial_selection()
    local state = ensure_state()
    if not state or state.initial_started then
        return
    end
    state.initial_started = true
    for player_name, force_name in pairs(storage.chosen_team or {}) do
        if force_name == 'north' or force_name == 'south' then
            state.required[player_name] = true
        end
    end
    game.print(
        '[font=default-large-bold]Initial draft complete. Picked players: choose your primary role; secondary is optional.[/font]'
    )
    for _, player in pairs(game.connected_players) do
        Public.draw_if_needed(player)
    end
end

function Public.require_player(player_name)
    local state = ensure_state()
    if not state or state.locked or not state.initial_started then
        return
    end
    state.required[player_name] = true
    local player = game.get_player(player_name)
    if player and player.connected then
        Public.draw_if_needed(player)
    end
end

function Public.team_complete(force_name)
    local state = ensure_state()
    if not state then
        return true
    end
    for player_name, required in pairs(state.required) do
        if required and storage.chosen_team[player_name] == force_name then
            local player = game.get_player(player_name)
            -- Do not deadlock the event on a disconnected picked player. If they
            -- reconnect before lock, they will be prompted again.
            if player and player.connected and not state.selections[player_name] then
                return false, player_name
            end
        end
    end
    return true
end

function Public.handle_gui_click(event)
    local element = event.element
    if not (element and element.valid) or element.name ~= 'captain_role_submit' then
        return false
    end
    local player = game.get_player(event.player_index)
    local state = ensure_state()
    if not player or not state or state.locked then
        return true
    end
    if
        not state.required[player.name]
        or state.selections[player.name]
        or (player.force.name ~= 'north' and player.force.name ~= 'south')
        or storage.chosen_team[player.name] ~= player.force.name
    then
        return true
    end
    local frame = player.gui.screen[FRAME_NAME]
    if not frame then
        return true
    end
    local role_table = frame.captain_role_table
    local primary_caption = selected_caption(role_table.captain_primary_role_dropdown)
    local secondary_caption = selected_caption(role_table.captain_secondary_role_dropdown)
    local primary = role_by_caption[primary_caption]
    local secondary = secondary_caption == 'None' and nil or role_by_caption[secondary_caption]
    if not primary then
        player.print('Choose a primary Captain Game role before confirming.')
        return true
    end
    if secondary and secondary == primary then
        player.print('Primary and secondary role must be different.')
        return true
    end
    local selection = {
        primary_role = primary,
        secondary_role = secondary,
        force = player.force.name,
        submitted_tick = game.tick,
    }
    state.selections[player.name] = selection
    ImpactData.record_role(player.name, player.force.name, primary, secondary)
    Public.try_destroy(player)
    player.print(
        'Captain Game roles saved: '
            .. primary_caption
            .. (secondary_caption ~= 'None' and (' / ' .. secondary_caption) or '')
    )

    local all_done = true
    for player_name, required in pairs(state.required) do
        if required then
            local p = game.get_player(player_name)
            if p and p.connected and not state.selections[player_name] then
                all_done = false
                break
            end
        end
    end
    if all_done and not state.initial_finished then
        state.initial_finished = true
        game.print('[font=default-large-bold]All connected first-round players have submitted their roles.[/font]')
    end
    return true
end

function Public.all_complete()
    local north_ok, north_missing = Public.team_complete('north')
    if not north_ok then
        return false, north_missing
    end
    local south_ok, south_missing = Public.team_complete('south')
    if not south_ok then
        return false, south_missing
    end
    return true
end

function Public.required_count()
    local state = ensure_state()
    if not state then
        return 0, 0
    end
    local required = 0
    local selected = 0
    for player_name, needed in pairs(state.required) do
        if needed then
            local player = game.get_player(player_name)
            if player and player.connected then
                required = required + 1
                if state.selections[player_name] then
                    selected = selected + 1
                end
            end
        end
    end
    return selected, required
end

function Public.lock_starting_roles()
    local state = ensure_state()
    if not state or state.locked then
        return
    end
    state.locked = true
    for _, player in pairs(game.players) do
        Public.try_destroy(player)
    end
end

return Public
