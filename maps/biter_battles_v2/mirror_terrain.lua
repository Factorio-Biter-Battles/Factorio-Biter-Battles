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

	if destination.name == "rocket-silo" and math.abs(destination.position.y) < 150 and math.abs(destination.position.x) < 100 then
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

function Public.remove_hidden_tiles(event)
	local bb = event.destination_area
	local surface = event.destination_surface
	local to_remove = surface.find_tiles_filtered {
		area = bb,
		has_hidden_tile = true,
		name = "stone-path",
	}

	local tiles = {}
	for i, tile in pairs(to_remove) do
		if not tile.valid then goto remove_hidden_cont end
		surface.set_hidden_tile(tile.position, nil)

		::remove_hidden_cont::
	end
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
