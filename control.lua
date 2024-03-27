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
local Chatbot = require "chatbot"
local ComfyPanelConfig = require "comfy_panel.config"
local ComfyPanelHistories = require "comfy_panel.histories"
local ComfyPanelPlayerList = require "comfy_panel.player_list"
local ComfyPanelScore = require "comfy_panel.score"
local Functions = require "maps.biter_battles_v2.functions"
local FunctionsBossUnit = require "functions.boss_unit"
local MapsBiterBattlesV2AiStrikes = require "maps.biter_battles_v2.ai_strikes"
local MapsBiterBattlesV2GameOver = require 'maps.biter_battles_v2.game_over'
local MapsBiterBattlesV2Main = require 'maps.biter_battles_v2.main'
local MapsBiterBattlesV2MirrorTerrain = require "maps.biter_battles_v2.mirror_terrain"
local MapsBiterBattlesV2DifficultyVote = require 'maps.biter_battles_v2.difficulty_vote'
local ModulesCorpseMarkers = require 'modules.corpse_markers'
local ModulesFloatyChat = require 'modules.floaty_chat'
local ModulesSpawnersContainBiters = require 'modules.spawners_contain_biters'
local Terrain = require "maps.biter_battles_v2.terrain"
local UtilsDatastoreColorData = require 'utils.datastore.color_data'
local UtilsDatastoreJailData = require 'utils.datastore.jail_data'
local UtilsDatastoreSessionData = require 'utils.datastore.session_data'
local UtilsFreeplay = require 'utils.freeplay'
local UtilsMuted = require 'utils.muted'
local UtilsServer = require 'utils.server'
local UtilsTask = require 'utils.task'

Event.add(
	defines.events.on_ai_command_completed,
	---@param event EventData.on_ai_command_completed
	function (event)
		if not event.was_distracted then
			MapsBiterBattlesV2AiStrikes.step(event.unit_number, event.result)
		end
	end
)

Event.add(
	defines.events.on_area_cloned,
	---@param event EventData.on_area_cloned
	function (event)
		local surface = event.destination_surface

		-- Check if we're out of init and not between surface hot-swap.
		if not surface or not surface.valid then return end

		-- Event is fired only for south side.
		MapsBiterBattlesV2MirrorTerrain.invert_tiles(event)
		MapsBiterBattlesV2MirrorTerrain.invert_decoratives(event)

		-- Check chunks around southern silo to remove water tiles under refined-concrete.
		-- Silo can be removed by picking bricks from under it in a situation where
		-- refined-concrete tiles were placed directly onto water tiles. This scenario does
		-- not appear for north as water is removed during silo generation.
		local position = event.destination_area.left_top
		if position.y >= 0 and position.y <= 192 and math.abs(position.x) <= 192 then
			MapsBiterBattlesV2MirrorTerrain.remove_hidden_tiles(event)
		end
	end
)

Event.add(
	defines.events.on_built_entity,
	---@param event EventData.on_built_entity
	function (event)
		local created_entity = event.created_entity
		local player = game.players[event.player_index]
		if not player then return end
		if not created_entity.valid then return end
		Antigrief.on_built_entity(created_entity, player)
		if not created_entity.valid then return end
		ComfyPanelScore.on_built_entity(created_entity, player)
		if not created_entity.valid then return end
		ComfyPanelConfig.spaghett_deny_building(created_entity, player, nil)
		if not created_entity.valid then return end
		Functions.maybe_set_game_start_tick(event)
		if not created_entity.valid then return end
		Functions.no_landfill_by_untrusted_user(event, UtilsDatastoreSessionData.get_trusted_table())
		if not created_entity.valid then return end
		Functions.no_turret_creep(created_entity, player.surface, player, nil)
		if not created_entity.valid then return end
		Terrain.deny_enemy_side_ghosts(event)
		if not created_entity.valid then return end
		-- Must be last
		AiTargets.start_tracking(event.created_entity)
	end
)

Event.add(
	defines.events.on_character_corpse_expired,
	---@param event EventData.on_character_corpse_expired
	function (event)
		ModulesCorpseMarkers.on_character_corpse_expired(event)
	end
)

Event.add(
	defines.events.on_chunk_generated,
	---@param event EventData.on_chunk_generated
	function (event)
		MapsBiterBattlesV2Main.on_chunk_generated(event)
	end
)
Event.add(
	defines.events.on_console_chat,
	---@param event EventData.on_console_chat
	function (event)
		local player = game.players[event.player_index]
		local message = event.message
		if message and player and player.valid then
			Chatbot.on_console_chat(player, message)
			ComfyPanelHistories.on_console_chat(player, message)
			MapsBiterBattlesV2GameOver.chat_with_everyone(player, message)
			MapsBiterBattlesV2Main.on_console_chat(player, message)
			ModulesFloatyChat.on_console_chat(player, message)
		end
	end
)

Event.add(
	defines.events.on_console_command,
	---@param event EventData.on_console_command
	function (event)
		Chatbot.on_console_command(event)
		MapsBiterBattlesV2Main.on_console_command(event)
		UtilsDatastoreJailData.on_console_command(event)
		UtilsDatastoreColorData.on_console_command(event)
		UtilsServer.on_console_command(event)
	end
)

Event.add(
	defines.events.on_cutscene_cancelled,
	---@param event EventData.on_cutscene_cancelled
	function (event)
		UtilsFreeplay.on_cutscene_cancelled(event)
	end
)

Event.add(
	defines.events.on_cutscene_waypoint_reached,
	---@param event EventData.on_cutscene_waypoint_reached
	function (event)
		UtilsFreeplay.on_cutscene_waypoint_reached(event)
	end
)

Event.add(
	defines.events.on_entity_cloned,
	---@param event EventData.on_entity_cloned
	function (event)
		MapsBiterBattlesV2Main.on_entity_cloned(event)
	end
)

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
	defines.events.on_entity_died,
	---@param event EventData.on_entity_died
	function (event)
		Antigrief.on_entity_died(event)
		MapsBiterBattlesV2Main.on_entity_died(event)
		ModulesSpawnersContainBiters.on_entity_died(event)
		ComfyPanelScore.on_entity_died(event)
	end
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

Event.add(
	defines.events.on_player_muted,
	---@param event EventData.on_player_muted
	function (event)
		local player = game.get_player(event.player_index)
		if player then
			UtilsMuted.on_player_muted(player)
		end
	end
)

Event.add(defines.events.on_player_respawned,
	---@param event EventData.on_player_respawned
	function (event)
		UtilsFreeplay.on_player_respawned(event)
	end
)

Event.add(
	defines.events.on_player_unmuted,
	---@param event EventData.on_player_unmuted
	function (event)
		local player = game.get_player(event.player_index)
		if player then
			UtilsMuted.on_player_unmuted(player)
		end
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
		end
		if created_entity.valid then
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
