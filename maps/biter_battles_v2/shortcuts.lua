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

Public.main_frame_name = 'bb_floating_shortcuts'
local main_frame_name = Public.main_frame_name

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

function Public.get_main_frame(player)
  local main_frame = player.gui.screen[main_frame_name]
  if not main_frame or not main_frame.valid then
    main_frame = player.gui.screen.add {
      type = 'frame',
      name = main_frame_name,
      caption = 'Shortcuts',
      direction = 'vertical',
    }
    main_frame.auto_center = true
    --main_frame.visible = false

    local table = main_frame.add { type = 'table', column_count = 5 }

    local button

    -- Send fish
    button = table.add { type = 'sprite-button', sprite = 'item/raw-fish', name = main_frame_name .. '_send_fish', tooltip = '[font=default-bold]Send fish[/font] - ' .. Tables.gui_foods['raw-fish'] }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Send science packs
    button = table.add { type = 'sprite-button', sprite = 'item/automation-science-pack', name = main_frame_name .. '_send_science', tooltip = '[font=default-bold]Send science[/font] - Send all science packs in your inventory' }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Research info
    button = table.add { type = 'sprite-button', sprite = 'item/lab', name = main_frame_name .. '_research_info', tooltip = '[font=default-bold]Research info[/font] - Toggle the research info UI' }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Team stats
    button = table.add { type = 'sprite-button', sprite = 'utility/side_menu_production_icon', hovered_sprite = 'utility/side_menu_production_hover_icon', name = main_frame_name .. '_teamstats', tooltip = '[font=default-bold]Team Statistics[/font] - Toggle the team statistics UI' }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Clear corpses
    button = table.add { type = 'sprite-button', sprite = 'entity/behemoth-biter', name = main_frame_name .. '_clear_corpses', tooltip = '[font=default-bold]Clear Corpses[/font] - Clear biter corpses around you' }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Silo progress bar
    local progress_bar = main_frame.add { type = 'progressbar', name = 'silo_health', tooltip = '[font=default-bold]Rocket Silo health[/font]', value = 1 }
    gui_style(progress_bar, { width = 214, maximal_width = 224 })
  end
  return main_frame
end

local main_frame_actions = {
  [main_frame_name..'_send_fish'] = function(player, event) Functions.spy_fish(player, event) end,
  [main_frame_name..'_send_science'] = function(player, event) Feeding.feed_biters_mixed_from_inventory(player, event.button) end,
  [main_frame_name..'_research_info'] = function(player, event) ResearchInfo.show_research_info_handler(event) end,
  [main_frame_name..'_clear_corpses'] = function(player, event) clear_corpses(player) end,
  [main_frame_name..'_teamstats'] = function(player, event) show_teamstats(player) end,
}

Event.add(defines.events.on_gui_click, function(event)
  if not (event.element and event.element.valid) then
    return
  end
	local player = game.get_player(event.player_index)
  local action = main_frame_actions[event.element.name]
  if action then action(player, event) end
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