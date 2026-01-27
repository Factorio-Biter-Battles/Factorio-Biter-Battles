local CaptainUtils = require('comfy_panel.special_games.captain_utils')
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
    local l = flow.add({
        type = 'label',
        caption = player_name,
        style = 'tooltip_label',
        tags = tags,
    })
    local color = PlayerUtils.get_suitable_ui_color(cpt_get_player(player_name))
    l.style.font_color = color
    l.style.minimal_width = 100
    l.style.horizontal_align = 'center'

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
    draw_picking_ui_list(frame)
end

---Removes a player from the pick list if it exists.
---@param cpt LuaPlayer Captain for whom we're updating the list.
---@param player string Name of a player that was just picked.
function Public.try_update_picking_ui_list(cpt, player)
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

---Iterate through a list of captains and try to update the picking list.
---If the picking list doesn't exist for a captain, it does nothing.
---@param names string[] List of captain names
---@param player string Name of player that was just picked.
function Public.try_update_picking_ui_list_for_each(names, player)
    for _, name in ipairs(names) do
        local cpt = game.get_player(name)
        Public.try_update_picking_ui_list(cpt, player)
    end
end

---Updates the title of the picking UI.
---@param cpt LuaPlayer Captain for whom we're going to update it.
---@param picking boolean If this captain is currently picking or not.
function Public.update_picking_ui_title(cpt, picking)
    local title = cpt.gui.screen['captain_picking_ui']['title_root']['title']
    if picking then
        title.caption = 'Who do you want to pick?'
    else
        title.caption = 'The other captain is picking right now'
    end
end

---Updates the state of the pick buttons in the picking UI.
---@param cpt LuaPlayer Captain for whom we're going to update it.
---@param enabled boolean New state of buttons
function Public.update_picking_ui_pick_buttons(cpt, enabled)
    ---Updates state of the picking button.
    ---@param button LuaGuiElement Button element
    local function update_state(button)
        local style = 'green_button'
        local tooltip = 'Click to select'
        if not enabled then
            style = 'red_button'
            tooltip = 'Wait for your turn!'
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

return Public
