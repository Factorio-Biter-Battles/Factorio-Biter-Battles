local Event = require('utils.event')
local Global = require('utils.global')
local safe_wrap_cmd = require('utils.utils').safe_wrap_cmd

local Public = {}

local TEAMS = { 'north', 'south' }
local MAX_ROWS = 8
local ICON_COLS = 4
local MAX_ICONS = ICON_COLS * 2
local ICON_SIZE = 26
local BTN_SIZE = 20
local NAME_MAX_CHARS = 10
local DIMMED = { r = 0.6, g = 0.6, b = 0.6 }
local UNDIMMED = { r = 1, g = 1, b = 1 }
local GRAY = { r = 0.8, g = 0.8, b = 0.8 }
local EMPTY_ICON = { sprite = nil, count = 0 }

---@class CqlTeamPanel
---@field frame LuaGuiElement
---@field dd LuaGuiElement
---@field dd_map table<integer, uint>
---@field add_btn LuaGuiElement
---@field rows LuaGuiElement

---@class CqlUiFrame
---@field root LuaGuiElement
---@field owner uint
---@field teams table<string, CqlTeamPanel>
---@field show_intermediates boolean

---@class CqlQueueItem
---@field sprite string?
---@field count number

---@class CqlTags
---@field view_id integer?
---@field team string?
---@field p_idx uint?
---@field delta integer?

---@class CqlState
---@field ui_frames table<integer, CqlUiFrame>
---@field watchlist table<integer, table<uint, integer>>
---@field view_id_next integer

---@type CqlState
local this = {
    ui_frames = {},
    watchlist = {},
    view_id_next = 1,
}

---@type table<string, string>
local sprite_cache = {}

Global.register(this, function(t)
    this = t
end)

---@param elem LuaGuiElement
---@param w number
---@param h number?
local function set_size(elem, w, h)
    h = h or w
    elem.style.width, elem.style.height = w, h
    elem.style.minimal_width, elem.style.minimal_height = w, h
    elem.style.maximal_width, elem.style.maximal_height = w, h
end

---@param fn fun(team: string)
local function for_each_team(fn)
    for _, team in ipairs(TEAMS) do
        fn(team)
    end
end

---@param id uint
---@return LuaPlayer?
local function get_player(id)
    local p = game.get_player(id)
    return (p and p.valid and p.connected) and p or nil
end

---@param p_idx uint
---@return string?
local function player_team(p_idx)
    local p = game.get_player(p_idx)
    if not p then
        return nil
    end
    local team = storage.chosen_team[p.name]
    if team == 'north' or team == 'south' then
        return team
    end
    return nil
end

---@param s string?
---@param n integer
---@return string
local function ellipsize(s, n)
    if not s or #s <= n then
        return s or ''
    end
    return s:sub(1, n) .. '...'
end

---@param name string?
---@return string?
local function recipe_sprite(name)
    if not name then
        return nil
    end
    local cached = sprite_cache[name]
    if cached then
        return cached
    end
    cached = 'recipe/' .. name
    sprite_cache[name] = cached
    return cached
end

---@param view_id integer
---@return uint[]
local function get_watchlist(view_id)
    this.watchlist[view_id] = this.watchlist[view_id] or {}
    return this.watchlist[view_id]
end

---@param view_id integer
---@return uint[]
local function get_ordered_watchlist(view_id)
    local wl = get_watchlist(view_id)
    local entries = {}
    for p_idx, order in pairs(wl) do
        entries[#entries + 1] = { p_idx = p_idx, order = order }
    end
    table.sort(entries, function(a, b)
        return a.order < b.order
    end)
    local result = {}
    for i, e in ipairs(entries) do
        result[i] = e.p_idx
    end
    return result
end

---@param view_id integer
---@param p_idx uint
---@return boolean
local function is_watching(view_id, p_idx)
    return get_watchlist(view_id)[p_idx] ~= nil
end

---@param p_idx uint
---@return integer[]
local function get_views_watching(p_idx)
    local views = {}
    for v_id, wl in pairs(this.watchlist) do
        if wl[p_idx] then
            views[#views + 1] = v_id
        end
    end
    return views
end

---@param p_idx uint
---@param just_crafted boolean
---@param show_intermediates boolean?
---@return CqlQueueItem[], integer
local function get_queue_display(p_idx, just_crafted, show_intermediates)
    local p = get_player(p_idx)
    local q = p and p.crafting_queue or {}
    local items, more = {}, 0
    local total = #q

    -- on_player_crafted_item fires before queue updates
    local skip_first, dec_head = false, false
    if just_crafted and total > 0 and not q[1].prerequisite then
        local head_count = q[1].count or 0
        if head_count == 1 then
            skip_first = true
        elseif head_count > 1 then
            dec_head = true
        end
    end

    local slot, visible = 0, 0
    for qi = 1, total do
        local entry = q[qi]
        if not show_intermediates and entry.prerequisite then
            goto next
        end
        if skip_first then
            skip_first = false
            goto next
        end
        visible = visible + 1
        if slot >= MAX_ICONS then
            goto next
        end
        slot = slot + 1
        local rec = entry.recipe
        local count = (entry.count or 0) - (dec_head and slot == 1 and 1 or 0)
        items[slot] = { sprite = recipe_sprite(rec and (rec.name or rec)), count = count }
        ::next::
    end

    for i = slot + 1, MAX_ICONS do
        items[i] = EMPTY_ICON
    end

    if visible > MAX_ICONS then
        more = visible - MAX_ICONS
    end

    return items, more
end

---@param team string
---@param view_id integer
---@return string[], table<integer, uint>
local function get_candidates(team, view_id)
    local items, map = {}, {}
    for _, p in pairs(game.connected_players) do
        if storage.chosen_team[p.name] == team and not is_watching(view_id, p.index) then
            items[#items + 1] = { name = p.name, id = p.index }
        end
    end
    table.sort(items, function(a, b)
        return a.name:lower() < b.name:lower()
    end)

    local names = {}
    for i, c in ipairs(items) do
        names[i] = c.name
        map[i] = c.id
    end
    return names, map
end

---@param view_id integer
---@param team string
local function refresh_dropdown(view_id, team)
    local ui = this.ui_frames[view_id]
    if not ui then
        return
    end
    local panel = ui.teams[team]
    if not (panel and panel.dd and panel.dd.valid) then
        return
    end

    local items, map = get_candidates(team, view_id)
    panel.dd.items = items
    panel.dd_map = map
    local has_candidates = #items > 0
    panel.dd.selected_index = has_candidates and 1 or 0
    panel.dd.enabled = has_candidates
    if panel.add_btn and panel.add_btn.valid then
        panel.add_btn.enabled = has_candidates
    end
end

---@param view_id integer
local function refresh_all_dropdowns(view_id)
    for_each_team(function(team)
        refresh_dropdown(view_id, team)
    end)
end

---@param parent LuaGuiElement
---@param view_id integer
---@param team string
---@param p_idx uint
---@param just_crafted boolean
---@return {row: LuaGuiElement, grid: LuaGuiElement, label: LuaGuiElement}
local function create_row(parent, view_id, team, p_idx, just_crafted)
    local p = get_player(p_idx)
    local name = p and p.name or ('#' .. p_idx)
    local ui = this.ui_frames[view_id]
    local show_inter = ui and ui.show_intermediates or false
    local items, more = get_queue_display(p_idx, just_crafted, show_inter)
    local idle = items[1].sprite == nil

    local row = parent.add({ type = 'flow', direction = 'vertical' })

    -- header: name + buttons
    local header = row.add({ type = 'flow', direction = 'horizontal' })
    header.style.vertical_align = 'center'

    local label = header.add({ type = 'label', caption = name, tooltip = name })
    label.style.font = 'default-small-bold'
    label.style.font_color = idle and DIMMED or UNDIMMED

    local spacer = header.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true

    local function make_btn(btn_name, sprite, tooltip, tags)
        local btn = header.add({
            type = 'sprite-button',
            name = btn_name,
            sprite = sprite,
            tooltip = tooltip,
            style = 'tool_button',
        })
        set_size(btn, BTN_SIZE)
        btn.tags = tags
        return btn
    end

    make_btn(
        'cql_move_up',
        'utility/hint_arrow_up',
        'Move up',
        { view_id = view_id, team = team, p_idx = p_idx, delta = -1 }
    )
    make_btn(
        'cql_move_down',
        'utility/hint_arrow_down',
        'Move down',
        { view_id = view_id, team = team, p_idx = p_idx, delta = 1 }
    )
    make_btn('cql_remove', 'utility/trash', 'Remove', { view_id = view_id, team = team, p_idx = p_idx })

    -- icons row
    local grid = row.add({ type = 'table', column_count = MAX_ICONS })
    grid.style.horizontal_spacing = 1

    for i = 1, MAX_ICONS do
        local it = items[i] or EMPTY_ICON
        local btn = grid.add({ type = 'sprite-button', style = 'slot_button' })
        btn.ignored_by_interaction = true
        btn.sprite = it.sprite
        btn.number = it.sprite and it.count or 0
        if i == MAX_ICONS and more > 0 then
            btn.style = 'yellow_slot_button'
            btn.tooltip = '+' .. more .. ' more'
        end
        set_size(btn, ICON_SIZE)
    end

    return { row = row, grid = grid, label = label }
end

---@param view_id integer
---@param team string
local function rebuild_team_rows(view_id, team)
    local ui = this.ui_frames[view_id]
    if not ui then
        return
    end
    local panel = ui.teams[team]
    if not panel or not panel.frame or not panel.frame.valid then
        return
    end

    -- Destroy and recreate rows container to avoid layout issues
    if panel.rows and panel.rows.valid then
        panel.rows.destroy()
    end
    panel.rows = panel.frame.add({ type = 'flow', direction = 'vertical' })
    panel.rows.style.vertical_spacing = 2

    local wl = get_ordered_watchlist(view_id)
    local team_players = {}
    for _, p_idx in ipairs(wl) do
        local p = game.get_player(p_idx)
        if p and storage.chosen_team[p.name] == team then
            team_players[#team_players + 1] = p_idx
        end
    end

    local visible = math.min(#team_players, MAX_ROWS)
    for i = 1, visible do
        create_row(panel.rows, view_id, team, team_players[i], false)
    end

    local overflow = #team_players - MAX_ROWS
    if overflow > 0 then
        panel.rows.add({ type = 'label', caption = '' })
        local more = panel.rows.add({ type = 'label', caption = '+' .. overflow .. ' more players' })
        more.style.font_color = GRAY
    end
end

---@param view_id integer
local function rebuild_all_rows(view_id)
    for_each_team(function(team)
        rebuild_team_rows(view_id, team)
    end)
end

---@param v_id integer
---@param team string
---@param p_idx uint
---@return integer?
local function find_player_row_index(v_id, team, p_idx)
    local wl = get_ordered_watchlist(v_id)
    local row_idx = 0

    for _, id in ipairs(wl) do
        local wp = game.get_player(id)
        if not wp or storage.chosen_team[wp.name] ~= team then
            goto next_player
        end

        row_idx = row_idx + 1
        if id == p_idx and row_idx <= MAX_ROWS then
            return row_idx
        end

        ::next_player::
    end
    return nil
end

---@param panel CqlTeamPanel
---@param row_idx integer
---@param items CqlQueueItem[]
---@param more integer
---@param idle boolean
local function update_row_ui(panel, row_idx, items, more, idle)
    if not panel.rows or not panel.rows.valid then
        return
    end
    local row = panel.rows.children[row_idx]
    if not row then
        return
    end
    local header = row.children[1]
    local grid = row.children[2]
    if not header or not grid then
        return
    end
    local label = header.children[1]
    if label then
        label.style.font_color = idle and DIMMED or UNDIMMED
    end

    for i = 1, MAX_ICONS do
        local icon = grid.children[i]
        if not icon then
            goto next_icon
        end
        local it = items[i] or EMPTY_ICON
        icon.sprite = it.sprite
        icon.number = it.sprite and it.count or 0
        if i == MAX_ICONS then
            icon.style = more > 0 and 'yellow_slot_button' or 'slot_button'
            icon.tooltip = more > 0 and ('+' .. more .. ' more') or ''
            set_size(icon, ICON_SIZE)
        end
        ::next_icon::
    end
end

---@param p_idx uint
---@param just_crafted boolean
local function update_player_crafting(p_idx, just_crafted)
    local team = player_team(p_idx)
    if not team then
        return
    end

    local views = get_views_watching(p_idx)
    if #views == 0 then
        return
    end

    for _, v_id in ipairs(views) do
        local ui = this.ui_frames[v_id]
        if not (ui and ui.teams[team]) then
            goto continue
        end

        local row_idx = find_player_row_index(v_id, team, p_idx)
        if row_idx then
            local show_inter = ui.show_intermediates or false
            local items, more = get_queue_display(p_idx, just_crafted, show_inter)
            local idle = items[1].sprite == nil
            update_row_ui(ui.teams[team], row_idx, items, more, idle)
        end

        ::continue::
    end
end

---@param view_id integer
---@param p_idx uint
---@return boolean
local function watchlist_add(view_id, p_idx)
    local wl = get_watchlist(view_id)
    if wl[p_idx] then
        return false
    end
    local max_order = 0
    for _, order in pairs(wl) do
        if order > max_order then
            max_order = order
        end
    end
    wl[p_idx] = max_order + 1
    return true
end

---@param view_id integer
---@param p_idx uint
---@return boolean
local function watchlist_remove(view_id, p_idx)
    local wl = get_watchlist(view_id)
    local removed_order = wl[p_idx]
    if not removed_order then
        return false
    end
    wl[p_idx] = nil
    for idx, order in pairs(wl) do
        if order > removed_order then
            wl[idx] = order - 1
        end
    end
    return true
end

---@param view_id integer
---@param p_idx uint
---@param delta integer
---@return boolean
local function watchlist_move(view_id, p_idx, delta)
    local wl = get_watchlist(view_id)
    local from_order = wl[p_idx]
    if not from_order then
        return false
    end
    local to_order = from_order + delta
    local swap_idx
    for idx, order in pairs(wl) do
        if order == to_order then
            swap_idx = idx
            break
        end
    end
    if not swap_idx then
        return false
    end
    wl[p_idx] = to_order
    wl[swap_idx] = from_order
    return true
end

---@param parent LuaGuiElement
---@param team string
---@param view_id integer
---@return CqlTeamPanel
local function create_team_panel(parent, team, view_id)
    local frame = parent.add({ type = 'frame', direction = 'vertical' })
    frame.style.padding = 2

    local header = frame.add({ type = 'flow', direction = 'horizontal' })
    header.style.vertical_align = 'center'

    local title = header.add({ type = 'label', caption = team:sub(1, 1):upper() .. team:sub(2) })
    title.style.font = 'default-bold'

    local spacer = header.add({ type = 'empty-widget' })
    spacer.style.horizontally_stretchable = true

    local names, map = get_candidates(team, view_id)
    local has_candidates = #names > 0
    local dd = header.add({
        type = 'drop-down',
        name = 'cql_dropdown_' .. team,
        items = names,
    })
    dd.tags = { team = team, view_id = view_id }
    dd.selected_index = has_candidates and 1 or 0
    dd.enabled = has_candidates

    local add_btn = header.add({
        type = 'sprite-button',
        name = 'cql_add_' .. team,
        sprite = 'utility/add',
        tooltip = 'Add player',
        style = 'tool_button',
    })
    add_btn.tags = { team = team, view_id = view_id }
    add_btn.enabled = has_candidates

    local rows = frame.add({ type = 'flow', direction = 'vertical' })
    rows.style.vertical_spacing = 2

    return {
        frame = frame,
        dd = dd,
        dd_map = map,
        add_btn = add_btn,
        rows = rows,
    }
end

---@param player LuaPlayer
---@return {x: number, y: number}
local function default_location(player)
    local res = player.display_resolution
    local scale = player.display_scale or 1
    local w = (res.width or 1280) / scale
    return { x = math.max(8, math.floor(w - 520)), y = 60 }
end

---@param player LuaPlayer
---@return integer view_id
local function create_window(player)
    local v_id = this.view_id_next
    this.view_id_next = this.view_id_next + 1

    local win = player.gui.screen.add({
        type = 'frame',
        name = 'cql_window',
        direction = 'vertical',
    })
    win.location = default_location(player)

    local titlebar = win.add({ type = 'flow', direction = 'horizontal' })
    titlebar.drag_target = win

    local title = titlebar.add({ type = 'label', caption = 'Crafting Queues', style = 'frame_title' })
    title.drag_target = win

    local drag = titlebar.add({ type = 'empty-widget', style = 'draggable_space_header' })
    drag.style.height = 24
    drag.style.horizontally_stretchable = true
    drag.drag_target = win

    local inter_cb = titlebar.add({
        type = 'checkbox',
        name = 'cql_show_intermediates',
        caption = 'Int',
        tooltip = 'Show intermediate products',
        state = true,
    })
    inter_cb.tags = { view_id = v_id }

    local close = titlebar.add({
        type = 'sprite-button',
        name = 'cql_close',
        sprite = 'utility/close_black',
        style = 'frame_action_button',
    })
    close.tags = { view_id = v_id }

    local content = win.add({ type = 'flow', direction = 'vertical' })
    content.style.vertical_spacing = 2

    local viewer_team = storage.chosen_team[player.name]
    local is_spectator = viewer_team ~= 'north' and viewer_team ~= 'south'

    local teams = {}
    for_each_team(function(team)
        if is_spectator or team == viewer_team then
            teams[team] = create_team_panel(content, team, v_id)
        end
    end)

    this.ui_frames[v_id] = {
        root = win,
        owner = player.index,
        teams = teams,
        show_intermediates = true,
    }
    this.watchlist[v_id] = {}

    return v_id
end

---@param view_id integer
local function destroy_window(view_id)
    local ui = this.ui_frames[view_id]
    if ui and ui.root and ui.root.valid then
        ui.root.destroy()
    end
    this.ui_frames[view_id] = nil
    this.watchlist[view_id] = nil
end

---@param player LuaPlayer
---@return integer?
local function get_player_view(player)
    for v_id, ui in pairs(this.ui_frames) do
        if ui.owner == player.index then
            return v_id
        end
    end
    return nil
end

---@param player LuaPlayer
local function toggle_window(player)
    local view_id = get_player_view(player)
    if view_id then
        destroy_window(view_id)
    else
        create_window(player)
    end
end

local function refresh_all_views()
    for v_id in pairs(this.ui_frames) do
        refresh_all_dropdowns(v_id)
    end
end

commands.add_command('crafting-list', 'Toggle Crafting List window', function(cmd)
    safe_wrap_cmd(cmd, function()
        local p = game.get_player(cmd.player_index)
        if p and p.valid then
            toggle_window(p)
        end
    end, cmd)
end)

Event.add(defines.events.on_player_joined_game, function()
    refresh_all_views()
end)

Event.add(defines.events.on_player_left_game, function()
    refresh_all_views()
end)

Event.add(defines.events.on_player_changed_force, function(ev)
    local player = game.get_player(ev.player_index)
    if player then
        local view_id = get_player_view(player)
        if view_id then
            destroy_window(view_id)
        end
    end
    refresh_all_views()
    for v_id in pairs(this.ui_frames) do
        rebuild_all_rows(v_id)
    end
end)

---@param tags CqlTags
local function on_close(tags)
    if tags.view_id then
        destroy_window(tags.view_id)
    end
end

---@param tags CqlTags
local function on_add(tags)
    local view_id, team = tags.view_id, tags.team
    if not (view_id and team) then
        return
    end

    local ui = this.ui_frames[view_id]
    if not ui then
        return
    end
    local panel = ui.teams[team]
    if not (panel and panel.dd and panel.dd.valid) then
        return
    end

    local idx = panel.dd.selected_index or 0
    local p_idx = panel.dd_map and panel.dd_map[idx]
    if not p_idx then
        return
    end

    if watchlist_add(view_id, p_idx) then
        refresh_all_dropdowns(view_id)
        rebuild_team_rows(view_id, team)
    end
end

---@param tags CqlTags
local function on_remove(tags)
    local view_id, team, p_idx = tags.view_id, tags.team, tags.p_idx
    if not (view_id and team and p_idx) then
        return
    end

    watchlist_remove(view_id, p_idx)
    refresh_all_dropdowns(view_id)
    rebuild_team_rows(view_id, team)
end

---@param tags CqlTags
local function on_move(tags)
    local view_id, team, p_idx = tags.view_id, tags.team, tags.p_idx
    local delta = tags.delta or 0
    if not (view_id and team and p_idx and delta ~= 0) then
        return
    end

    if watchlist_move(view_id, p_idx, delta) then
        rebuild_team_rows(view_id, team)
    end
end

local click_handlers = {
    cql_close = on_close,
    cql_remove = on_remove,
    cql_move_up = on_move,
    cql_move_down = on_move,
}

Event.add(defines.events.on_gui_click, function(ev)
    local e = ev.element
    if not (e and e.valid) then
        return
    end
    local name = e.name
    local tags = e.tags or {} ---@cast tags CqlTags

    local handler = click_handlers[name]
    if handler then
        handler(tags)
        return
    end

    if name:match('^cql_add_') then
        on_add(tags)
    end
end)

Event.add(defines.events.on_gui_checked_state_changed, function(ev)
    local e = ev.element
    if not (e and e.valid and e.name == 'cql_show_intermediates') then
        return
    end
    local tags = e.tags or {} ---@cast tags CqlTags
    local view_id = tags.view_id
    if not view_id then
        return
    end
    local ui = this.ui_frames[view_id]
    if not ui then
        return
    end
    ui.show_intermediates = e.state
    rebuild_all_rows(view_id)
end)

Event.add(defines.events.on_pre_player_crafted_item, function(ev)
    update_player_crafting(ev.player_index, false)
end)
Event.add(defines.events.on_player_crafted_item, function(ev)
    update_player_crafting(ev.player_index, true)
end)
Event.add(defines.events.on_player_cancelled_crafting, function(ev)
    update_player_crafting(ev.player_index, false)
end)

function Public.reset_crafting_queue_list()
    for v_id in pairs(this.ui_frames) do
        destroy_window(v_id)
    end
    this.ui_frames = {}
    this.watchlist = {}
    this.view_id_next = 1
end

function Public.on_team_changed(player)
    if player then
        local view_id = get_player_view(player)
        if view_id then
            destroy_window(view_id)
        end
    end
    refresh_all_views()
    for v_id in pairs(this.ui_frames) do
        rebuild_all_rows(v_id)
    end
end

return Public
