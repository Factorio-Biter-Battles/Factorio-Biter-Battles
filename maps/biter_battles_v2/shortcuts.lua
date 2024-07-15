local Gui = require 'utils.gui'
local gui_style = require "utils.utils".gui_style
local Tables = require 'maps.biter_battles_v2.tables'
local Functions = require "maps.biter_battles_v2.functions"
local ResearchInfo = require 'maps.biter_battles_v2.research_info'

local Public = {}

Public.main_frame_name = 'bb_floating_shortcuts'
local main_frame_name = Public.main_frame_name

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

    local table = main_frame.add { type = 'table', column_count = 4 }

    local button

    -- Send fish
    button = table.add { type = 'sprite-button', sprite = 'item/raw-fish', name = main_frame_name .. 'send_fish', tooltip = Tables.gui_foods['raw-fish'] }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Send science packs
    button = table.add { type = 'sprite-button', sprite = 'item/automation-science-pack', name = main_frame_name .. 'send_science', tooltip = '___' }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Research info
    button = table.add { type = 'sprite-button', sprite = 'item/lab', name = main_frame_name .. 'research_info', tooltip = '___' }
    gui_style(button, { font_color = { 165, 165, 165 } })

    -- Clear corpses
    button = table.add { type = 'sprite-button', sprite = 'entity/behemoth-biter', name = main_frame_name .. 'clear_corpses', tooltip = '___' }
    gui_style(button, { font_color = { 165, 165, 165 } })

    local progress_bar = main_frame.add {
      type = 'progressbar',
      name = 'silo_health',
      tooltip = [[Rocket silo's health]],
      value = 1,
    }
    gui_style(progress_bar, { maximal_width = 170 })
  end
  return main_frame
end

Gui.on_click(main_frame_name .. 'send_fish', function(event)
  if not event.element then return end
	if not event.element.valid then return end
	local player = game.get_player(event.player_index)
  Functions.spy_fish(player, event)
end)

Gui.on_click(main_frame_name .. 'research_info', function(event)
  if not event.element then return end
	if not event.element.valid then return end
	ResearchInfo.show_research_info_handler(event)
end)

function Public.update_main_frame(player)
  local main_frame = Public.get_main_frame(player)
  local rocket_silo = global.rocket_silo[player.force.name]
  if rocket_silo and rocket_silo.valid then
    main_frame.silo_health.value = rocket_silo.health
  end
end

function Public.refresh()
  for _, force in pairs(game.forces) do
    local rocket_silo = global.rocket_silo[force.name]
    if rocket_silo and rocket_silo.valid then
      local health = rocket_silo.health
      for _, player in pairs(force.connected_players) do
        local frame = Public.get_main_frame(player)
        frame.silo_health.value = health
        frame.silo_health.style.color = { r = 1 - health, g = health, b = 0, a = 1 }
      end
    end
  end
end

return Public