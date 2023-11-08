-- Biter Battles v2 -- by MewMew

local Ai = require "maps.biter_battles_v2.ai"
local AiStrikes = require "maps.biter_battles_v2.ai_strikes"
local AiTargets = require "maps.biter_battles_v2.ai_targets"
local Functions = require "maps.biter_battles_v2.functions"
local Game_over = require "maps.biter_battles_v2.game_over"
local Gui = require "maps.biter_battles_v2.gui"
local Init = require "maps.biter_battles_v2.init"
local Mirror_terrain = require "maps.biter_battles_v2.mirror_terrain"
require 'modules.simple_tags'
local Team_manager = require "maps.biter_battles_v2.team_manager"
local Terrain = require "maps.biter_battles_v2.terrain"
local Session = require 'utils.datastore.session_data'
local Color = require 'utils.color_presets'
local autoTagWestOutpost = "[West]"
local autoTagEastOutpost = "[East]"
local autoTagDistance = 600
local antiAfkTimeBeforeEnabled = 60 * 60 * 5 -- in tick : 5 minutes
local antiAfkTimeBeforeWarning = 60 * 60 * 3 + 60*40 -- in tick : 3 minutes 40s
require "maps.biter_battles_v2.sciencelogs_tab"
require "maps.biter_battles_v2.changelog_tab"
require 'maps.biter_battles_v2.commands'
require "modules.spawners_contain_biters"

local function on_player_joined_game(event)
	local surface = game.surfaces[global.bb_surface_name]
	local player = game.players[event.player_index]
	if player.online_time == 0 or player.force.name == "player" then
		Functions.init_player(player)
	end
	Gui.clear_copy_history(player)
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
	
	local name = event.research.name
	local force = event.research.force
	if name == 'uranium-processing' then
		force.technologies["uranium-ammo"].researched = true
		force.technologies["kovarex-enrichment-process"].researched = true
	elseif name == 'stone-wall' then
		force.technologies["gate"].researched = true
	elseif name == 'rocket-silo' then
		force.technologies['space-science-pack'].researched = true
	end
end

local function on_console_chat(event)
	Functions.share_chat(event)
end

local function on_built_entity(event)
	Functions.no_landfill_by_untrusted_user(event)
	Functions.no_turret_creep(event)
	Terrain.deny_enemy_side_ghosts(event)
	AiTargets.start_tracking(event.created_entity)
end

local function on_robot_built_entity(event)
	Functions.no_turret_creep(event)
	Terrain.deny_construction_bots(event)
	AiTargets.start_tracking(event.created_entity)
end

local function on_robot_built_tile(event)
	Terrain.deny_bot_landfill(event)
end

local function on_entity_died(event)
	local entity = event.entity
	if not entity.valid then return end
	if Ai.subtract_threat(entity) then Gui.refresh_threat() end
	AiTargets.stop_tracking(entity)
	if Functions.biters_landfill(entity) then return end
	Game_over.silo_death(event)
end

local function on_ai_command_completed(event)
	if not event.was_distracted then AiStrikes.step(event.unit_number, event.result) end
end

local function getTagOutpostName(pos)
	if pos < 0 then
		return autoTagWestOutpost
	else
		return autoTagEastOutpost
	end
end

local function hasOutpostTag(tagName)
	return (string.find(tagName, '%'..autoTagWestOutpost) or string.find(tagName, '%'..autoTagEastOutpost))
end

local function autotagging_outposters()
    for _, p in pairs(game.connected_players) do
		if (p.force.name == "north" or p.force.name == "south") then
			if math.abs(p.position.x) < autoTagDistance then
				if hasOutpostTag(p.tag) then
					p.tag = p.tag:gsub("%"..autoTagWestOutpost, "")
					p.tag = p.tag:gsub("%"..autoTagEastOutpost, "")
				end
			else
				if not hasOutpostTag(p.tag) then
					p.tag = p.tag .. getTagOutpostName(p.position.x)
				end
			end
		end
		
		if p.force.name == "spectator" and hasOutpostTag(p.tag) then
				p.tag = p.tag:gsub("%"..autoTagWestOutpost, "")
				p.tag = p.tag:gsub("%"..autoTagEastOutpost, "")
		end
	end
end

local function afk_kick(player)
	if player.afk_time > antiAfkTimeBeforeWarning and player.afk_time < antiAfkTimeBeforeEnabled then
		player.print('Please move within the next minute or you will be sent back to spectator island ! But even if you keep staying afk and sent back to spectator island, you will be able to join back to your position with your equipment')
	end
	if player.afk_time > antiAfkTimeBeforeEnabled then
		player.print('You were sent back to spectator island as you were afk for too long, you can still join to come back at your position with all your equipment')
		spectate(player,false,true)
	end
end

local function anti_afk_system()
    for _, player in pairs(game.forces.north.connected_players) do
		afk_kick(player)
	end
    for _, player in pairs(game.forces.south.connected_players) do
		afk_kick(player)
	end
end

local tick_minute_functions = {
	[300 * 1] = Ai.raise_evo,
	[300 * 3 + 30 * 0] = Ai.pre_main_attack,		-- setup for main_attack
	[300 * 3 + 30 * 1] = Ai.perform_main_attack,	-- call perform_main_attack 7 times on different ticks
	[300 * 3 + 30 * 2] = Ai.perform_main_attack,	-- some of these might do nothing (if there are no wave left)
	[300 * 3 + 30 * 3] = Ai.perform_main_attack,
	[300 * 3 + 30 * 4] = Ai.perform_main_attack,
	[300 * 3 + 30 * 5] = Ai.perform_main_attack,
	[300 * 3 + 30 * 6] = Ai.perform_main_attack,
	[300 * 3 + 30 * 7] = Ai.perform_main_attack,
	[300 * 3 + 30 * 8] = Ai.post_main_attack,
	[300 * 3 + 30 * 9] = autotagging_outposters,
	[300 * 4] = Ai.send_near_biters_to_silo,
	[300 * 4 + 30 * 1] = anti_afk_system,
}

local function on_tick()
	local tick = game.tick

	if tick % 60 == 0 then 
		global.bb_threat["north_biters"] = global.bb_threat["north_biters"] + global.bb_threat_income["north_biters"]
		global.bb_threat["south_biters"] = global.bb_threat["south_biters"] + global.bb_threat_income["south_biters"]
	end

	if (tick+11) % 300 == 0 then
		Gui.spy_fish()

		if global.bb_game_won_by_team then
			Game_over.reveal_map()
			Game_over.server_restart()
			return
		end
	end

	if tick % 30 == 0 then	
		local key = tick % 3600
		if tick_minute_functions[key] then
			tick_minute_functions[key]()
			return
		end
	end

	if (tick+5) % 180 == 0 then
		Gui.refresh()
		return
	end

	Ai.reanimate_units()
end

local function on_marked_for_deconstruction(event)
	if not event.entity.valid then return end
	if not event.player_index then return end
	local force_name = game.get_player(event.player_index).force.name
	if event.entity.name == "fish" then event.entity.cancel_deconstruction(force_name) return end
	if (force_name == "north" and event.entity.position.y > 0) or (force_name == "south" and event.entity.position.y < 0) then
		event.entity.cancel_deconstruction(force_name)
	end
end

local function on_player_built_tile(event)
	local player = game.players[event.player_index]
	if event.item ~= nil and event.item.name == "landfill" then
		Terrain.restrict_landfill(player.surface, player, event.tiles)
	end
end

local function on_player_mined_entity(event)
	Terrain.minable_wrecks(event)
	AiTargets.stop_tracking(event.entity)
end

local function on_robot_mined_entity(event)
	AiTargets.stop_tracking(event.entity)
end

local function on_chunk_generated(event)
	local surface = event.surface

	-- Check if we're out of init.
	if not surface or not surface.valid then return end

	-- Necessary check to ignore nauvis surface.
	if surface.name ~= global.bb_surface_name then return end

	-- Generate structures for north only.
	local pos = event.area.left_top
	if pos.y < 0 then
		Terrain.generate(event)
	end

	-- Request chunk for opposite side, maintain the lockstep.
	-- NOTE: There is still a window where user can place down a structure
	-- and it will be mirrored. However this window is so tiny - user would
	-- need to fly in god mode and spam entities in partially generated
	-- chunks.
	local req_pos = { pos.x + 16, -pos.y + 16 }
	surface.request_to_generate_chunks(req_pos, 0)

	-- Clone from north and south. NOTE: This WILL fire 2 times
	-- for each chunk due to asynchronus nature of this event.
	-- Both sides contain arbitary amount of chunks, some positions
	-- when inverted will be still in process of generation or not
	-- generated at all. It is important to perform 2 passes to make
	-- sure everything is cloned properly. Normally we would use mutex
	-- but this is not reliable in this environment.
	Mirror_terrain.clone(event)

	-- The game pregenerate tiles within a radius of 3 chunks from the generated chunk.
	-- Bites can use these tiles for pathing.
	-- This creates a problem that bites pathfinder can cross the river at the edge of the map.
	-- To prevent this, divide the north and south land by drawing a strip of water on these pregenerated tiles.
	if event.position.y >= 0 and event.position.y <= 3 then
		for x = -3, 3 do
			local chunk_pos = { x = event.position.x + x, y = 0 }
			if not surface.is_chunk_generated(chunk_pos) then
				Terrain.draw_water_for_river_ends(surface, chunk_pos)
			end
		end
	end

	-- add decorations only after the south part of the island is generated
	if event.position.y == 0 and event.position.x == 1 and global.bb_settings['new_year_island'] then
		Terrain.add_new_year_island_decorations(surface)
	end
end

local function on_entity_cloned(event)
	local source = event.source
	local destination = event.destination

	-- In case entity dies between clone and this event we
	-- have to ensure south doesn't get additional objects.
	if not source.valid then
		if destination.valid then
			destination.destroy()
		end

		return
	end

	Mirror_terrain.invert_entity(event)
end

local function on_area_cloned(event)
	local surface = event.destination_surface

	-- Check if we're out of init and not between surface hot-swap.
	if not surface or not surface.valid then return end

	-- Event is fired only for south side.
	Mirror_terrain.invert_tiles(event)
	Mirror_terrain.invert_decoratives(event)

	-- Check chunks around southen silo to remove water tiles under refined-concrete.
	-- Silo can be removed by picking bricks from under it in a situation where
	-- refined-concrete tiles were placed directly onto water tiles. This scenario does
	-- not appear for north as water is removed during silo generation.
	local position = event.destination_area.left_top
	if position.y >= 0 and position.y <= 192 and math.abs(position.x) <= 192 then
		Mirror_terrain.remove_hidden_tiles(event)
	end
end

local function on_rocket_launch_ordered(event)
	local vehicles = {
		["car"] = true,
		["tank"] = true,
		["locomotive"] = true,
		["cargo-wagon"] = true,
		["fluid-wagon"] = true,
		["spidertron"] = true,
	}
	local inventory = event.rocket.get_inventory(defines.inventory.fuel)
	local contents = inventory.get_contents()
	for name, _ in pairs(contents) do
		if vehicles[name] then
			inventory.clear()
		end
	end
end

local function clear_corpses(cmd)
	local player = game.player
        local trusted = Session.get_trusted_table()
        local param = tonumber(cmd.parameter)

        if not player or not player.valid then
            return
        end
        if param == nil then
            player.print('[ERROR] Must specify radius!', Color.fail)
            return
        end
        if not trusted[player.name] and not player.admin and param > 100 then
				player.print('[ERROR] Value is too big. Max radius is 100', Color.fail)
				return
        end
        if param < 0 then
            player.print('[ERROR] Value is too low.', Color.fail)
            return
        end
        if param > 500 then
            player.print('[ERROR] Value is too big.', Color.fail)
            return
        end

	if not Ai.empty_reanim_scheduler() then
		player.print("[ERROR] Some corpses are waiting to be reanimated...")
		player.print(" => Try again in short moment")
		return
	end

        local pos = player.position

        local radius = {{x = (pos.x + -param), y = (pos.y + -param)}, {x = (pos.x + param), y = (pos.y + param)}}
        for _, entity in pairs(player.surface.find_entities_filtered {area = radius, type = 'corpse'}) do
            if entity.corpse_expires then
                entity.destroy()
            end
        end
        player.print('Cleared biter-corpses.', Color.success)
end

local function on_init()
	Init.tables()
	Init.initial_setup()
	Init.playground_surface()
	Init.forces()
	Init.draw_structures()
	Init.load_spawn()
	Init.reveal_map()
end


local Event = require 'utils.event'
Event.add(defines.events.on_rocket_launch_ordered, on_rocket_launch_ordered)
Event.add(defines.events.on_area_cloned, on_area_cloned)
Event.add(defines.events.on_post_entity_died, Ai.schedule_reanimate)
Event.add_event_filter(defines.events.on_post_entity_died, {
	filter = "type",
	type = "unit",
})
Event.add(defines.events.on_entity_cloned, on_entity_cloned)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_chunk_generated, on_chunk_generated)
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_ai_command_completed, on_ai_command_completed)
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

commands.add_command('clear-corpses', 'Clears all the biter corpses..',
		     clear_corpses)

require "maps.biter_battles_v2.spec_spy"
