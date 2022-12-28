local Public = {}
local LootRaffle = require "functions.loot_raffle"
local BiterRaffle = require "maps.biter_battles_v2.biter_raffle"
local bb_config = require "maps.biter_battles_v2.config"
local Functions = require "maps.biter_battles_v2.functions"
local tables = require "maps.biter_battles_v2.tables"
local session = require 'utils.datastore.session_data'

local spawn_ore = tables.spawn_ore
local table_insert = table.insert
local math_floor = math.floor
local math_random = math.random
local math_abs = math.abs
local math_sqrt = math.sqrt

local GetNoise = require "utils.get_noise"
local simplex_noise = require 'utils.simplex_noise'.d2
local river_circle_size = 39
local spawn_island_size = 9
local ores = {"copper-ore", "iron-ore", "stone", "coal"}
-- mixed_ore_multiplier order is based on the ores variable
local mixed_ore_multiplier = {1, 1, 1, 1}
local rocks = {"rock-huge", "rock-big", "rock-big", "rock-big", "sand-rock-big"}

local chunk_tile_vectors = {}
for x = 0, 31, 1 do
	for y = 0, 31, 1 do
		chunk_tile_vectors[#chunk_tile_vectors + 1] = {x, y}
	end
end
local size_of_chunk_tile_vectors = #chunk_tile_vectors

local loading_chunk_vectors = {}
for _, v in pairs(chunk_tile_vectors) do
	if v[1] == 0 or v[1] == 31 or v[2] == 0 or v[2] == 31 then table_insert(loading_chunk_vectors, v) end
end

local wrecks = {"crash-site-spaceship-wreck-big-1", "crash-site-spaceship-wreck-big-2", "crash-site-spaceship-wreck-medium-1", "crash-site-spaceship-wreck-medium-2", "crash-site-spaceship-wreck-medium-3"}
local size_of_wrecks = #wrecks
local valid_wrecks = {}
for _, wreck in pairs(wrecks) do valid_wrecks[wreck] = true end
local loot_blacklist = {
	["automation-science-pack"] = true,
	["logistic-science-pack"] = true,
	["military-science-pack"] = true,
	["chemical-science-pack"] = true,
	["production-science-pack"] = true,
	["utility-science-pack"] = true,
	["space-science-pack"] = true,
	["loader"] = true,
	["fast-loader"] = true,
	["express-loader"] = true,		
}

local function shuffle(tbl)
	local size = #tbl
		for i = size, 1, -1 do
			local rand = math_random(size)
			tbl[i], tbl[rand] = tbl[rand], tbl[i]
		end
	return tbl
end

local function create_mirrored_tile_chain(surface, tile, count, straightness)
	if not surface then return end
	if not tile then return end
	if not count then return end

	local position = {x = tile.position.x, y = tile.position.y}
	
	local modifiers = {
		{x = 0, y = -1},{x = -1, y = 0},{x = 1, y = 0},{x = 0, y = 1},
		{x = -1, y = 1},{x = 1, y = -1},{x = 1, y = 1},{x = -1, y = -1}
	}	
	modifiers = shuffle(modifiers)
	
	for _ = 1, count, 1 do
		local tile_placed = false
		
		if math_random(0, 100) > straightness then modifiers = shuffle(modifiers) end
		for b = 1, 4, 1 do
			local pos = {x = position.x + modifiers[b].x, y = position.y + modifiers[b].y}
			if surface.get_tile(pos).name ~= tile.name then
				surface.set_tiles({{name = "landfill", position = pos}}, true)
				surface.set_tiles({{name = tile.name, position = pos}}, true)
				--surface.set_tiles({{name = "landfill", position = {pos.x * -1, (pos.y * -1) - 1}}}, true)
				--surface.set_tiles({{name = tile.name, position = {pos.x * -1, (pos.y * -1) - 1}}}, true)
				position = {x = pos.x, y = pos.y}
				tile_placed = true
				break
			end			
		end						
		
		if not tile_placed then
			position = {x = position.x + modifiers[1].x, y = position.y + modifiers[1].y}
		end		
	end			
end

local function get_replacement_tile(surface, position)
	for i = 1, 128, 1 do
		local vectors = {{0, i}, {0, i * -1}, {i, 0}, {i * -1, 0}}
		table.shuffle_table(vectors)
		for _, v in pairs(vectors) do
			local tile = surface.get_tile(position.x + v[1], position.y + v[2])
			if not tile.collides_with("resource-layer") then
				if tile.name ~= "stone-path" then
					return tile.name
				end
			end
		end
	end
	return "grass-1"
end

local function draw_noise_ore_patch(position, name, surface, radius, richness)
	if not position then return end
	if not name then return end
	if not surface then return end
	if not radius then return end
	if not richness then return end
	local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
	local noise_seed_add = 25000
	local richness_part = richness / radius
	for y = radius * -3, radius * 3, 1 do
		for x = radius * -3, radius * 3, 1 do
			local pos = {x = x + position.x + 0.5, y = y + position.y + 0.5}			
			local noise_1 = simplex_noise(pos.x * 0.0125, pos.y * 0.0125, seed)
			local noise_2 = simplex_noise(pos.x * 0.1, pos.y * 0.1, seed + 25000)
			local noise = noise_1 + noise_2 * 0.12
			local distance_to_center = math_sqrt(x^2 + y^2)
			local a = richness - richness_part * distance_to_center
			if distance_to_center < radius - math_abs(noise * radius * 0.85) and a > 1 then
				if surface.can_place_entity({name = name, position = pos, amount = a}) then
					surface.create_entity{name = name, position = pos, amount = a}
					for _, e in pairs(surface.find_entities_filtered({position = pos, name = {"wooden-chest", "stone-wall", "gun-turret"}})) do					
						e.destroy()
					end
				end
			end
		end
	end
end

-- distance to the center of the map from the center of the tile
local function tile_distance_to_center(tile_pos)
	return math_sqrt((tile_pos.x + 0.5) ^ 2 + (tile_pos.y + 0.5) ^ 2)
end

local function is_within_spawn_island(pos)
	if math_abs(pos.x) > spawn_island_size then return false end
	if math_abs(pos.y) > spawn_island_size then return false end
	if tile_distance_to_center(pos) > spawn_island_size then return false end
	return true
end

-- border_river_noise is the maximum random value that can be added to each side of the river
local border_river_noise = 4
local river_width_half_min = math_floor(bb_config.border_river_width * -0.5)
local river_width_half_max = river_width_half_min - border_river_noise
-- pos must be from the North side
local function is_horizontal_border_river(pos)
	if tile_distance_to_center(pos) < river_circle_size then return true end
	if pos.y < river_width_half_max then return false end
	if pos.y > river_width_half_min then return true end
	if pos.y >= river_width_half_min - (math_abs(Functions.get_noise(1, pos)) * border_river_noise) then return true end
	return false
end

local function generate_starting_area(pos, surface)
	local spawn_wall_radius = 116
	local noise_multiplier = 15 
	local min_noise = -noise_multiplier * 1.25

	if is_horizontal_border_river(pos) then
		return
	end

	local distance_to_center = tile_distance_to_center(pos)
	-- Avoid calculating noise, see comment below
	if (distance_to_center + min_noise - spawn_wall_radius) > 4.5 then
		return
	end

	local noise = Functions.get_noise(2, pos) * noise_multiplier
	local distance_from_spawn_wall = distance_to_center + noise - spawn_wall_radius
	-- distance_from_spawn_wall is the difference between the distance_to_center (with added noise) 
	-- and our spawn_wall radius (spawn_wall_radius=116), i.e. how far are we from the ring with radius spawn_wall_radius.
	-- The following shows what happens depending on distance_from_spawn_wall:
	--   	min     max
    --  	N/A     -10	    => replace water
	-- if noise_2 > -0.5:
	--      -1.75    0 	    => wall
	-- else:
	--   	-6      -3 	 	=> 1/16 chance of turret or turret-remnants
	--   	-1.95    0 	 	=> wall
	--    	 0       4.5    => chest-remnants with 1/3, chest with 1/(distance_from_spawn_wall+2)
	--
	-- => We never do anything for (distance_to_center + min_noise - spawn_wall_radius) > 4.5

	if distance_from_spawn_wall < 0 then
		if math_random(1, 100) > 23 then
			for _, tree in pairs(surface.find_entities_filtered({type = "tree", area = {{pos.x, pos.y}, {pos.x + 1, pos.y + 1}}})) do
				tree.destroy()
			end
		end
	end

	if distance_from_spawn_wall < -10 then
		local tile_name = surface.get_tile(pos).name
		if tile_name == "water" or tile_name == "deepwater" then
			surface.set_tiles({{name = get_replacement_tile(surface, pos), position = pos}}, true)
		end
		return
	end

	if surface.can_place_entity({name = "wooden-chest", position = pos}) and surface.can_place_entity({name = "coal", position = pos}) then
		local noise_2 = Functions.get_noise(3, pos)
		if noise_2 < 0.40 then
			if noise_2 > -0.40 then
				if distance_from_spawn_wall > -1.75 and distance_from_spawn_wall < 0 then				
					local e = surface.create_entity({name = "stone-wall", position = pos, force = "north"})
				end
			else
				if distance_from_spawn_wall > -1.95 and distance_from_spawn_wall < 0 then				
					local e = surface.create_entity({name = "stone-wall", position = pos, force = "north"})

				elseif distance_from_spawn_wall > 0 and distance_from_spawn_wall < 4.5 then
						local name = "wooden-chest"
						local r_max = math_floor(math.abs(distance_from_spawn_wall)) + 2
						if math_random(1,3) == 1 then name = name .. "-remnants" end
						if math_random(1,r_max) == 1 then 
							local e = surface.create_entity({name = name, position = pos, force = "north"})
						end

				elseif distance_from_spawn_wall > -6 and distance_from_spawn_wall < -3 then
					if math_random(1, 16) == 1 then
						if surface.can_place_entity({name = "gun-turret", position = pos}) then
							local e = surface.create_entity({name = "gun-turret", position = pos, force = "north"})
							e.insert({name = "firearm-magazine", count = math_random(2,16)})
							Functions.add_target_entity(e)
						end
					else
						if math_random(1, 24) == 1 then
							if surface.can_place_entity({name = "gun-turret", position = pos}) then
								surface.create_entity({name = "gun-turret-remnants", position = pos, force = "neutral"})
							end
						end
					end
				end
			end
		end
	end
end

local function generate_river(surface, left_top_x, left_top_y)
	if not (left_top_y == -32 or (left_top_y == -64 and (left_top_x == -32 or left_top_x == 0))) then return end
	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local pos = {x = left_top_x + x, y = left_top_y + y}
			if is_horizontal_border_river(pos) and not is_within_spawn_island(pos) then
				surface.set_tiles({{name = "deepwater", position = pos}})
				if math_random(1, 64) == 1 then 
					local e = surface.create_entity({name = "fish", position = pos})
				end
			end
		end
	end	
end

local scrap_vectors = {}
for x = -8, 8, 1 do
	for y = -8, 8, 1 do
		if math_sqrt(x^2 + y^2) <= 8 then
			scrap_vectors[#scrap_vectors + 1] = {x, y}
		end
	end
end
local size_of_scrap_vectors = #scrap_vectors

local function generate_extra_worm_turrets(surface, left_top)
	local chunk_distance_to_center = math_sqrt(left_top.x ^ 2 + left_top.y ^ 2)
	if bb_config.bitera_area_distance > chunk_distance_to_center then return end
	
	local amount = (chunk_distance_to_center - bb_config.bitera_area_distance) * 0.0005
	if amount < 0 then return end
	local floor_amount = math_floor(amount)
	local r = math.round(amount - floor_amount, 3) * 1000
	if math_random(0, 999) <= r then floor_amount = floor_amount + 1 end 
	
	if floor_amount > 64 then floor_amount = 64 end
	
	for _ = 1, floor_amount, 1 do	
		local worm_turret_name = BiterRaffle.roll("worm", chunk_distance_to_center * 0.00015)
		local v = chunk_tile_vectors[math_random(1, size_of_chunk_tile_vectors)]
		local position = surface.find_non_colliding_position(worm_turret_name, {left_top.x + v[1], left_top.y + v[2]}, 8, 1)
		if position then
			local worm = surface.create_entity({name = worm_turret_name, position = position, force = "north_biters"})
			
			-- add some scrap			
			for _ = 1, math_random(0, 4), 1 do
				local vector = scrap_vectors[math_random(1, size_of_scrap_vectors)]
				local position = {worm.position.x + vector[1], worm.position.y + vector[2]}
				local name = wrecks[math_random(1, size_of_wrecks)]					
				position = surface.find_non_colliding_position(name, position, 16, 1)									
				if position then
					local e = surface.create_entity({name = name, position = position, force = "neutral"})
				end
			end		
		end
	end
end

local function draw_biter_area(surface, left_top_x, left_top_y)
	if not Functions.is_biter_area({x = left_top_x, y = left_top_y - 96},true) then return end
	
	local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
		
	local out_of_map = {}
	local tiles = {}
	local i = 1
	
	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local position = {x = left_top_x + x, y = left_top_y + y}
			if Functions.is_biter_area(position,true) then
				local index = math_floor(GetNoise("bb_biterland", position, seed) * 48) % 7 + 1
				out_of_map[i] = {name = "out-of-map", position = position}
				tiles[i] = {name = "dirt-" .. index, position = position}
				i = i + 1			
			end
		end
	end
	
	surface.set_tiles(out_of_map, false)
	surface.set_tiles(tiles, true)
	
	for _ = 1, 4, 1 do
		local v = chunk_tile_vectors[math_random(1, size_of_chunk_tile_vectors)]
		local position = {x = left_top_x + v[1], y = left_top_y + v[2]}
		if Functions.is_biter_area(position,true) and surface.can_place_entity({name = "spitter-spawner", position = position}) then
			local e
			if math_random(1, 4) == 1 then
				e = surface.create_entity({name = "spitter-spawner", position = position, force = "north_biters"})
			else
				e = surface.create_entity({name = "biter-spawner", position = position, force = "north_biters"})
			end
			table.insert(global.unit_spawners[e.force.name], e)
		end
	end

	local e = (math_abs(left_top_y) - bb_config.bitera_area_distance) * 0.0015	
	for _ = 1, math_random(5, 10), 1 do
		local v = chunk_tile_vectors[math_random(1, size_of_chunk_tile_vectors)]
		local position = {x = left_top_x + v[1], y = left_top_y + v[2]}
		local worm_turret_name = BiterRaffle.roll("worm", e)
		if Functions.is_biter_area(position,true) and surface.can_place_entity({name = worm_turret_name, position = position}) then
			surface.create_entity({name = worm_turret_name, position = position, force = "north_biters"})
		end
	end
end

local function mixed_ore(surface, left_top_x, left_top_y)
	local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
	
	local noise = GetNoise("bb_ore", {x = left_top_x + 16, y = left_top_y + 16}, seed)

	--Draw noise text values to determine which chunks are valid for mixed ore.
	--rendering.draw_text{text = noise, surface = game.surfaces.biter_battles, target = {x = left_top_x + 16, y = left_top_y + 16}, color = {255, 255, 255}, scale = 2, font = "default-game"}

	--Skip chunks that are too far off the ore noise value.
	if noise < 0.42 then return end

	--Draw the mixed ore patches.
	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local pos = {x = left_top_x + x, y = left_top_y + y}
			if surface.can_place_entity({name = "iron-ore", position = pos}) then
				local noise = GetNoise("bb_ore", pos, seed)
				if noise > 0.72 then
					local i = math_floor(noise * 25 + math_abs(pos.x) * 0.05) % 4 + 1
					local amount = (math_random(800, 1000) + math_sqrt(pos.x ^ 2 + pos.y ^ 2) * 3) * mixed_ore_multiplier[i]
					surface.create_entity({name = ores[i], position = pos, amount = amount})
				end
			end
		end
	end
	
	if left_top_y == -32 and math_abs(left_top_x) <= 32 then
		for _, e in pairs(surface.find_entities_filtered({name = 'character', invert = true, area = {{-12, -12},{12, 12}}})) do e.destroy() end
	end
end

function Public.generate(event)
	local surface = event.surface
	local left_top = event.area.left_top
	local left_top_x = left_top.x
	local left_top_y = left_top.y

	mixed_ore(surface, left_top_x, left_top_y)
	generate_river(surface, left_top_x, left_top_y)
	draw_biter_area(surface, left_top_x, left_top_y)		
	generate_extra_worm_turrets(surface, left_top)
end

function Public.draw_spawn_island(surface)
	local tiles = {}
	for x = math_floor(spawn_island_size) * -1, -1, 1 do
		for y = math_floor(spawn_island_size) * -1, -1, 1 do
			local pos = {x = x, y = y}
			if is_within_spawn_island(pos) then
				local distance_to_center = tile_distance_to_center(pos)
				local tile_name = "refined-concrete"
				if distance_to_center < 6.3 then
					tile_name = "sand-1"
				end

				if global.bb_settings['new_year_island'] then
					tile_name = "blue-refined-concrete"
					if distance_to_center < 6.3 then
						tile_name = "lab-white"
					end
				end

				table_insert(tiles, {name = tile_name, position = pos})
			end
		end
	end

	for i = 1, #tiles, 1 do
		table_insert(tiles, {name = tiles[i].name, position = {tiles[i].position.x * -1 - 1, tiles[i].position.y}})
	end

	surface.set_tiles(tiles, true)

	local island_area = {{-spawn_island_size, -spawn_island_size}, {spawn_island_size, 0}}
	surface.destroy_decoratives({area = island_area})
	for _, entity in pairs(surface.find_entities(island_area)) do
		entity.destroy()
	end
end

function Public.draw_spawn_area(surface)
	local chunk_r = 4
	local r = chunk_r * 32	
	
	for x = r * -1, r, 1 do
		for y = r * -1, -4, 1 do
			generate_starting_area({x = x, y = y}, surface)
		end
	end
	
	surface.destroy_decoratives({})
	surface.regenerate_decorative()
end

function Public.draw_water_for_river_ends(surface, chunk_pos)
	local left_top_x = chunk_pos.x * 32
	for x = 0, 31, 1 do
		local pos = {x = left_top_x + x, y = 1}
		surface.set_tiles({{name = "deepwater", position = pos}})
	end
end


local function draw_grid_ore_patch(count, grid, name, surface, size, density)
	-- Takes a random left_top coordinate from grid, removes it and draws
	-- ore patch on top of it. Grid is held by reference, so this function
	-- is reentrant.
	for i = 1, count, 1 do
		local idx = math.random(1, #grid)
		local pos = grid[idx]
		table.remove(grid, idx)

		-- The draw_noise_ore_patch expects position with x and y keys.
		pos = { x = pos[1], y = pos[2] }
		draw_noise_ore_patch(pos, name, surface, size, density)
	end
end

local function _clear_resources(surface, area)
	local resources = surface.find_entities_filtered {
		area = area,
		type = "resource",
	}

	local i = 0
	for _, res in pairs(resources) do
		if not res.valid then
			goto clear_resources_cont
		end
		res.destroy()
		i = i + 1

		::clear_resources_cont::
	end

	return i
end

function Public.clear_ore_in_main(surface)
	local area = {
		left_top = { -150, -150 },
		right_bottom = { 150, 0 }
	}
	local limit = 20
	local cnt = 0
	repeat
		-- Keep clearing resources until there is none.
		-- Each cycle increases search area.
		cnt = _clear_resources(surface, area)
		limit = limit - 1
		area.left_top[1] = area.left_top[1] - 5
		area.left_top[2] = area.left_top[2] - 5
		area.right_bottom[1] = area.right_bottom[1] + 5
	until cnt == 0 or limit == 0

	if limit == 0 then
		log("Limit reached, some ores might be truncated in spawn area")
		log("If this is a custom build, remove a call to clear_ore_in_main")
		log("If this in a standard value, limit could be tweaked")
	end
end

function Public.generate_spawn_ore(surface)
	-- This array holds indicies of chunks onto which we desire to
	-- generate ore patches. It is visually representing north spawn
	-- area. One element was removed on purpose - we don't want to
	-- draw ore in the lake which overlaps with chunk [0,-1]. All ores
	-- will be mirrored to south.
	local grid = {
		{ -2, -3 }, { -1, -3 }, { 0, -3 }, { 1, -3, }, { 2, -3 },
		{ -2, -2 }, { -1, -2 }, { 0, -2 }, { 1, -2, }, { 2, -2 },
		{ -2, -1 }, { -1, -1 },            { 1, -1, }, { 2, -1 },
	}

	-- Calculate left_top position of a chunk. It will be used as origin
	-- for ore drawing. Reassigns new coordinates to the grid.
	for i, _ in ipairs(grid) do
		grid[i][1] = grid[i][1] * 32 + math.random(-12, 12)
		grid[i][2] = grid[i][2] * 32 + math.random(-24, -1)
	end

	for name, props in pairs(spawn_ore) do
		draw_grid_ore_patch(props.big_patches, grid, name, surface,
				    props.size, props.density)
		draw_grid_ore_patch(props.small_patches, grid, name, surface,
				    props.size / 2, props.density)
	end
end

function Public.generate_additional_rocks(surface)
	local r = 130
	if surface.count_entities_filtered({type = "simple-entity", area = {{r * -1, r * -1}, {r, 0}}}) >= 12 then return end		
	local position = {x = -96 + math_random(0, 192), y = -40 - math_random(0, 96)}
	for _ = 1, math_random(6, 10) do
		local name = rocks[math_random(1, 5)]
		local p = surface.find_non_colliding_position(name, {position.x + (-10 + math_random(0, 20)), position.y + (-10 + math_random(0, 20))}, 16, 1)
		if p and p.y < -16 then
			surface.create_entity({name = name, position = p})
		end
	end
end

function Public.generate_silo(surface)
	local pos = {x = -32 + math_random(0, 64), y = -72}
	local mirror_position = {x = pos.x * -1, y = pos.y * -1}

	for _, t in pairs(surface.find_tiles_filtered({area = {{pos.x - 6, pos.y - 6},{pos.x + 6, pos.y + 6}}, name = {"water", "deepwater"}})) do
		surface.set_tiles({{name = get_replacement_tile(surface, t.position), position = t.position}})
	end
	for _, t in pairs(surface.find_tiles_filtered({area = {{mirror_position.x - 6, mirror_position.y - 6},{mirror_position.x + 6, mirror_position.y + 6}}, name = {"water", "deepwater"}})) do
		surface.set_tiles({{name = get_replacement_tile(surface, t.position), position = t.position}})
	end

	local silo = surface.create_entity({
		name = "rocket-silo",
		position = pos,
		force = "north"
	})
	silo.minable = false
	global.rocket_silo[silo.force.name] = silo
	Functions.add_target_entity(global.rocket_silo[silo.force.name])

	for _ = 1, 32, 1 do
		create_mirrored_tile_chain(surface, {name = "stone-path", position = silo.position}, 32, 10)
	end
	
	local p = silo.position
	for _, entity in pairs(surface.find_entities({{p.x - 4, p.y - 4}, {p.x + 4, p.y + 4}})) do
		if entity.type == "simple-entity" or entity.type == "tree" or entity.type == "resource" then
			entity.destroy()
		end
	end
	local turret1 = surface.create_entity({name = "gun-turret", position = {x=pos.x, y=pos.y-5}, force = "north"})
	turret1.insert({name = "firearm-magazine", count = 10})
	local turret2 = surface.create_entity({name = "gun-turret", position = {x=pos.x+2, y=pos.y-5}, force = "north"})
	turret2.insert({name = "firearm-magazine", count = 10})
end
--[[
function Public.generate_spawn_goodies(surface)
	local tiles = surface.find_tiles_filtered({name = "stone-path"})
	table.shuffle_table(tiles)
	local budget = 1500
	local min_roll = 30
	local max_roll = 600
	local blacklist = {
		["automation-science-pack"] = true,
		["logistic-science-pack"] = true,
		["military-science-pack"] = true,
		["chemical-science-pack"] = true,
		["production-science-pack"] = true,
		["utility-science-pack"] = true,
		["space-science-pack"] = true,
		["loader"] = true,
		["fast-loader"] = true,
		["express-loader"] = true,		
	}
	local container_names = {"wooden-chest", "wooden-chest", "iron-chest"}
	for k, tile in pairs(tiles) do
		if budget <= 0 then return end
		if surface.can_place_entity({name = "wooden-chest", position = tile.position, force = "neutral"}) then
			local v = math_random(min_roll, max_roll)
			local item_stacks = LootRaffle.roll(v, 4, blacklist)		
			local container = surface.create_entity({name = container_names[math_random(1, 3)], position = tile.position, force = "neutral"})
			for _, item_stack in pairs(item_stacks) do container.insert(item_stack)	end
			budget = budget - v
		end
	end
end
]]

function Public.minable_wrecks(event)
	local entity = event.entity
	if not entity then return end
	if not entity.valid then return end
	if not valid_wrecks[entity.name] then return end
	
	local surface = entity.surface
	local player = game.players[event.player_index]
	
	local loot_worth = math_floor(math_abs(entity.position.x * 0.02)) + math_random(16, 32)	
	local blacklist = LootRaffle.get_tech_blacklist(math_abs(entity.position.x * 0.0001) + 0.10)
	for k, _ in pairs(loot_blacklist) do blacklist[k] = true end
	local item_stacks = LootRaffle.roll(loot_worth, math_random(1, 3), blacklist)
		
	for k, stack in pairs(item_stacks) do	
		local amount = stack.count
		local name = stack.name
		
		local inserted_count = player.insert({name = name, count = amount})	
		if inserted_count ~= amount then
			local amount_to_spill = amount - inserted_count			
			surface.spill_item_stack(entity.position, {name = name, count = amount_to_spill}, true)
		end
		
		surface.create_entity({
			name = "flying-text",
			position = {entity.position.x, entity.position.y - 0.5 * k},
			text = "+" .. amount .. " [img=item/" .. name .. "]",
			color = {r=0.98, g=0.66, b=0.22}
		})	
	end
end

--Landfill Restriction
function Public.restrict_landfill(surface, user, tiles)
	for _, t in pairs(tiles) do
		local check_position = t.position
		if check_position.y > 0 then check_position = {x = check_position.x, y = (check_position.y * -1) - 1} end
		local trusted = session.get_trusted_table()
		if is_horizontal_border_river(check_position) then
			surface.set_tiles({{name = t.old_tile.name, position = t.position}}, true)
			if user ~= nil then
				user.print('You can not landfill the river', {r = 0.22, g = 0.99, b = 0.99})
			end
	    elseif user ~= nil and not trusted[user.name] then
			surface.set_tiles({{name = t.old_tile.name, position = t.position}}, true)
			user.print('You have not grown accustomed to this technology yet.', {r = 0.22, g = 0.99, b = 0.99})
		end
	end
end

function Public.deny_bot_landfill(event)
	if event.item ~= nil and event.item.name == "landfill" then
		Public.restrict_landfill(event.robot.surface, nil, event.tiles)
	end
end

--Construction Robot Restriction
local robot_build_restriction = {
	["north"] = function(y)
		if y >= -bb_config.border_river_width / 2 then return true end
	end,
	["south"] = function(y)
		if y <= bb_config.border_river_width / 2 then return true end
	end
}

function Public.deny_construction_bots(event)
	if not robot_build_restriction[event.robot.force.name] then return end
	if not robot_build_restriction[event.robot.force.name](event.created_entity.position.y) then return end
	local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
	inventory.insert({name = event.created_entity.name, count = 1})
	event.robot.surface.create_entity({name = "explosion", position = event.created_entity.position})
	game.print("Team " .. event.robot.force.name .. "'s construction drone had an accident.", {r = 200, g = 50, b = 100})
	event.created_entity.destroy()
end

function Public.deny_enemy_side_ghosts(event)
	if not event.created_entity.valid then return end
	if event.created_entity.type == 'entity-ghost' or event.created_entity.type == 'tile-ghost' then
		local force = game.get_player(event.player_index).force.name
		if not robot_build_restriction[force] then return end
		if not robot_build_restriction[force](event.created_entity.position.y) then return end
		event.created_entity.destroy()
	end
end

local function add_gifts(surface)
	-- exclude dangerous goods
	local blacklist = LootRaffle.get_tech_blacklist(0.95)
	for k, _ in pairs(loot_blacklist) do blacklist[k] = true end

	for i = 1, math_random(8, 12) do
		local loot_worth = math_random(1, 35000)
		local item_stacks = LootRaffle.roll(loot_worth, 3, blacklist)
		for k, stack in pairs(item_stacks) do
			surface.spill_item_stack(
				{
					x = math_random(-10, 10) * 0.1,
					y = math_random(-5, 15) * 0.1
				},
				{name = stack.name, count = 1}, false, nil, true)
		end
	end
end

function Public.add_new_year_island_decorations(surface)
	for _ = 1, math_random(0, 4) do
		local stump = surface.create_entity({
			name = "tree-05-stump",
			position = {x = math_random(-40, 40) * 0.1, y = math_random(-40, 40) * 0.1}
		})
		stump.corpse_expires = false
	end

	local scorchmark = surface.create_entity({
		name = "medium-scorchmark-tintable",
		position = {x = 0, y = 0}
	})
	scorchmark.corpse_expires = false

	local tree = surface.create_entity({
		name = "tree-01",
		position = {x = 0, y = 0.05}
	})
	tree.minable = false
	tree.destructible = false

	add_gifts(surface)

	local signals = {
		{name = "rail-signal", position = {-0.5, -5.5}, direction = defines.direction.west},
		{name = "rail-signal", position = {0.5, -5.5}, direction = defines.direction.west},
		{name = "rail-signal", position = {2.5, -4.5}, direction = defines.direction.northwest},
		{name = "rail-signal", position = {4.5, -2.5}, direction = defines.direction.northwest},
		{name = "rail-signal", position = {5.5, -0.5}, direction = defines.direction.north},
		{name = "rail-signal", position = {5.5, 0.5}, direction = defines.direction.north},
		{name = "rail-signal", position = {4.5, 2.5}, direction = defines.direction.northeast},
		{name = "rail-signal", position = {2.5, 4.5}, direction = defines.direction.northeast},
		{name = "rail-signal", position = {0.5, 5.5}, direction = defines.direction.east},
		{name = "rail-signal", position = {-0.5, 5.5}, direction = defines.direction.east},
		{name = "rail-signal", position = {-2.5, 4.5}, direction = defines.direction.southeast},
		{name = "rail-signal", position = {-4.5, 2.5}, direction = defines.direction.southeast},
		{name = "rail-signal", position = {-5.5, 0.5}, direction = defines.direction.south},
		{name = "rail-signal", position = {-5.5, -0.5}, direction = defines.direction.south},
		{name = "rail-signal", position = {-4.5, -2.5}, direction = defines.direction.southwest},
		{name = "rail-signal", position = {-2.5, -4.5}, direction = defines.direction.southwest},
	}
	for _, v in pairs(signals) do
		local signal = surface.create_entity(v)
		signal.minable = false
		signal.destructible = false
	end

	for _ = 1, math_random(0, 6) do
		surface.create_decoratives{check_collision = false, decoratives = {{
			name = "green-asterisk-mini",
			position = {x = math_random(-40, 40) * 0.1, y = math_random(-40, 40) * 0.1},
			amount = 1
		}}}
	end
	for _ = 1, math_random(0, 6) do
		surface.create_decoratives{check_collision = false, decoratives = {{
			name = "rock-tiny",
			position = {x = math_random(-40, 40) * 0.1, y = math_random(-40, 40) * 0.1},
			amount = 1
		}}}
	end
end

return Public
