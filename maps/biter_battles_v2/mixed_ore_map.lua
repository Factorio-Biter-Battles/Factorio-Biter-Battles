local Functions = require "maps.biter_battles_v2.functions"
local GetNoise = require "utils.get_noise"
local math_floor = math.floor
local math_random = math.random
local math_abs = math.abs
local math_sqrt = math.sqrt

local function clear_ores(surface, left_top_x, left_top_y, ores)
	local resources = surface.find_entities_filtered {
		area = {{left_top_x, left_top_y}, {left_top_x + 32, left_top_y + 32}},
		name = ores,
	}

	for _, res in pairs(resources) do
		if res.valid then
			res.destroy()
		end
	end
end

local function mixed_ore(surface, left_top_x, left_top_y)
	local ores = {"uranium-ore", "stone", "copper-ore", "iron-ore", "coal"}
	local mixed_ore_weight = {}
	local mixed_ore_weight_total = 0
	for k, v in ipairs({0.3, 6, 8.05, 8.5,  6.5}) do
		mixed_ore_weight_total = mixed_ore_weight_total + v
		mixed_ore_weight[k] = mixed_ore_weight_total
	end

	clear_ores(surface, left_top_x, left_top_y, ores)
	local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
	local size = 1 + global.special_games_variables['mixed_ore_map']['size']
	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local pos = {x = left_top_x + x, y = left_top_y + y}
			if surface.can_place_entity({name = "iron-ore", position = pos}) then
				local noise = GetNoise("bb_ore", pos, seed)
				local i_raw = math_floor(noise * 25 * size + math_abs(pos.x) * 0.05 ) % mixed_ore_weight_total
				local i = 1
				for k, v in ipairs(mixed_ore_weight) do
					if i_raw < v then
						i = k
						break
					end
				end
				local amount = (math_random(80, 100) + math_sqrt(math_abs(pos.x) ^ 1.5 + math_abs(pos.y) ^ 1.5) * 1)
				surface.create_entity({name = ores[i], position = pos, amount = amount, enable_tree_removal = false})
			end
		end
	end
end

local function checkerboard(surface, left_top_x, left_top_y)
	local ores = {"uranium-ore", "stone", "copper-ore", "iron-ore", "coal"}
	clear_ores(surface, left_top_x, left_top_y, ores)
	local uranium_cells = {}
	local cell_size = global.special_games_variables['mixed_ore_map']['size']
	local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local pos = {x = left_top_x + x, y = left_top_y + y}
			if surface.can_place_entity({name = "iron-ore", position = pos}) then
				local ore
				local cell_start_pos = {
					x = pos.x - (pos.x % cell_size),
					y = pos.y - (pos.y % cell_size)
				}
				local cell_start_key = cell_start_pos.x .. "_" .. cell_start_pos.y
				if uranium_cells[cell_start_key] == nil then
					local new_seed = (cell_start_pos.x * 374761393 + cell_start_pos.y * 668265263 + seed) % 4294967296 -- numbers from internet
					local rng = game.create_random_generator(new_seed)
					uranium_cells[cell_start_key] = rng() > 0.999
				end

				if uranium_cells[cell_start_key] then
					ore = ores[1]
				else
					local cx = pos.x % (cell_size*2)
					local cy = pos.y % (cell_size*2)
					local is_row1 = cy >= 0 and cy < cell_size

					if cx >= 0 and cx < cell_size then -- col 1
						if is_row1 then  -- row 1
							ore = ores[3]
						else -- row 2
							ore = ores[4]
						end
					else -- col 2
						if is_row1 then -- row 1
							ore = ores[5]
						else -- row 2
							ore = ores[2]
						end
					end
				end

				surface.create_entity({name = ore, position = pos, amount = 15000, enable_tree_removal = false})
			end
		end
	end
end

local function vertical_lines(surface, left_top_x, left_top_y)
	local ores = {"copper-ore", "stone", "iron-ore", "coal", "iron-ore", "coal", "iron-ore", "iron-ore", "stone", "iron-ore", "stone", "coal", "iron-ore", "coal", "stone", "iron-ore" }
	clear_ores(surface, left_top_x, left_top_y, {"coal", "stone", "copper-ore","iron-ore"})
	local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed

	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local pos = {x = left_top_x + x, y = left_top_y + y}
			if surface.can_place_entity({name = "iron-ore", position = pos}) then
				local noise = GetNoise("bb_ore_vertical_lines", pos, seed)
				local i = math.floor(noise * 50 + math.abs(pos.x) * 0.2) % 16 + 1
				local amount = (1000 + math.sqrt(pos.x ^ 2 + pos.y ^ 2) * 3) * 10
				surface.create_entity({name = ores[i], position = pos, amount = amount, enable_tree_removal = false})
			end
		end
	end
end

-- generate ore on entire map for special game
local function mixed_ore_map(surface, left_top_x, left_top_y)
	if Functions.is_biter_area({x = left_top_x, y = left_top_y + 96}, true) then return end

	local type = global.special_games_variables['mixed_ore_map']['type']
	if type == 1 then
		mixed_ore(surface, left_top_x, left_top_y)
	elseif type == 2 then
		checkerboard(surface, left_top_x, left_top_y)
	elseif type == 3 then
		vertical_lines(surface, left_top_x, left_top_y)
	end

	if left_top_y == -32 and math_abs(left_top_x) <= 32 then
		for _, e in pairs(surface.find_entities_filtered({name = 'character', invert = true, area = {{-12, -12},{12, 12}}})) do e.destroy() end
	end
end

return mixed_ore_map
