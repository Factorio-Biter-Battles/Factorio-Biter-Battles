require 'utils.data_stages'
_LIFECYCLE = _STAGE.control -- Control stage

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


local loaded = _G.package.loaded
function require(path)
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end

---------------- Central Dispatch of Events ----------------
local Event = require "utils.event"

-- Try to keep events and requires alphabetized

local AiTargets = require "maps.biter_battles_v2.ai_targets"
local Antigrief = require "antigrief"
local ComfyPanelConfig = require "comfy_panel.config"
local ComfyPanelPlayerList = require "comfy_panel.player_list"
local ComfyPanelScore = require "comfy_panel.score"
local Functions = require "maps.biter_battles_v2.functions"
local FunctionsBossUnit = require "functions.boss_unit"
local MapsBiterBattlesV2Main = require 'maps.biter_battles_v2.main'
local MapsBiterBattlesV2DifficultyVote = require 'maps.biter_battles_v2.difficulty_vote'
local ModulesCorpseMarkers = require 'modules.corpse_markers'
local Terrain = require "maps.biter_battles_v2.terrain"
local UtilsFreeplay = require 'utils.freeplay'
local UtilsServer = require 'utils.server'
local UtilsTask = require 'utils.task'

Event.add(
	defines.events.on_entity_damaged,
	---@param event EventData.on_entity_damaged
	function (event)
		FunctionsBossUnit.on_entity_damaged(event)
	end
)

Event.add_event_filter(
	defines.events.on_entity_damaged,
	{filter = "type", type = "unit"}
)

Event.add(
	defines.events.on_force_created,
	---@param event EventData.on_force_created
	function (event)
		ComfyPanelConfig.spaghett()
	end
)

Event.add(defines.events.on_player_created, function (event)
	local player = game.players[event.player_index]
	player.gui.top.style = "slot_table_spacing_horizontal_flow"
	player.gui.left.style = "slot_table_spacing_vertical_flow"
end)

Event.add(
	defines.events.on_player_died,
	---@param event EventData.on_player_died
	function(event)
		local player = game.players[event.player_index]
		if player.valid then
			ComfyPanelScore.on_player_died(player)
			UtilsServer.on_player_died(player, event.cause)
			-- Reading will always give a LuaForce
			-- https://lua-api.factorio.com/latest/classes/LuaControl.html#force
			ModulesCorpseMarkers.draw_map_tag(player.surface, player.force, player.position)
		end
	end
)

Event.add(
	defines.events.on_player_left_game,
	---@param event EventData.on_player_left_game
	function (event)
		ComfyPanelPlayerList.refresh()
		local player = game.get_player(event.player_index)
		if player and player.valid then
			UtilsServer.on_player_left_game(player)
			MapsBiterBattlesV2DifficultyVote.on_player_left_game(player)
		end
	end
)

Event.add(defines.events.on_player_mined_entity, function (event)
	Functions.maybe_set_game_start_tick(event)
	local entity = event.entity
	if not entity.valid then
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

Event.add(defines.events.on_player_mined_item, function (event)
	Functions.maybe_set_game_start_tick(event)
end)

Event.add(defines.events.on_player_respawned,
	---@param event EventData.on_player_respawned
	function (event)
		UtilsFreeplay.on_player_respawned(event)
	end
)

Event.add(defines.events.on_pre_player_crafted_item, function (event)
	Functions.maybe_set_game_start_tick(event)
end)

Event.add(
	defines.events.on_robot_built_entity,
	---@param event EventData.on_robot_built_entity
	function (event)
		local created_entity = event.created_entity
		if created_entity.valid then
			local robot = event.robot
			ComfyPanelConfig.spaghett_deny_building(created_entity, nil, robot)
			Functions.no_turret_creep(created_entity, robot.surface, nil, robot)
			Terrain.deny_construction_bots(created_entity, robot)
			AiTargets.start_tracking(created_entity)
		end
	end
)

Event.add(defines.events.on_tick,
	---@param event EventData.on_tick
	function (event)
		local tick = event.tick
		UtilsTask.on_tick(tick)
		MapsBiterBattlesV2Main.on_tick(tick)
	end
)
