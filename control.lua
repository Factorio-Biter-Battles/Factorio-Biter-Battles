require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage
_DEBUG = false

require 'utils.server'
require 'utils.server_commands'
require 'utils.utils'
require 'utils.table'
require 'utils.freeplay'
--require 'utils.datastore.server_ups'
require 'utils.datastore.color_data'
require 'utils.datastore.session_data'
require 'utils.datastore.jail_data'
require 'utils.datastore.quickbar_data'
require 'utils.datastore.message_on_join_data'
require 'utils.datastore.player_tag_data'
require 'utils.muted'
require 'chatbot'
require 'commands'
require 'antigrief'
require 'modules.corpse_markers'
require 'modules.floaty_chat'
require 'modules.show_inventory'

require 'comfy_panel.main'
require 'comfy_panel.player_list'
require 'comfy_panel.admin'
require 'comfy_panel.histories'
require 'comfy_panel.group'
require 'comfy_panel.poll'
require 'comfy_panel.score'
require 'comfy_panel.config'
require 'comfy_panel.special_games'

---------------- ENABLE MAPS HERE ----------------
--![[North VS South Survival PVP, feed the opposing team's biters with science flasks. Disable Autostash, Group and Poll modules.]]--
require 'maps.biter_battles_v2.main'

---------------------------------------------------------------

--- Follow Krastorio 2 format
-- See: https://github.com/raiguard/Krastorio2/blob/master/control.lua
-- They use local's in control to aggregate and define script.on_events

local Antigrief = require("antigrief")
local ComfyPanelScore = require("comfy_panel.score")
local Functions = require("maps.biter_battles_v2.functions")
local Terrain = require("maps.biter_battles_v2.terrain")
local AiTargets = require("maps.biter_battles_v2.ai_targets")
local BossUnit = require("functions.boss_unit")
local CorpseMarkers = require("modules/corpse_markers.lua")

-- ENTITY

script.on_event(defines.events.on_player_mined_entity, function(event)
	local entity = event.entity
	if not entity or not entity.valid then
		return
	end
	AiTargets.stop_tracking(entity)

	local player = game.get_player(event.player_index)
	if player and player.valid then
		if Antigrief.enabled then
			Antigrief.on_player_mined_entity(entity, player)
		end
		ComfyPanelScore.on_player_mined_entity(entity, player)

		Terrain.minable_wrecks(entity, player)
	end
end)

-- Maybe combine with defines.events.on_player_mined_entity ?
script.on_event(defines.events.on_robot_mined_entity, function(event)
	local entity = event.entity
	if not entity or not entity.valid then
		return
	end
	AiTargets.stop_tracking(entity)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
	local created_entity = event.created_entity
	if created_entity and created_entity.valid then
		Functions.no_turret_creep(event)
		Terrain.deny_construction_bots(event)
		AiTargets.start_tracking(event.created_entity)
	end
end)

script.on_event(defines.events.on_robot_built_tile, function(event)
	Terrain.deny_bot_landfill(event)
end)

script.on_event(defines.events.on_entity_damaged, function(event)
	BossUnit.handle_boss_damage(event)
end)
script.set_event_filter(defines.events.on_entity_damaged, {
	{
		filter = "type",
		type = "unit",
	},
})

-- PLAYER DEATH

script.on_event(defines.events.on_character_corpse_expired, function(event)
	CorpseMarkers.on_character_corpse_expired(event)
end)

script.on_event(defines.events.on_pre_player_mined_item, function(event)
	CorpseMarkers.on_pre_player_mined_item(event)
end)


---- END Event refactor.  Must have this at end until all Event is gone.

local function on_player_created(event)
    local player = game.players[event.player_index]
    player.gui.top.style = 'slot_table_spacing_horizontal_flow'
    player.gui.left.style = 'slot_table_spacing_vertical_flow'
end

local loaded = _G.package.loaded
function require(path)
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end

local Event = require 'utils.event'
Event.add(defines.events.on_player_created, on_player_created)

