-- Biter Battles v2 -- by MewMew

local Ai = require "maps.biter_battles_v2.ai"
local Functions = require "maps.biter_battles_v2.functions"
local Game_over = require "maps.biter_battles_v2.game_over"
local Gui = require "maps.biter_battles_v2.gui"
local Init = require "maps.biter_battles_v2.init"
local Mirror_terrain = require "maps.biter_battles_v2.mirror_terrain"
require 'modules.simple_tags'
local Team_manager = require "maps.biter_battles_v2.team_manager"
local Terrain = require "maps.biter_battles_v2.terrain"

require "maps.biter_battles_v2.sciencelogs_tab"
require 'maps.biter_battles_v2.commands'
require "modules.spawners_contain_biters"

local function on_player_joined_game(event)
	local surface = game.surfaces["biter_battles"]
	local player = game.players[event.player_index]
	if player.online_time == 0 or player.force.name == "player" then
		Functions.init_player(player)
	end
	Functions.create_map_intro_button(player)
	Team_manager.draw_top_toggle_button(player)
end

local function on_gui_click(event)
	local player = game.players[event.player_index]
	local element = event.element
	if not element then return end
	if not element.valid then return end

	if Functions.map_intro_click(player, element) then return end
	Team_manager.gui_click(event)
end

local function on_research_finished(event)
	Functions.combat_balance(event)
end

local function on_console_chat(event)
	Functions.share_chat(event)
end
local entity_limits = {
        ['north'] = {placed = 0, limit = 3000, str = 'land-mine'},
        ['south'] = {placed = 0, limit = 3000, str = 'land-mine'},
    }
local function on_built_entity(event)
	Functions.no_turret_creep(event)
	Functions.add_target_entity(event.created_entity)
	
	local entity=event.created_entity
	if(entity.name=='land-mine')then
	if entity_limits[entity.force.name].placed < entity_limits[entity.force.name].limit then
			entity_limits[entity.force.name].placed = entity_limits[entity.force.name].placed + 1
				if(entity_limits[entity.force.name].placed%10==0)then
					entity.surface.create_entity(
					{
						name = 'flying-text',
						position = entity.position,
						text = entity_limits[entity.force.name].placed ..
							' / ' .. entity_limits[entity.force.name].limit .. ' ' .. entity_limits[entity.force.name].str .. 's',
						color = {r = 0.98, g = 0.66, b = 0.22}
					}
            )
			end
        else
            entity.surface.create_entity(
                {
                    name = 'flying-text',
                    position = entity.position,
                    text = entity_limits[entity.force.name].str .. ' limit reached.',
                    color = {r = 0.82, g = 0.11, b = 0.11}
                }
            )
			local player = game.players[event.player_index]
            player.insert({name = entity.name, count = 1})
            if get_score then
                if get_score[player.force.name] then
                    if get_score[player.force.name].players[player.name] then
                        get_score[player.force.name].players[player.name].built_entities =
                            get_score[player.force.name].players[player.name].built_entities - 1
                    end
                end
            end
            entity.destroy()
		end
	end
end

local function on_robot_built_entity(event)
	Functions.no_turret_creep(event)
	Terrain.deny_construction_bots(event)
	Functions.add_target_entity(event.created_entity)
	
	local entity=event.created_entity
	if(entity.name=='land-mine')then
	if entity_limits[entity.force.name].placed < entity_limits[entity.force.name].limit then
			entity_limits[entity.force.name].placed = entity_limits[entity.force.name].placed + 1
				if(entity_limits[entity.force.name].placed%10==0)then
					entity.surface.create_entity(
					{
						name = 'flying-text',
						position = entity.position,
						text = entity_limits[entity.force.name].placed ..
							' / ' .. entity_limits[entity.force.name].limit .. ' ' .. entity_limits[entity.force.name].str .. 's',
						color = {r = 0.98, g = 0.66, b = 0.22}
					}
            )
			end
        else
            entity.surface.create_entity(
                {
                    name = 'flying-text',
                    position = entity.position,
                    text = entity_limits[entity.force.name].str .. ' limit reached.',
                    color = {r = 0.82, g = 0.11, b = 0.11}
                }
            )
			local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
            inventory.insert({name = entity.name, count = 1})
            entity.destroy()
		end
	end

end

local function on_robot_built_tile(event)
	Terrain.deny_bot_landfill(event)
end

local function on_entity_died(event)
	local entity = event.entity
	if not entity.valid then return end
	if Ai.subtract_threat(entity) then Gui.refresh_threat() end
	if Functions.biters_landfill(entity) then return end
	Game_over.silo_death(event)
	if(entity.name=='land-mine')then
        entity_limits[event.entity.force.name].placed = entity_limits[event.entity.force.name].placed - 1
	end
end

local tick_minute_functions = {
	[300 * 1] = Ai.raise_evo,
	[300 * 2] = Ai.destroy_inactive_biters,
	[300 * 3 + 30 * 0] = Ai.pre_main_attack,		-- setup for main_attack
	[300 * 3 + 30 * 1] = Ai.perform_main_attack,	-- call perform_main_attack 7 times on different ticks
	[300 * 3 + 30 * 2] = Ai.perform_main_attack,	-- some of these might do nothing (if there are no wave left)
	[300 * 3 + 30 * 3] = Ai.perform_main_attack,
	[300 * 3 + 30 * 4] = Ai.perform_main_attack,
	[300 * 3 + 30 * 5] = Ai.perform_main_attack,
	[300 * 3 + 30 * 6] = Ai.perform_main_attack,
	[300 * 3 + 30 * 7] = Ai.perform_main_attack,
	[300 * 3 + 30 * 8] = Ai.post_main_attack,
	[300 * 4] = Ai.send_near_biters_to_silo,
	[300 * 5] = Ai.wake_up_sleepy_groups,
}

local function on_tick()
	Mirror_terrain.ticking_work()

	local tick = game.tick

	if tick % 60 == 0 then 
		global.bb_threat["north_biters"] = global.bb_threat["north_biters"] + global.bb_threat_income["north_biters"]
		global.bb_threat["south_biters"] = global.bb_threat["south_biters"] + global.bb_threat_income["south_biters"]
	end

	if tick % 180 == 0 then Gui.refresh() end

	if tick % 300 == 0 then
		Gui.spy_fish()

		if global.bb_game_won_by_team then
			Game_over.reveal_map()
			Game_over.server_restart()
			return
		end
	end

	if tick % 30 == 0 then	
		local key = tick % 3600
		if tick_minute_functions[key] then tick_minute_functions[key]() end
	end
end

local function on_marked_for_deconstruction(event)
	if not event.entity.valid then return end
	if event.entity.name == "fish" then event.entity.cancel_deconstruction(game.players[event.player_index].force.name) end
end

local function on_player_built_tile(event)
	local player = game.players[event.player_index]
	Terrain.restrict_landfill(player.surface, player, event.tiles)
end

local function on_player_built_tile(event)
	local player = game.players[event.player_index]
	Terrain.restrict_landfill(player.surface, player, event.tiles)
end

local function on_player_mined_entity(event)
	Terrain.minable_wrecks(event)
	if(event.entity.name=='land-mine')then
        entity_limits[event.entity.force.name].placed = entity_limits[event.entity.force.name].placed - 1
	end
end
local function on_robot_mined_entity(event)
	if(event.entity.name=='land-mine')then
        entity_limits[event.entity.force.name].placed = entity_limits[event.entity.force.name].placed - 1
	end
end
local function on_chunk_generated(event)
	Terrain.generate(event)
	Mirror_terrain.add_chunk(event)
end

local function on_init()
	Init.tables()
	Init.initial_setup()
	Init.forces()	
	Init.source_surface()
	Init.load_spawn()
end

local Event = require 'utils.event'
Event.add(defines.events.on_research_finished, Ai.unlock_satellite)			--free silo space tech
Event.add(defines.events.on_entity_died, Ai.on_entity_died)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_chunk_generated, on_chunk_generated)
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_marked_for_deconstruction, on_marked_for_deconstruction)
Event.add(defines.events.on_player_built_tile, on_player_built_tile)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_mined_entity, on_player_mined_entity)
Event.add(defines.events.on_robot_mined_entity, on_robot_mined_entity)
Event.add(defines.events.on_research_finished, on_research_finished)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_robot_built_tile, on_robot_built_tile)
Event.add(defines.events.on_tick, on_tick)
Event.on_init(on_init)

require "maps.biter_battles_v2.spec_spy"
require "maps.biter_battles_v2.difficulty_vote"
