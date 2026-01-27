local CaptainUtils = require('comfy_panel.special_games.captain_utils')
local CaptainStates = require('comfy_panel.special_games.captain_states')
local Color = require('utils.color_presets')
local Group = require('comfy_panel.group')
local PlayerList = require('comfy_panel.player_list')
local PlayerUtils = require('utils.player')
local cpt_get_player = CaptainUtils.cpt_get_player
local gui_style = require('utils.utils').gui_style
local Public = {}

---@param parent LuaGuiElement
---@param tags Tags Associated data that helps with identification of players.
local function draw_picking_ui_button(parent, tags)
    local button = parent.add({
        type = 'sprite-button',
        name = 'captain_player_picked_' .. tags.name,
        sprite = 'utility/enter',
        tags = tags,
    })
    gui_style(button, { font = 'default-bold', horizontally_stretchable = false })
end

---Updates connection status of a player in the picking UI.
---@param widget LuaGuiElement Widget
---@param connected boolean If the player is connected.
local function update_player_status(widget, connected)
    if connected then
        widget.sprite = 'utility/status_working'
        widget.tooltip = 'This player is currently connected'
    else
        widget.sprite = 'utility/status_not_working'
        widget.tooltip = 'This player is currently disconnected'
    end
end

---@param enabled boolean If the button should be enabled
local function draw_picking_ui_entry(parent, player_name, group_name, play_time)
    local special = storage.special_games_variables.captain_mode
    local tags = {
        name = player_name,
    }

    -- Horizontal container for button + player name next to it.
    local flow = parent.add({
        type = 'flow',
        direction = 'horizontal',
        tags = tags,
    })
    draw_picking_ui_button(flow, tags)
    local name_flow = flow.add({
        type = 'flow',
        direction = 'horizontal',
        name = 'container',
        tags = tags,
    })

    local icon = name_flow.add({
        type = 'sprite',
        name = 'online_icon',
        sprite = 'utility/status_not_working',
        tooltip = 'This player is currently disconnected',
    })
    gui_style(icon, { width = 12, height = 12 })

    local player = cpt_get_player(player_name)
    local connected = player and player.connected
    update_player_status(icon, connected)

    -- Inner flow elements don't require tags.
    local l = name_flow.add({
        type = 'label',
        caption = player_name,
        style = 'tooltip_label',
    })

    local color = PlayerUtils.get_suitable_ui_color(player)
    l.style.font_color = color
    l.style.minimal_width = 100
    l.style.horizontal_align = 'left'

    l = parent.add({
        type = 'label',
        caption = group_name,
        style = 'tooltip_label',
        tags = tags,
    })
    gui_style(l, { minimal_width = 100, font_color = Color.antique_white })

    l = parent.add({
        type = 'label',
        caption = play_time,
        style = 'tooltip_label',
        tags = tags,
    })
    gui_style(l, { minimal_width = 100 })

    l = parent.add({
        type = 'label',
        caption = special.player_info[player_name] or '',
        style = 'tooltip_label',
        tags = tags,
    })
    gui_style(l, { minimal_width = 100, single_line = false, maximal_width = 300 })
end

---Draws empty title on top of picking UI.
---@param frame LuaGuiElement Main picking UI frame
local function draw_picking_ui_title(frame)
    local flow = frame.add({ type = 'flow', name = 'title_root', direction = 'horizontal' })
    gui_style(flow, { horizontal_spacing = 8, bottom_padding = 4 })

    local title = flow.add({ type = 'label', name = 'title', style = 'frame_title' })
    title.drag_target = frame

    local dragger = flow.add({ type = 'empty-widget', style = 'draggable_space_header' })
    dragger.drag_target = frame
    gui_style(dragger, { height = 24, horizontally_stretchable = true })
end

---Draws a main table where header and player entires are going to be drawn.
---@param frame LuaGuiElement Main picking UI frame
---@return LuaGuiElement Table
local function draw_picking_ui_list_inner(frame)
    local flow = frame.add({ type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' })
    local inner_frame = flow.add({
        type = 'frame',
        name = 'inner_frame',
        style = 'inside_shallow_frame_packed',
        direction = 'vertical',
    })
    local sp = inner_frame.add({
        type = 'scroll-pane',
        name = 'scroll_pane',
        style = 'scroll_pane_under_subheader',
        direction = 'vertical',
    })
    gui_style(sp, { horizontally_squashable = false, padding = 0 })
    return sp.add({ type = 'table', name = 'picks_list', column_count = 4, style = 'mods_explore_results_table' })
end

---Draws header of picking list containing player entires.
---@param tab LuaGuiElement Table element.
local function draw_picking_ui_list_header(tab)
    local label_style = {
        font_color = Color.antique_white,
        font = 'heading-2',
        minimal_width = 100,
        top_margin = 4,
        bottom_margin = 4,
    }
    local l = tab.add({ type = 'label', caption = 'Player' })
    gui_style(l, label_style)

    l = tab.add({ type = 'label', caption = 'Group' })
    gui_style(l, label_style)

    l = tab.add({ type = 'label', caption = 'Total playtime' })
    gui_style(l, label_style)

    l = tab.add({ type = 'label', caption = 'Notes' })
    gui_style(l, label_style)
end

---Draws picking list that contains entires players.
---@param frame LuaGuiElement Main picking UI frame
local function draw_picking_ui_list(frame)
    local tab = draw_picking_ui_list_inner(frame)
    draw_picking_ui_list_header(tab)

    local pick_list = storage.special_games_variables.captain_mode.listPlayers
    for _, pl in pairs(pick_list) do
        local playerIterated = cpt_get_player(pl)
        local playtimePlayer = '0 minutes'
        if playerIterated and storage.total_time_online_players[playerIterated.name] then
            playtimePlayer =
                PlayerList.get_formatted_playtime_from_ticks(storage.total_time_online_players[playerIterated.name])
        end

        local tag = playerIterated.tag
        tag = Group.is_cpt_group_tag(tag) and tag or ''
        draw_picking_ui_entry(tab, pl, tag, playtimePlayer)
    end
end

---Draws picking list timer.
---@param frame LuaGuiElement Main picking UI frame
local function draw_picking_ui_timer(frame)
    local special = storage.special_games_variables.captain_mode
    if not special.captain_pick_timer_enabled then
        return
    end

    local flow = frame.add({
        type = 'flow',
        name = 'timer_flow',
        direction = 'horizontal',
    })
    flow.style.horizontal_align = 'center'
    flow.style.horizontally_stretchable = true
    flow.add({
        type = 'label',
        name = 'timer',
        caption = 'a',
        style = 'green_label',
    })
end

---Transform ticks into string representing whole seconds.
---@param ticks integer
---@return string
local function ticks_to_seconds(ticks)
    return tostring(math.floor(ticks / 60)) .. 's'
end

---Transform ticks into string. The resulting format is ZZm XX.Ys, where ZZ is full
---minutes, XX is full seconds and Y is a fraction of a second. If there is less
---than a minute, then only seconds are returned.
local function ticks_to_time(ticks)
    local str = ''
    local minutes = math.floor(ticks / 60 / 60)
    if minutes > 0 then
        str = tostring(minutes) .. 'm '
    end

    return str .. ticks_to_seconds(ticks / 60 % 60 * 60)
end

---Calculate color for timer based on remaining time.
---Uses a cool-toned gradient for better contrast on dark UI.
---@param ticks integer Remaining time in ticks
---@return {r: number, g: number, b: number} Color
local function timer_gradient(ticks)
    local special = storage.special_games_variables.captain_mode
    -- p: percentage of base time remaining, clamped to [0, 1]
    local p = math.max(0, math.min(1, ticks / special.captain_pick_timer_base))
    -- ratio: stays at 1 until 30% time remaining, then transitions from 1 to 0
    local ratio = p >= 0.3 and 1 or p / 0.3
    -- Transition: mint (ratio=1) -> soft yellow (ratio=0.5) -> orange-red (ratio=0)
    local high = { r = 120, g = 255, b = 220 }
    local mid = { r = 255, g = 236, b = 150 }
    local low = { r = 255, g = 96, b = 64 }
    local function mix(a, b, t)
        return {
            r = math.floor(a.r + (b.r - a.r) * t),
            g = math.floor(a.g + (b.g - a.g) * t),
            b = math.floor(a.b + (b.b - a.b) * t),
        }
    end
    if ratio >= 0.5 then
        return mix(mid, high, (ratio - 0.5) / 0.5)
    end
    return mix(low, mid, ratio / 0.5)
end

---Updates picking UI timer.
---@param player LuaPlayer Captain that receives an update.
function Public.update_picking_ui_timer(player)
    local special = storage.special_games_variables.captain_mode
    if not special.captain_pick_timer_enabled then
        return
    end

    -- This element always exists, if we're here.
    local list = player.gui.screen['captain_picking_ui']['timer_flow']['timer']
    local ticks = special.captain_pick_timer[special.next_pick_force]
    local timer = ticks_to_seconds(ticks)
    local is_paused = special.captain_pick_timer_paused
    local is_idle = player.force.name ~= special.next_pick_force
    local caption
    local color
    if is_paused then
        caption = string.format('Picking paused for both teams: Your time: %s', timer)
        color = Color.light_cyan
    elseif is_idle then
        local idle_force = special.next_pick_force == 'north' and 'south' or 'north'
        local idle_ticks = special.captain_pick_timer[idle_force]
        local idle_timer = ticks_to_seconds(idle_ticks)
        caption = string.format('The other team is picking. Their time: %s -- Your time: %s', timer, idle_timer)
        color = Color.light_steel_blue
    else
        caption = string.format('Time remaining for your next pick: %s', timer)
        color = timer_gradient(ticks)
    end

    list.caption = caption
    list.style.font_color = color
end

---Goes through all connected players and tries to locate player
---that is performing picks right now and updates the displayed timer.
---@param force string Force that does the picking now.
function Public.try_update_picking_ui_timer(force)
    for _, player in ipairs(game.forces[force].connected_players) do
        if player.gui.screen['captain_picking_ui'] then
            Public.update_picking_ui_timer(player)
            break
        end
    end
end

---@param player LuaPlayer
local function draw_picking_ui_base(player)
    local location = storage.special_games_variables.captain_mode.ui_picking_location[player.name]

    local frame = player.gui.screen.add({
        type = 'frame',
        name = 'captain_picking_ui',
        direction = 'vertical',
    })
    gui_style(frame, { maximal_width = 900, maximal_height = 800 })
    if location then
        frame.location = location
    else
        frame.auto_center = true
    end

    draw_picking_ui_title(frame)
    draw_picking_ui_timer(frame)
    draw_picking_ui_list(frame)
end

---Finds a child by name in a widget.
---@param widget LuaGuiElement Widget to search in.
---@param fn function Function to call that will check if the child matches.
---@return LuaGuiElement? Child widget.
local function find_child_with_fn(widget, fn)
    for _, child in ipairs(widget.children) do
        if fn(child) then
            return child
        end

        if child.children then
            local res = find_child_with_fn(child, fn)
            if res then
                return res
            end
        end
    end

    return nil
end

---Updates online status of a player in the picking UI.
---@param cpt LuaPlayer Captain for whom we're updating the list.
---@param player_name string Name of a player that changed online status.
function Public.try_update_picking_ui_list_entry(cpt, player_name)
    ---Checks if a child contains a player tag.
    ---@param child LuaGuiElement Child widget.
    ---@return boolean
    local function is_player_tag(child)
        return child.tags and child.tags.name == player_name
    end

    local ui = cpt.gui.screen['captain_picking_ui']
    if not ui then
        return
    end

    local player = cpt_get_player(player_name)
    local connected = player and player.connected
    local list = ui['flow']['inner_frame']['scroll_pane']['picks_list']
    local entry = find_child_with_fn(list, is_player_tag)
    if entry then
        update_player_status(entry['container']['online_icon'], connected)
    end
end

---Iterate through a list of captains and try to update the picking list.
---If the picking list doesn't exist for a captain, it does nothing.
---@param list LuaPlayer[] List of captains
---@param player string Name of player whose entry we're updating.
function Public.try_update_picking_ui_list_entry_for_each(list, player)
    for _, p in pairs(list) do
        Public.try_update_picking_ui_list_entry(p, player)
    end
end

---Removes a player from the pick list if it exists.
---@param cpt LuaPlayer Captain for whom we're updating the list.
---@param player string Name of a player that was just picked.
function Public.try_destroy_picking_ui_list_entry(cpt, player)
    local ui = cpt.gui.screen['captain_picking_ui']
    if not ui then
        return
    end

    local list = ui['flow']['inner_frame']['scroll_pane']['picks_list']
    for _, child in ipairs(list.children) do
        local tags = child.tags
        if tags and tags.name == player then
            child.destroy()
        end
    end
end

---Iterate through a list of captains and try to destroy entry with player.
---If the picking list doesn't exist for a captain, it does nothing.
---@param names string[] List of captain names
---@param player string Name of player that was just picked.
function Public.try_destroy_picking_ui_list_entry_for_each(names, player)
    for _, name in ipairs(names) do
        local cpt = game.get_player(name)
        Public.try_destroy_picking_ui_list_entry(cpt, player)
    end
end

---Updates the title of the picking UI.
---@param cpt LuaPlayer Captain for whom we're going to update it.
---@param state integer State of UI for this captain
function Public.update_picking_ui_title(cpt, state)
    local title = cpt.gui.screen['captain_picking_ui']['title_root']['title']
    if state == CaptainStates.PICKS.RUNNING then
        title.caption = 'Who do you want to pick?'
    elseif state == CaptainStates.PICKS.IDLE then
        title.caption = 'The other captain is picking right now'
    else
        title.caption = 'Picking is paused right now'
    end
end

---Updates the state of the pick buttons in the picking UI.
---@param cpt LuaPlayer Captain for whom we're going to update it.
---@param state integer State of UI buttons for this captain
function Public.update_picking_ui_pick_buttons(cpt, state)
    ---Updates state of the picking button.
    ---@param button LuaGuiElement Button element
    local function update_state(button)
        local enabled = true
        local style = 'green_button'
        local tooltip = 'Click to select'
        if state == CaptainStates.PICKS.IDLE then
            enabled = false
            style = 'red_button'
            tooltip = 'Wait for your turn!'
        elseif state == CaptainStates.PICKS.PAUSED then
            enabled = false
            style = 'red_button'
            tooltip = 'Wait for the picking to be unpaused!'
        end

        button.enabled = enabled
        button.style = style
        button.style.width = 40
        button.tooltip = tooltip
    end

    ---Recursive helper function to find deeply nested pick buttons and
    ---change their state respectively.
    ---@param widget LuaGuiElement Any element under 'picks_list' parent.
    local function update_buttons(widget)
        if #widget.children == 0 then
            return
        end

        for _, child in ipairs(widget.children) do
            if child.type == 'sprite-button' then
                update_state(child)
            else
                update_buttons(child)
            end
        end
    end

    local list = cpt.gui.screen['captain_picking_ui']['flow']['inner_frame']['scroll_pane']['picks_list']
    update_buttons(list)
end

---Draws entire picking UI. Does nothing if it exists for a given player.
---Some fields are left uninitialized and require calling 'update' functions.
---@param player LuaPlayer?
function Public.draw_picking_ui(player)
    if player.gui.screen['captain_picking_ui'] then
        return
    end

    draw_picking_ui_base(player)
end

---Tries to destroy picking UI for a given player. If picking UI exists,
---we're also going to save it's location to draw it next time in the same
---location.
---@param player LuaPlayer Player for which we're going to destroy picking UI.
function Public.try_destroy_picking_ui(player)
    local name = 'captain_picking_ui'
    local special = storage.special_games_variables.captain_mode
    if player.gui.screen[name] then
        special.ui_picking_location[player.name] = player.gui.screen[name].location
        player.gui.screen[name].destroy()
    end
end

---Tries to destroy picking UI for a list of players.
---@param players LuaPlayer[]
function Public.try_destroy_picking_ui_for_each(players)
    for _, p in pairs(players) do
        Public.try_destroy_picking_ui(p)
    end
end

---Draws a single numeric textfield.
---@param parent LuaGuiElement Parent widget
---@param caption string Description of the field
---@param value string Value set in the field.
---@param name string Name of the textfield.
local function draw_referee_ui_pick_timer_numeric_field(parent, caption, value, name)
    local flow = parent.add({ type = 'flow', direction = 'horizontal' })
    flow.style.vertical_align = 'center'
    flow.add({ type = 'label', caption = '   ' .. caption })
    local field = flow.add({ type = 'textfield', name = name, allow_decimal = true, numeric = true })
    field.text = value
    field.style.maximal_width = 50
    flow.add({ type = 'label', caption = 'in seconds' })
end

---Draws option related to pick timer setting, before any picking phase.
---@param parent LuaGuiElement Parent widget
local function draw_referee_ui_pick_timer_startup(parent)
    local special = storage.special_games_variables.captain_mode
    local flow = parent.add({ type = 'flow', direction = 'horizontal' })
    flow.add({ type = 'label', caption = 'Picking timer is' })
    flow.add({
        type = 'switch',
        name = 'captain_pick_timer_enable',
        switch_state = special.captain_pick_timer_enabled and 'left' or 'right',
        left_label_caption = 'enabled',
        right_label_caption = 'disabled',
    })

    if special.captain_pick_timer_enabled then
        flow = parent.add({ type = 'flow', direction = 'vertical', style = 'packed_vertical_flow' })
        draw_referee_ui_pick_timer_numeric_field(
            flow,
            'Initial timer value',
            tostring(special.captain_pick_timer_base / 60),
            'captain_pick_timer_base'
        )
        draw_referee_ui_pick_timer_numeric_field(
            flow,
            'Time gained per pick',
            tostring(special.captain_pick_timer_gain / 60),
            'captain_pick_timer_gain'
        )
        draw_referee_ui_pick_timer_numeric_field(
            flow,
            'Extra time for the first captain',
            tostring(special.captain_pick_timer_extra / 60),
            'captain_pick_timer_extra'
        )
    end
end

---Draws option related to pick timer setting, before any picking phase.
---@param parent LuaGuiElement Parent widget
local function draw_referee_ui_pick_timer_runtime(parent)
    local special = storage.special_games_variables.captain_mode
    if not special.captain_pick_timer_enabled then
        return
    end

    local flow = parent.add({ type = 'flow', direction = 'horizontal' })
    flow.add({ type = 'label', caption = 'Picking timer is' })
    flow.add({
        type = 'switch',
        name = 'captain_pick_timer_pause',
        switch_state = special.captain_pick_timer_paused and 'left' or 'right',
        left_label_caption = 'paused',
        right_label_caption = 'running',
    })
end

---Draw options related to pick timer manipulation.
---@param parent LuaGuiElement Parent widget
function Public.draw_referee_ui_pick_timer(parent)
    local special = storage.special_games_variables.captain_mode
    if special.prepaPhase and not special.initialPickingPhaseStarted then
        draw_referee_ui_pick_timer_startup(parent)
    end

    if special.pickingPhase then
        draw_referee_ui_pick_timer_runtime(parent)
    end
end

---Get string with estimated time for picks phase.
---Uses per-team SMA (Simple Moving Average) to track actual pick rates
---and project remaining time based on historical pace.
local function get_estimated_pick_duration()
    local special = storage.special_games_variables.captain_mode
    -- If timer is active then extra+base time is already factored in.
    local active = special.captain_pick_timer['north'] ~= nil
    local count = #special.listPlayers
    -- We can only estimate time if we have at least three players on the list or
    -- we're in pick phase.
    if count <= 2 and not active then
        return ''
    end

    -- Return early if initial picking phase is done
    if special.initialPickingPhaseStarted and not special.pickingPhase then
        return ''
    end

    if special.communityPickingMode then
        return 'Estimated picking phase duration: instantaneous'
    end

    -- Before picking starts, listPlayers includes future captains who won't be picked.
    -- After picking starts, captains are removed so count is accurate.
    local remaining_picks = active and count or (count - 2)

    local current_budget = 0
    for _, f in ipairs({ 'north', 'south' }) do
        current_budget = current_budget + (special.captain_pick_timer[f] or special.captain_pick_timer_base)
    end

    -- Check if we have enough SMA data
    local north_count = special.captain_pick_timer_sma_sum.north
    local south_count = special.captain_pick_timer_sma_sum.south
    local has_sma_data = (north_count > 0 and south_count > 0)

    local estimate
    if has_sma_data then
        local avg_sma_north = special.captain_pick_timer_sma_sum.north * remaining_picks / 2
        local avg_sma_south = special.captain_pick_timer_sma_sum.south * remaining_picks / 2
        estimate = avg_sma_north + avg_sma_south

        -- Cap to theoretical maximum (remaining timer budget + future gains)
        local theoretical_max = current_budget + remaining_picks * special.captain_pick_timer_gain
        estimate = math.min(estimate, theoretical_max)
    else
        -- Fallback: use time gain per pick
        -- Before picking starts, add the extra time given to the first captain.
        if not active then
            current_budget = current_budget + special.captain_pick_timer_extra
        end

        estimate = current_budget + (remaining_picks * special.captain_pick_timer_gain)
    end

    local text = 'Estimated picking phase duration: '
    if estimate == 0 then
        text = ''
    else
        text = text .. ticks_to_time(estimate)
    end

    return text
end

local ESTIMATE_TOOLTIP = [[Initially based on timer settings (time budget + gain per pick).
After several picks, uses simple moving average to refine the estimate.]]

---Draw estimate time of all picks if timer is enabled.
---@param parent LuaGuiElement Parent widget
function Public.draw_lobby_ui_estimate(parent)
    -- Due to how lobby UI is constructed, we always create estimation
    -- flow and just hide it. It's made visible if timer is enabled.
    local flow = parent.add({
        type = 'flow',
        name = 'captain_pick_timer_estimate_flow',
        direction = 'horizontal',
    })
    flow.style.vertical_align = 'center'
    flow.visible = false

    flow.add({
        type = 'label',
        name = 'estimate',
        caption = get_estimated_pick_duration(),
        style = 'label_with_left_padding',
    })

    local info = flow.add({
        type = 'label',
        caption = '[img=info]',
        tooltip = ESTIMATE_TOOLTIP,
    })
end

---Update estimate time of all picks if timer is enabled.
---@param parent LuaGuiElement Parent widget
function Public.update_lobby_ui_estimate(parent)
    local special = storage.special_games_variables.captain_mode
    local flow = parent['captain_pick_timer_estimate_flow']
    if not special.captain_pick_timer_enabled then
        flow.visible = false
        return
    end

    -- Is estimate available?
    local estimate = get_estimated_pick_duration()
    if #estimate == 0 then
        flow.visible = false
        return
    end

    flow.visible = true
    flow['estimate'].caption = estimate
end

return Public
