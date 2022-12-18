local table_insert = table.insert
local math_round = math.round
local math_floor = math.floor

local Public = {}

Public.type_none = 1
Public.type_full = 2
Public.type_desert = 3
Public.type_grass = 4
Public.type_small = 5
Public.type_random = 6

Public.types = {
    [Public.type_none] = "none",
    [Public.type_full] = "full snow",
    [Public.type_desert] = "desert+snow",
    [Public.type_grass] = "grass+snow",
    [Public.type_small] = "small snow",
    [Public.type_random] = "random above",
}

local random_types = {
    Public.type_full,
    Public.type_desert,
    Public.type_grass,
    Public.type_small,
}

function Public.get_next_snow_cover()
    if global.bb_settings["snow_cover_next"] == Public.type_random then
        return random_types[math_round(#random_types)]
    end

    return global.bb_settings["snow_cover_next"]
end

Public.transition_tiles = {
    ["brown-refined-concrete"] = true,
    ["orange-refined-concrete"] = true,
}

local function get_trans_tile(src_tile)
	if src_tile == "red-desert-0" or src_tile == "red-desert-1" or global.bb_settings["snow_cover"] == Public.type_desert then
		return "orange-refined-concrete"
	else
		return "brown-refined-concrete"
	end
end

function Public.draw_biter_area_border(surface, pos)
    local adjacent_positions = {
        {x = pos.x - 1, y = pos.y},
        {x = pos.x, y = pos.y - 1},
        {x = pos.x + 1, y = pos.y},
        {x = pos.x, y = pos.y + 1},
    }
    for _, adjacent_pos in pairs(adjacent_positions) do
        if surface.get_tile(adjacent_pos).name == "lab-white" then
            surface.set_tiles({{name = "orange-refined-concrete", position = adjacent_pos}})
        end
    end
end

function Public.generate_snow(surface, left_top_x, left_top_y)
    local current_type = global.bb_settings["snow_cover"]
	local protected = {
		["deepwater"] = true,
		["water"] = true,
		["stone-path"] = true,
	}

    if current_type == Public.type_desert or current_type == Public.type_small then
        protected["red-desert-0"] = true
        protected["red-desert-1"] = true
    end

    if current_type == Public.type_grass or current_type == Public.type_small then
        protected["grass-1"] = true
        protected["grass-2"] = true
    end

    if current_type == Public.type_small then
        protected["dirt-1"] = true
        protected["dirt-2"] = true
    end


	local tiles = {}
	local replace_trees = {}
	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local pos = {x = left_top_x + x, y = left_top_y + y}

			if is_horizontal_border_river(pos) then
				goto continue
			end

			local tile_name = surface.get_tile(pos).name
			if protected[tile_name] or Public.transition_tiles[tile_name] then
				goto continue
			end

			local adjacent_positions = {
				{x = pos.x - 1, y = pos.y},
				{x = pos.x, y = pos.y - 1},
				{x = pos.x + 1, y = pos.y},
				{x = pos.x, y = pos.y + 1},
			}

			for _, adjacent_pos in pairs(adjacent_positions) do
				tile_name = surface.get_tile(adjacent_pos).name
				if protected[tile_name] then
					table_insert(tiles, {name = get_trans_tile(tile_name), position = pos})
					goto continue
				end
			end

			table_insert(tiles, {name = "lab-white", position = pos})
			replace_trees[pos.x .. "_" .. pos.y] = true

			::continue::
		end
	end

	surface.set_tiles(tiles, true)

	for _, entity in pairs(surface.find_entities({{left_top_x, left_top_y}, {left_top_x + 32, left_top_y + 32}})) do
		if entity.type == "tree" then
            local name = nil

			if entity.name == "tree-02"
				or entity.name == "tree-02-red"
				or entity.name == "tree-03"
				or entity.name == "tree-05"
				or entity.name == "tree-07"
			then
				name = "tree-01"
            end

            if entity.name == "tree-08"
                or entity.name == "tree-08-red"
                or entity.name == "tree-08-brown"
                or entity.name == "tree-09"
                or entity.name == "tree-09-red"
                or entity.name == "tree-09-brown"
            then
                name = "tree-04"
            end

            if name then
				local pos = entity.position
				local tile_pos = {x = math_floor(pos.x), y = math_floor(pos.y)}
				if replace_trees[tile_pos.x .. "_" .. tile_pos.y] then
					entity.destroy()
					surface.create_entity({name = name, position = pos})
				end
			end
		end
	end
end

return Public