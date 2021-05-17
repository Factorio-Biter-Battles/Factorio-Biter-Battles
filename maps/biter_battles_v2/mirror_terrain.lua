local Public = {}

local Functions = require "maps.biter_battles_v2.functions"
local terrain = require "maps.biter_battles_v2.terrain"
local table_remove = table.remove
local table_insert = table.insert

local direction_translation = {
	[defines.direction.north] = defines.direction.south,
	[defines.direction.northeast] = defines.direction.southeast,
	[defines.direction.east] = defines.direction.east,
	[defines.direction.southeast] = defines.direction.northeast,
	[defines.direction.south] = defines.direction.north,
	[defines.direction.southwest] = defines.direction.northwest,
	[defines.direction.west] = defines.direction.west,
	[defines.direction.northwest] = defines.direction.southwest,
}

local cliff_orientation_translation = {
	["east-to-none"] =  "west-to-none",
	["east-to-north"] =  "west-to-south",
	["east-to-south"] =  "west-to-north",
	["east-to-west"] =  "west-to-east",
	["north-to-east"] =  "south-to-west",
	["north-to-none"] =  "south-to-none",
	["north-to-south"] =  "south-to-north",
	["north-to-west"] =  "south-to-east",
	["south-to-east"] =  "north-to-west",
	["south-to-none"] =  "north-to-none",
	["south-to-north"] =  "north-to-south",
	["south-to-west"] =  "north-to-east",
	["west-to-east"] =  "east-to-west",
	["west-to-none"] =  "east-to-none",
	["west-to-north"] =  "east-to-south",
	["west-to-south"] =  "east-to-north",
	["none-to-east"] =  "none-to-west",
	["none-to-north"] =  "none-to-south",
	["none-to-south"] =  "none-to-north",
	["none-to-west"] =  "none-to-east"
}

local entity_copy_functions = {
	["tree"] = function(surface, entity, target_position, force_name)
		if not surface.can_place_entity({name = entity.name, position = target_position}) then return end
		entity.clone({position = target_position, surface = surface, force = "neutral"})
	end,
	["simple-entity"] = function(surface, entity, target_position, force_name)
		local mirror_entity = {name = entity.name, position = target_position, direction = direction_translation[entity.direction]}
		if not surface.can_place_entity(mirror_entity) then return end
		local mirror_entity = surface.create_entity(mirror_entity)
		mirror_entity.graphics_variation = entity.graphics_variation
	end,
	["cliff"] = function(surface, entity, target_position, force_name)
		local mirror_entity = {name = entity.name, position = target_position, cliff_orientation = cliff_orientation_translation[entity.cliff_orientation]}
		if not surface.can_place_entity(mirror_entity) then return end
		surface.create_entity(mirror_entity)
		return
	end,	
	["resource"] = function(surface, entity, target_position, force_name)
		surface.create_entity({name = entity.name, position = target_position, amount = entity.amount})
	end,	
	["corpse"] = function(surface, entity, target_position, force_name)
		surface.create_entity({name = entity.name, position = target_position})
	end,	
	["unit-spawner"] = function(surface, entity, target_position, force_name)
		local mirror_entity = {name = entity.name, position = target_position, direction = direction_translation[entity.direction], force = force_name .. "_biters"}
		if not surface.can_place_entity(mirror_entity) then return end		
		table_insert(global.unit_spawners[force_name .. "_biters"], surface.create_entity(mirror_entity))
	end,
	["turret"] = function(surface, entity, target_position, force_name)
		local mirror_entity = {name = entity.name, position = target_position, direction = direction_translation[entity.direction], force = force_name .. "_biters"}
		if not surface.can_place_entity(mirror_entity) then return end
		surface.create_entity(mirror_entity)
	end,
	["rocket-silo"] = function(surface, entity, target_position, force_name)
		if surface.count_entities_filtered({name = "rocket-silo", area = {{target_position.x - 8, target_position.y - 8},{target_position.x + 8, target_position.y + 8}}}) > 0 then return end
		global.rocket_silo[force_name] = surface.create_entity({name = entity.name, position = target_position, direction = direction_translation[entity.direction], force = force_name})
		global.rocket_silo[force_name].minable = false
		Functions.add_target_entity(global.rocket_silo[force_name])
	end,	
	["ammo-turret"] = function(surface, entity, target_position, force_name)
		local direction = 0
		if force_name == "south" then direction = 4 end
		local mirror_entity = {name = entity.name, position = target_position, force = force_name, direction = direction}
		if not surface.can_place_entity(mirror_entity) then return end
		local e = surface.create_entity(mirror_entity)
		Functions.add_target_entity(e)
		local inventory = entity.get_inventory(defines.inventory.turret_ammo)
		if inventory.is_empty() then return end
		for name, count in pairs(inventory.get_contents()) do e.insert({name = name, count = count}) end	
	end,
	["wall"] = function(surface, entity, target_position, force_name)
		local e = entity.clone({position = target_position, surface = surface, force = force_name})
	end,
	["container"] = function(surface, entity, target_position, force_name)
		local e = entity.clone({position = target_position, surface = surface, force = force_name})
	end,
	["fish"] = function(surface, entity, target_position, force_name)
		local mirror_entity = {name = entity.name, position = target_position}
		if not surface.can_place_entity(mirror_entity) then return end
		local e = surface.create_entity(mirror_entity)
	end,
}

local function process_entity(surface, entity, force_name)
	if not entity.valid then return end
	if not entity_copy_functions[entity.type] then return end
	
	local target_position = {x = entity.position.x, y = entity.position.y * -1}
	entity_copy_functions[entity.type](surface, entity, target_position, force_name)
end

local function mirror_chunk(chunk)
	local surface = game.surfaces[global.bb_surface_name]
	
	local source_chunk_position = {chunk[1][1], chunk[1][2] * -1 - 1}
	local source_left_top = {x = source_chunk_position[1] * 32, y = source_chunk_position[2] * 32}
	local source_area = {{source_left_top.x, source_left_top.y}, {source_left_top.x + 32, source_left_top.y + 32}}
	
	if not surface.is_chunk_generated(source_chunk_position) then
		surface.request_to_generate_chunks({x = source_left_top.x + 16, y = source_left_top.y + 16}, 0)
		return
	end

	if chunk[2] == 1 then
		local tiles = {}
		for k, tile in pairs(surface.find_tiles_filtered({area = source_area})) do
			tiles[k] = {name = tile.name, position = {tile.position.x, tile.position.y * -1 - 1}}			
		end
		surface.set_tiles(tiles, true)
		chunk[2] = chunk[2] + 1
		return
	end
	
	if chunk[2] == 2 then
		for _, entity in pairs(surface.find_entities_filtered({area = source_area})) do
			process_entity(surface, entity, "south")
		end
		chunk[2] = chunk[2] + 1
		return
	end
	
	local decoratives = {}
	for k, decorative in pairs(surface.find_decoratives_filtered{area = source_area}) do
		decoratives[k] = {name = decorative.decorative.name, position = {decorative.position.x, decorative.position.y * -1}, amount = decorative.amount}
	end
	surface.create_decoratives({check_collision = false, decoratives = decoratives})
	
	return true
end

local function reveal_chunk(chunk)
	local surface = game.surfaces[global.bb_surface_name]
	local chunk_position = chunk[1]
	for _, force_name in pairs({"north", "south"}) do
		local force = game.forces[force_name]
		if force.is_chunk_charted(surface, chunk_position) then
			force.chart(surface, {{chunk_position[1] * 32, chunk_position[2] * 32}, {chunk_position[1] * 32 + 31, chunk_position[2] * 32 + 31}})
		end
	end
end

function Public.add_chunk(event)
	local surface = event.surface
	if surface.name ~= global.bb_surface_name then return end
	local left_top = event.area.left_top	
	local terrain_gen = global.terrain_gen
	
	if left_top.y >= 0 then
		terrain_gen.size_of_chunk_mirror = terrain_gen.size_of_chunk_mirror + 1
		terrain_gen.chunk_mirror[terrain_gen.size_of_chunk_mirror] = {{left_top.x / 32, left_top.y / 32}, 1}
	end
end

local function work()
	local terrain_gen = global.terrain_gen
	for k, chunk in pairs(terrain_gen.chunk_mirror) do			
		if mirror_chunk(chunk) then
			reveal_chunk(chunk)
			table_remove(terrain_gen.chunk_mirror, k)
			terrain_gen.size_of_chunk_mirror = terrain_gen.size_of_chunk_mirror - 1
			terrain_gen.counter = terrain_gen.counter + 1
		end			
		break
	end
end

function Public.ticking_work()
	local tick = game.ticks_played
	if tick < 4 then return end
	if global.server_restart_timer then return end
	work()
end

local function clear_entities(surface, bb)
	objects = surface.find_entities_filtered {
		area = bb,
		name = 'character',
		invert = true,
	}

	for _, object in pairs(objects) do
		object.destroy()
	end
end

function Public.clone(event)
	local surface = event.surface
	local source_bb = event.area
	local destination_bb = table.deepcopy(source_bb)

	-- Clone entities. This will trigger on_entity_cloned where
	-- we'll adjust positions, orientations etc. It will also
	-- trigger on_area_cloned where we can clone tiles at inverted positions.
	local request = {
		source_area = source_bb,
		destination_area = destination_bb,
		destination_surface = surface,
		clone_tiles = false,
		clone_entities = true,
		clone_decoratives = false,
		clear_destination_entities = false,
		clear_destination_decoratives = true,
		create_build_effect_smoke = false,
		expand_map = true
	}

	if source_bb.left_top.y < 0 then
		destination_bb.left_top.y = -source_bb.right_bottom.y
		destination_bb.right_bottom.y = -source_bb.left_top.y
	else
		source_bb.left_top.y = -destination_bb.right_bottom.y
		source_bb.right_bottom.y = -destination_bb.left_top.y
	end

	-- Workaround for what I assume is bug in game engine.
	-- "Source entities overlap with destination entities."
	-- Seems like clear_destination_entities flag is ignored in some edge
	-- cases for x > 3000, y = 0, seed = 2018927096
	clear_entities(surface, destination_bb)
	surface.clone_area(request)
end

function Public.invert_entity(event)
	local source = event.source
	local destination = event.destination

	-- Don't allow soulless characters to be cloned on spawn platform.
	if destination.name == "character" then
		destination.destroy()
		return
	end

	if destination.force.name == "north" then
		destination.force = "south"
	elseif destination.force.name == "north_biters" then
		destination.force = "south_biters"
	end

	if destination.name == "rocket-silo" then
		global.rocket_silo[destination.force.name] = destination
		Functions.add_target_entity(destination)
	elseif destination.name == "gun-turret" then
		Functions.add_target_entity(destination)
	elseif destination.name == "spitter-spawner" or destination.name == 'biter-spawner' then
		table_insert(global.unit_spawners[destination.force.name], destination)
	end

	if destination.supports_direction then
		destination.direction = direction_translation[destination.direction]
	end

	-- Invert entity position to south in relation to source entity.
	local src_pos = source.position
	local dest_pos = source.position
	dest_pos.y = -dest_pos.y

	-- Check if there are no overlaps.
	if src_pos.x == dest_pos.x and src_pos.y == dest_pos.y then
		destination.destroy()
		return
	end

	-- It's safe to use teleport() even if final position is on top
	-- of lake.
	destination.teleport(dest_pos)
end

function Public.invert_tiles(event)
	local surface = event.destination_surface
	local to_emplace = surface.find_tiles_filtered {
		area = event.source_area
	}

	local tiles = {}
	for i, tile in pairs(to_emplace) do
		if not tile.valid then goto invert_tile_continue end

		local pos = tile.position
		pos.y = -pos.y - 1
		tiles[i] = {
			position = pos,
			name = tile.name
		}

		::invert_tile_continue::
	end

	surface.set_tiles(tiles)
end

return Public
