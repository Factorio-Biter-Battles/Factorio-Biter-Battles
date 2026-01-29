local Event         = require('utils.event')
local Global        = require('utils.global')
local safe_wrap_cmd = require('utils.utils').safe_wrap_cmd

local Public = {}

local TEAMS           = { 'north', 'south' }
local MAX_ROWS        = 8
local ICON_COLS       = 4
local ICON_SIZE       = 26
local BTN_SIZE        = 20
local NAME_MAX_CHARS  = 6
local DIMMED          = { r = 0.6, g = 0.6, b = 0.6 }
local UNDIMMED        = { r = 1, g = 1, b = 1 }
local GRAY            = { r = 0.8, g = 0.8, b = 0.8 }

local this = {
  forces       = { north = {}, south = {} },
  ui_frames    = {},
  watchlist    = {},
  view_id_next = 1,
  sprite_cache = {},
}

Global.register(this, function(t) this = t end)

local function set_size(elem, w, h)
  h = h or w
  elem.style.width, elem.style.height = w, h
  elem.style.minimal_width, elem.style.minimal_height = w, h
  elem.style.maximal_width, elem.style.maximal_height = w, h
end

local function for_each_team(fn)
  for _, team in ipairs(TEAMS) do fn(team) end
end

local function get_player(id)
  local p = game.get_player(id)
  return (p and p.valid and p.connected) and p or nil
end

local function player_team(p_idx)
  for _, team in ipairs(TEAMS) do
    if this.forces[team][p_idx] then return team end
  end
  return nil
end

local function ellipsize(s, n)
  if not s or #s <= n then return s or '' end
  return s:sub(1, n) .. '...'
end

local function recipe_sprite(name)
  if not name then return nil end
  local cached = this.sprite_cache[name]
  if cached then return cached end
  cached = 'recipe/' .. name
  this.sprite_cache[name] = cached
  return cached
end

local function get_watchlist(view_id)
  this.watchlist[view_id] = this.watchlist[view_id] or {}
  return this.watchlist[view_id]
end

local function is_watching(view_id, p_idx)
  for _, id in ipairs(get_watchlist(view_id)) do
    if id == p_idx then return true end
  end
  return false
end

local function get_views_watching(p_idx)
  local views = {}
  for v_id, wl in pairs(this.watchlist) do
    for _, id in ipairs(wl) do
      if id == p_idx then views[#views + 1] = v_id; break end
    end
  end
  return views
end

local function get_queue_display(p_idx, just_crafted)
  local p = get_player(p_idx)
  local q = p and p.crafting_queue or {}
  local items, more = {}, 0
  local total = #q

  -- on_player_crafted_item fires before queue updates
  local offset, dec_head = 0, false
  if just_crafted and total > 0 then
    local head_count = q[1].count or 0
    if head_count == 1 then
      offset = 1
    elseif head_count > 1 then
      dec_head = true
    end
  end

  local visible = math.max(0, total - offset)
  local max_icons = ICON_COLS * 2

  for i = 1, max_icons do
    local qi = i + offset
    if qi <= total then
      local entry = q[qi]
      local rec = entry and entry.recipe
      local name = rec and (rec.name or rec)
      local count = entry.count or 0
      if dec_head and i == 1 and count > 0 then
        count = count - 1
      end
      items[i] = { sprite = recipe_sprite(name), count = count }
    else
      items[i] = { sprite = nil, count = 0 }
    end
  end

  if visible > max_icons then
    more = visible - max_icons
  end

  return items, more
end

local function get_candidates(team, view_id)
  local items, map = {}, {}
  for p_idx in pairs(this.forces[team]) do
    if not is_watching(view_id, p_idx) then
      local p = get_player(p_idx)
      if p then
        items[#items + 1] = { name = p.name, id = p_idx }
      end
    end
  end
  table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)

  local names = {}
  for i, c in ipairs(items) do
    names[i] = c.name
    map[i] = c.id
  end
  return names, map
end

local function refresh_dropdown(view_id, team)
  local ui = this.ui_frames[view_id]
  if not ui then return end
  local panel = ui.teams[team]
  if not (panel and panel.dd and panel.dd.valid) then return end

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

local function refresh_all_dropdowns(view_id)
  for_each_team(function(team) refresh_dropdown(view_id, team) end)
end

local function create_row(parent, view_id, team, p_idx, just_crafted)
  local p = get_player(p_idx)
  local name = p and p.name or ('#' .. p_idx)
  local items, more = get_queue_display(p_idx, just_crafted)
  local idle = items[1].sprite == nil

  -- name + buttons
  local left = parent.add { type = 'flow', direction = 'horizontal' }
  left.style.vertical_align = 'center'

  local label = left.add { type = 'label', caption = ellipsize(name, NAME_MAX_CHARS), tooltip = name }
  label.style.font = 'default-small-bold'
  label.style.font_color = idle and DIMMED or UNDIMMED
  label.style.minimal_width = NAME_MAX_CHARS * 8
  label.style.maximal_width = NAME_MAX_CHARS * 8

  local function make_btn(btn_name, sprite, tooltip, tags)
    local btn = left.add {
      type = 'sprite-button', name = btn_name,
      sprite = sprite, tooltip = tooltip, style = 'tool_button'
    }
    set_size(btn, BTN_SIZE)
    btn.tags = tags
    return btn
  end

  make_btn('cql_move_up', 'utility/hint_arrow_up', 'Move up',
    { view_id = view_id, team = team, p_idx = p_idx, delta = -1 })
  make_btn('cql_move_down', 'utility/hint_arrow_down', 'Move down',
    { view_id = view_id, team = team, p_idx = p_idx, delta = 1 })
  make_btn('cql_remove', 'utility/trash', 'Remove',
    { view_id = view_id, team = team, p_idx = p_idx })

  -- icons
  local grid = parent.add { type = 'table', column_count = ICON_COLS }
  grid.style.horizontal_spacing, grid.style.vertical_spacing = 1, 0

  local max_icons = ICON_COLS * 2
  for i = 1, max_icons do
    local it = items[i]
    local btn = grid.add { type = 'sprite-button', style = 'slot_button' }
    btn.ignored_by_interaction = true
    set_size(btn, ICON_SIZE)
    btn.sprite = it.sprite
    btn.number = it.sprite and it.count or 0
    -- tint last icon if overflow
    if i == max_icons and more > 0 then
      btn.style = 'yellow_slot_button'
      btn.tooltip = '+' .. more .. ' more'
    end
  end

  return { left = left, grid = grid, label = label }
end

local function rebuild_team_rows(view_id, team)
  local ui = this.ui_frames[view_id]
  if not ui then return end
  local panel = ui.teams[team]
  if not panel then return end

  panel.rows.clear()

  local wl = get_watchlist(view_id)
  local team_players = {}
  for _, p_idx in ipairs(wl) do
    if this.forces[team][p_idx] then
      team_players[#team_players + 1] = p_idx
    end
  end

  local visible = math.min(#team_players, MAX_ROWS)
  for i = 1, visible do
    create_row(panel.rows, view_id, team, team_players[i], false)
  end

  local overflow = #team_players - MAX_ROWS
  if overflow > 0 then
    panel.rows.add { type = 'label', caption = '' }
    local more = panel.rows.add { type = 'label', caption = '+' .. overflow .. ' more players' }
    more.style.font_color = GRAY
  end
end

local function rebuild_all_rows(view_id)
  for_each_team(function(team) rebuild_team_rows(view_id, team) end)
end

local function update_player_crafting(p_idx, just_crafted)
  local team = player_team(p_idx)
  if not team then return end

  for _, v_id in ipairs(get_views_watching(p_idx)) do
    local ui = this.ui_frames[v_id]
    if not (ui and ui.teams[team]) then goto continue end

    local panel = ui.teams[team]
    local items, more = get_queue_display(p_idx, just_crafted)
    local idle = items[1].sprite == nil
    local max_icons = ICON_COLS * 2

    local wl = get_watchlist(v_id)
    local row_idx = 0
    for _, id in ipairs(wl) do
      if this.forces[team][id] then
        row_idx = row_idx + 1
        if id == p_idx and row_idx <= MAX_ROWS then
          local left_idx = (row_idx - 1) * 2 + 1
          local grid_idx = left_idx + 1
          local children = panel.rows.children

          if children[left_idx] and children[grid_idx] then
            local left = children[left_idx]
            if left.children[1] then
              left.children[1].style.font_color = idle and DIMMED or UNDIMMED
            end
            local grid = children[grid_idx]
            for i = 1, max_icons do
              local it = items[i]
              local icon = grid.children[i]
              if icon then
                icon.sprite = it.sprite
                icon.number = it.sprite and it.count or 0
                if i == max_icons then
                  icon.style = more > 0 and 'yellow_slot_button' or 'slot_button'
                  icon.tooltip = more > 0 and ('+' .. more .. ' more') or ''
                  set_size(icon, ICON_SIZE)
                end
              end
            end
          end
          break
        end
      end
    end
    ::continue::
  end
end

local function watchlist_add(view_id, p_idx)
  if is_watching(view_id, p_idx) then return false end
  local wl = get_watchlist(view_id)
  wl[#wl + 1] = p_idx
  return true
end

local function watchlist_remove(view_id, p_idx)
  local wl = get_watchlist(view_id)
  for i = #wl, 1, -1 do
    if wl[i] == p_idx then
      table.remove(wl, i)
      return true
    end
  end
  return false
end

local function watchlist_move(view_id, p_idx, delta)
  local wl = get_watchlist(view_id)
  local from
  for i, id in ipairs(wl) do
    if id == p_idx then from = i; break end
  end
  if not from then return false end

  local to = from + delta
  if to < 1 or to > #wl then return false end
  wl[from], wl[to] = wl[to], wl[from]
  return true
end

local function create_team_panel(parent, team, view_id)
  local frame = parent.add { type = 'frame', direction = 'vertical' }
  frame.style.padding = 2

  local header = frame.add { type = 'flow', direction = 'horizontal' }
  header.style.vertical_align = 'center'

  local title = header.add { type = 'label', caption = team:sub(1,1):upper() .. team:sub(2) }
  title.style.font = 'default-bold'

  local spacer = header.add { type = 'empty-widget' }
  spacer.style.horizontally_stretchable = true

  local names, map = get_candidates(team, view_id)
  local has_candidates = #names > 0
  local dd = header.add {
    type = 'drop-down', name = 'cql_dropdown_' .. team,
    items = names,
  }
  dd.tags = { team = team, view_id = view_id }
  dd.selected_index = has_candidates and 1 or 0
  dd.enabled = has_candidates

  local add_btn = header.add {
    type = 'sprite-button', name = 'cql_add_' .. team,
    sprite = 'utility/add', tooltip = 'Add player', style = 'tool_button'
  }
  add_btn.tags = { team = team, view_id = view_id }
  add_btn.enabled = has_candidates

  local rows = frame.add { type = 'table', column_count = 2 }
  rows.style.vertical_spacing = 0
  rows.style.horizontal_spacing = 2

  return {
    frame = frame, dd = dd, dd_map = map, add_btn = add_btn, rows = rows,
  }
end

local function default_location(player)
  local res = player.display_resolution
  local scale = player.display_scale or 1
  local w = (res.width or 1280) / scale
  return { x = math.max(8, math.floor(w - 520)), y = 60 }
end

local function create_window(player)
  local v_id = this.view_id_next
  this.view_id_next = this.view_id_next + 1

  local win = player.gui.screen.add {
    type = 'frame', name = 'cql_window_' .. v_id, direction = 'vertical'
  }
  win.location = default_location(player)

  local titlebar = win.add { type = 'flow', direction = 'horizontal' }
  titlebar.drag_target = win

  local title = titlebar.add { type = 'label', caption = 'Crafting Queues', style = 'frame_title' }
  title.drag_target = win

  local drag = titlebar.add { type = 'empty-widget', style = 'draggable_space_header' }
  drag.style.height = 24
  drag.style.horizontally_stretchable = true
  drag.drag_target = win

  local close = titlebar.add {
    type = 'sprite-button', name = 'cql_close',
    sprite = 'utility/close_black', style = 'frame_action_button'
  }
  close.tags = { view_id = v_id }

  local content = win.add { type = 'flow', direction = 'vertical' }
  content.style.vertical_spacing = 2

  local teams = {}
  for_each_team(function(team)
    teams[team] = create_team_panel(content, team, v_id)
  end)

  this.ui_frames[v_id] = {
    root = win, owner = player.index, teams = teams
  }
  this.watchlist[v_id] = {}

  return v_id
end

local function destroy_window(view_id)
  local ui = this.ui_frames[view_id]
  if ui and ui.root and ui.root.valid then
    ui.root.destroy()
  end
  this.ui_frames[view_id] = nil
  this.watchlist[view_id] = nil
end

local function get_player_view(player)
  for v_id, ui in pairs(this.ui_frames) do
    if ui.owner == player.index then return v_id end
  end
  return nil
end

local function toggle_window(player)
  local existing = get_player_view(player)
  if existing then
    destroy_window(existing)
  else
    create_window(player)
  end
end

local function rebuild_forces()
  this.forces = { north = {}, south = {} }
  for _, p in pairs(game.players) do
    if p and p.valid then
      local fname = p.force and p.force.name
      if fname == 'north' or fname == 'south' then
        this.forces[fname][p.index] = true
      end
    end
  end
  for v_id in pairs(this.ui_frames) do
    refresh_all_dropdowns(v_id)
  end
end

commands.add_command('crafting_list', 'Toggle Crafting List window', function(cmd)
  safe_wrap_cmd(cmd, function()
    local p = game.get_player(cmd.player_index)
    if p and p.valid then toggle_window(p) end
  end, cmd)
end)

Event.add(defines.events.on_player_joined_game, function(ev)
  local p = game.get_player(ev.player_index)
  if p and p.valid then rebuild_forces() end
end)

Event.add(defines.events.on_player_left_game, function()
  rebuild_forces()
end)

Event.add(defines.events.on_player_changed_force, function(ev)
  rebuild_forces()
  for v_id in pairs(this.ui_frames) do
    rebuild_all_rows(v_id)
  end
end)

Event.add(defines.events.on_gui_click, function(ev)
  local e = ev.element
  if not (e and e.valid) then return end
  local player = game.get_player(ev.player_index)
  if not (player and player.valid) then return end
  local name = e.name
  local tags = e.tags or {}

  if name == 'cql_close' then
    if tags.view_id then destroy_window(tags.view_id) end
    return
  end

  if name:match('^cql_add_') then
    local view_id, team = tags.view_id, tags.team
    if not (view_id and team) then return end

    local ui = this.ui_frames[view_id]
    if not ui then return end
    local panel = ui.teams[team]
    if not (panel and panel.dd and panel.dd.valid) then return end

    local idx = panel.dd.selected_index or 0
    local p_idx = panel.dd_map and panel.dd_map[idx]
    if not p_idx then return end

    if watchlist_add(view_id, p_idx) then
      refresh_all_dropdowns(view_id)
      rebuild_team_rows(view_id, team)
    end
    return
  end

  if name == 'cql_remove' then
    local view_id, team, p_idx = tags.view_id, tags.team, tags.p_idx
    if not (view_id and team and p_idx) then return end

    watchlist_remove(view_id, p_idx)
    refresh_all_dropdowns(view_id)
    rebuild_team_rows(view_id, team)
    return
  end

  if name == 'cql_move_up' or name == 'cql_move_down' then
    local view_id, team, p_idx = tags.view_id, tags.team, tags.p_idx
    local delta = tags.delta or 0
    if not (view_id and team and p_idx and delta ~= 0) then return end

    if watchlist_move(view_id, p_idx, delta) then
      rebuild_team_rows(view_id, team)
    end
    return
  end
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
  for v_id in pairs(this.ui_frames) do destroy_window(v_id) end
  this.ui_frames = {}
  this.watchlist = {}
  this.forces = { north = {}, south = {} }
  this.view_id_next = 1
  this.sprite_cache = {}
end

return Public
