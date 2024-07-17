local Event = require 'utils.event'
local Gui = require 'utils.gui'
local gui_style = require 'utils.utils'.gui_style
local Tables = require 'maps.biter_battles_v2.tables'
local Color = require 'utils.color_presets'
local Functions = require 'maps.biter_battles_v2.functions'
local ResearchInfo = require 'maps.biter_battles_v2.research_info'
local Feeding = require 'maps.biter_battles_v2.feeding'
local TeamStatsCompare = require 'maps.biter_battles_v2.team_stats_compare'
local safe_wrap_with_player_print = require 'utils.utils'.safe_wrap_with_player_print
local math_floor = math.floor

local Public = {}

global.shortcuts_ui = global.shortcuts_ui or {}

Public.main_frame_name = 'bb_floating_shortcuts'
local main_frame_name = Public.main_frame_name

local function handle_spectator(player)
  local is_spectator = player.force.name == 'spectator'
  if is_spectator then
    player.print('This shortcut cannot be used while spectating')
    Sounds.notify_player(player, 'utility/cannot_build')
  end
  return is_spectator
end

local function show_teamstats(player)
  local frame = player.gui.screen.teamstats_frame

  if frame and frame.valid then
    if player.opened == frame then
        player.opened = nil
    end
    frame.destroy()
    return
  end

  local deny_reason = false
  -- allow it always in singleplayer, or if the game is over
  if global.bb_game_won_by_team and game.is_multiplayer() then
    if global.allow_teamstats == "spectators" then
      if player.force.name ~= "spectator" then deny_reason = "spectators only" end
    elseif global.allow_teamstats == "pure-spectators" then
      if global.chosen_team[player.name] then deny_reason = "pure spectators only (you have joined a team)" end
    else
      if global.allow_teamstats ~= "always" then deny_reason = "only allowed at end of game" end
    end
  end
  if deny_reason then
    player.print("Team stats for current game is unavailable: " .. deny_reason)
    Sounds.notify_player(player, "utility/cannot_build")
    return
  end
  safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player)
end

local function clear_corpses(player)
  local param = 160
  local pos = player.position
  local radius = { { x = (pos.x + -param), y = (pos.y + -param) }, { x = (pos.x + param), y = (pos.y + param) } }
  for _, entity in pairs(player.surface.find_entities_filtered { area = radius, type = 'corpse' }) do
    if entity.corpse_expires then
      entity.destroy()
    end
  end
  player.print('Cleared biter-corpses.', Color.success)
end

function get_player_preferences(player)
  local player_preferences = global.shortcuts_ui[player.name]
  if not player_preferences then
    player_preferences = { enabled = false }
    global.shortcuts_ui[player.name] = player_preferences
  end
  return player_preferences
end

local function add_shortcut_selection_row(player, parent, child)
  local row = parent.add { type = 'frame', style = 'shortcut_selection_row' }
  gui_style(row, { horizontally_stretchable = true, vertically_stretchable = false })

  local icon = row.add { type = 'sprite-button', style = 'transparent_slot', sprite = child.sprite, tooltip = child.tooltip }
  gui_style(icon, { width = 20, height = 20 })
  
  local player_preferences = get_player_preferences(player)
  if player_preferences[child.name] == nil then
    player_preferences[child.name] = true
  end

  local checkbox = row.add { type = 'checkbox', caption = child.caption, state = player_preferences[child.name], tags = { action = main_frame_name .. '_checkbox', name = child.name } }
  gui_style(checkbox, { horizontally_stretchable = true })

  -- TODO: add future logic to reorder the buttons
  --local drag = row.add { type = 'empty-widget', style = 'draggable_space_in_shortcut_list' }
  --gui_style(drag, { vertically_stretchable = true })
end

local function toggle_shortcuts_settings(player)
  local frame = Public.get_main_frame(player)
  frame.qbip.qbsp.visible = not frame.qbip.qbsp.visible
end

local main_frame_actions = {
  [main_frame_name..'_send_fish'] = function(player, event) if handle_spectator(player) then return end Functions.spy_fish(player, event) end,
  [main_frame_name..'_send_science'] = function(player, event) if handle_spectator(player) then return end  Feeding.feed_biters_mixed_from_inventory(player, event.button) end,
  [main_frame_name..'_research_info'] = function(player, event) ResearchInfo.show_research_info_handler(event) end,
  [main_frame_name..'_clear_corpses'] = function(player, event) clear_corpses(player) end,
  [main_frame_name..'_teamstats'] = function(player, event) show_teamstats(player) end,
  [main_frame_name..'_settings'] = function(player, event) toggle_shortcuts_settings(player) end,
}

local shortcut_buttons = {
  { name = main_frame_name..'_send_fish', caption = 'Send fish', sprite = 'item/raw-fish', tooltip = '[font=default-bold]Send fish[/font] - ' .. Tables.gui_foods['raw-fish'] },
  { name = main_frame_name..'_send_science', caption = 'Send science', sprite = 'item/automation-science-pack', tooltip = '[font=default-bold]Send science[/font] - Send all science packs in your inventory' },
  { name = main_frame_name..'_research_info', caption = 'Research info', sprite = 'item/lab', hovered_sprite = '', tooltip = '[font=default-bold]Research info[/font] - Toggle the research info UI' },
  { name = main_frame_name..'_teamstats', caption = 'Team statistics', sprite = 'utility/side_menu_production_icon', hovered_sprite = 'utility/side_menu_production_hover_icon', tooltip = '[font=default-bold]Team statistics[/font] - Toggle the team statistics UI' },
  { name = main_frame_name..'_clear_corpses', caption = 'Clear corpses', sprite = 'entity/behemoth-biter', hovered_sprite = '', tooltip = '[font=default-bold]Clear corpses[/font] - Clear biter corpses around you' },
}

function Public.get_main_frame(player)
  local main_frame = player.gui.screen[main_frame_name]
  if not main_frame or not main_frame.valid then
    main_frame = player.gui.screen.add {
      type = 'frame',
      name = main_frame_name,
      --caption = 'Shortcuts',
      direction = 'vertical',
      style = 'quick_bar_window_frame'
    }
    main_frame.auto_center = true
    --main_frame.visible = false

    local title_bar = main_frame.add { type = 'flow', name = 'titlebar', direction = 'horizontal', style = 'horizontal_flow' }
    gui_style(title_bar, { vertical_align = 'center' })
    title_bar.drag_target = main_frame

    local title = title_bar.add { type = 'label', caption = 'Shortcuts', style = 'frame_title', ignored_by_interaction = true }
    gui_style(title, { top_padding = 2, font = 'heading-3', font_color = { 165, 165, 165 } })

    local widget = title_bar.add { type = 'empty-widget', style = 'draggable_space', ignored_by_interaction = true }
    gui_style(widget, { left_margin = 4, right_margin = 4, height = 20, horizontally_stretchable = true })

    local settings = title_bar.add {
      type = 'sprite-button',
      name = main_frame_name .. '_settings',
      style = 'shortcut_bar_expand_button',
      sprite = 'utility/expand_dots_white',
      hovered_sprite = 'utility/expand_dots',
      clicked_sprite = 'utility/expand_dots',
      tooltip = '[font=default-small-bold]Shortcuts settings[/font] - Customize your shortcuts bar',
      mouse_button_filter = { 'left' },
      auto_toggle = true,
    }
    gui_style(settings, { width = 8, height = 16 })

    local settings_scroll_pane = main_frame
      .add { type = 'frame', name = 'qbip', style = 'quick_bar_inner_panel' }
      .add { type = 'scroll-pane', name = 'qbsp', style = 'shortcut_bar_selection_scroll_pane' }
    gui_style(settings_scroll_pane, { minimal_width = 40 * (#shortcut_buttons) })

    for _, s in pairs(shortcut_buttons) do
      add_shortcut_selection_row(player, settings_scroll_pane, s)
    end
    add_shortcut_selection_row(player, settings_scroll_pane, { caption = 'Rocket silo health', sprite = 'utility/short_indication_line_green', tooltip = '[font=default-bold]Rocket Silo health[/font] - Show your team rocket silo health status', name = 'silo_health' })
    settings_scroll_pane.visible = false

    local table_frame = main_frame.add { type = 'frame', name = 'table_frame', direction = 'horizontal', style = 'quick_bar_inner_panel' } --slot_button_deep_frame, quick_bar_window_frame
    gui_style(table_frame, { horizontally_stretchable = true, margin = 0 })

    local table = table_frame.add { type = 'table', name = 'table', column_count = #shortcut_buttons, style = 'filter_slot_table' }
    gui_style(table, { horizontally_stretchable = true })

    local button
    for _, s in pairs(shortcut_buttons) do
      button = table.add { type = 'sprite-button', style = 'quick_bar_slot_button', sprite = s.sprite, hovered_sprite = s.hovered_sprite, name = s.name, tooltip = s.tooltip }
      gui_style(button, { font_color = { 165, 165, 165 } })
      button.visible = get_player_preferences(player)[s.name]
    end

    -- Silo progress bar
    local progress_bar = main_frame.add { type = 'progressbar', name = 'silo_health', tooltip = '[font=default-bold]Rocket Silo health[/font]', value = 1 }
    gui_style(progress_bar, { horizontally_stretchable = true })
    progress_bar.style.natural_width = nil
    progress_bar.visible = get_player_preferences(player)['silo_health']
  end
  return main_frame
end

Event.add(defines.events.on_gui_click, function(event)
  local ele = event.element
  if not (ele and ele.valid) then
    return
  end
	local player = game.get_player(event.player_index)
  local action = main_frame_actions[ele.name]
  if action then action(player, event) end

  if ele.tags.action == main_frame_name .. '_checkbox' then
    local name = ele.tags.name
    local status = ele.status
    local frame = Public.get_main_frame(player)
    local button
    if name == 'silo_health' then
      button = frame.silo_health
    else
      button = frame.table_frame.table[name]
    end
    if button then
      button.visible = not button.visible
      local player_preferences = get_player_preferences(player)
      player_preferences[name] = button.visible
    end
  end
end)

function Public.refresh()
  for _, force in pairs(game.forces) do
    local rocket_silo = global.rocket_silo[force.name]
    if rocket_silo and rocket_silo.valid then
      local health = rocket_silo.get_health_ratio()
      local HP = math_floor(rocket_silo.health)
      local HP_percent = math_floor(1000 * health) * 0.1
      for _, player in pairs(force.connected_players) do
        local frame = Public.get_main_frame(player)
        frame.silo_health.value = health
        frame.silo_health.style.color = { r = 1 - health, g = health, b = 0 }
        frame.silo_health.tooltip = '[font=default-bold]Rocket Silo health[/font] - ' .. HP .. '/5000  (' .. HP_percent .. '%)'
      end
    end
  end
end

return Public