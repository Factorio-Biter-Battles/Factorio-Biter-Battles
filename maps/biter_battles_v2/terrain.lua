local Public = {}
local LootRaffle = require('functions.loot_raffle')
local BiterRaffle = require('maps.biter_battles_v2.biter_raffle')
local bb_config = require('maps.biter_battles_v2.config')
local mixed_ore_map_special = require('maps.biter_battles_v2.mixed_ore_map_special')
local multi_octave_noise = require('utils.multi_octave_noise')
local noise = require('maps.biter_battles_v2.predefined_noise')
local AiTargets = require('maps.biter_battles_v2.ai_targets')
local tables = require('maps.biter_battles_v2.tables')
local session = require('utils.datastore.session_data')
local biter_texture = require('maps.biter_battles_v2.precomputed.biter_texture')
local river = require('maps.biter_battles_v2.precomputed.river')

local bb_config_bitera_area_distance = bb_config.bitera_area_distance
local bb_config_biter_area_slope = bb_config.biter_area_slope
local biter_raffle_roll = BiterRaffle.roll
local spawn_ore = tables.spawn_ore
local table_insert = table.insert
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt

local get_noise = multi_octave_noise.get
local get_lower_bounded_noise = multi_octave_noise.get_lower_bounded
local simplex_noise = require('utils.simplex_noise').d2

local biter_area_border_noise = noise.biter_area_border
local biter_area_border_noise_amp_sum = 0
for _, octave in pairs(biter_area_border_noise) do
    biter_area_border_noise_amp_sum = biter_area_border_noise_amp_sum + octave.amp
end

local mixed_ore_noise = noise.mixed_ore
local mixed_ore_noise_amp_sum = 1.0 -- normalized

local spawn_wall_noise = noise.spawn_wall
local spawn_wall_2_noise = noise.spawn_wall_2

local biter_texture_width = biter_texture.width
local biter_texture_height = biter_texture.height
local biter_texture_grid = biter_texture.grid
local biter_texture_map = biter_texture.map

local river_offset = river.offset
local river_size = river.size

-- pre-map
for x = 1, biter_texture_width do
    for y = 1, biter_texture_height do
        biter_texture_grid[x][y] = biter_texture_map[biter_texture_grid[x][y]]
    end
end

-- avoid allocations to improve performance and maybe reduce gc lag
local preallocated_out_of_map_tiles = {}
local preallocated_tiles = {}
for i = 1, 32 * 32 do
    preallocated_out_of_map_tiles[i] = { name = 'out-of-map', position = { 0, 0 } }
    preallocated_tiles[i] = { name = '', position = { 0, 0 } }
end
local next_preallocated_tile = 1

-- max value 64
local river_circle_size = 39

local river_width_half = math_floor(bb_config.border_river_width * 0.5)

-- max value 32
local spawn_island_size = 9

local ores = {
    'iron-ore',
    'copper-ore',
    'iron-ore',
    'stone',
    'copper-ore',
    'iron-ore',
    'copper-ore',
    'iron-ore',
    'coal',
    'iron-ore',
    'copper-ore',
    'iron-ore',
    'stone',
    'copper-ore',
    'coal',
}
-- mixed_ore_multiplier order is based on the ores variable
local mixed_ore_multiplier = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }
local rocks = { 'huge-rock', 'big-rock', 'big-rock', 'big-rock', 'big-sand-rock' }

-- 32 * 32 buffers
local chunk_buffer = {}
local chunk_buffer2 = {}

local chunk_tile_vectors = {}
for x = 0, 31, 1 do
    for y = 0, 31, 1 do
        chunk_tile_vectors[#chunk_tile_vectors + 1] = { x, y }
    end
end
local size_of_chunk_tile_vectors = #chunk_tile_vectors

local loading_chunk_vectors = {}
for _, v in pairs(chunk_tile_vectors) do
    if v[1] == 0 or v[1] == 31 or v[2] == 0 or v[2] == 31 then
        table_insert(loading_chunk_vectors, v)
    end
end

local wrecks = {
    'crash-site-spaceship-wreck-big-1',
    'crash-site-spaceship-wreck-big-2',
    'crash-site-spaceship-wreck-medium-1',
    'crash-site-spaceship-wreck-medium-2',
    'crash-site-spaceship-wreck-medium-3',
}
local size_of_wrecks = #wrecks
local valid_wrecks = {}
for _, wreck in pairs(wrecks) do
    valid_wrecks[wreck] = true
end
local loot_blacklist = {
    ['automation-science-pack'] = true,
    ['logistic-science-pack'] = true,
    ['military-science-pack'] = true,
    ['chemical-science-pack'] = true,
    ['production-science-pack'] = true,
    ['utility-science-pack'] = true,
    ['space-science-pack'] = true,
    ['loader'] = true,
    ['fast-loader'] = true,
    ['express-loader'] = true,
}

local function shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = storage.random_generator(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

function Public.adjust_map_gen_settings(map_gen_settings)
    map_gen_settings.starting_area = 2.5
    map_gen_settings.property_expression_names = {
        ['segmentation_multiplier'] = 0.1,
    }
    map_gen_settings.cliff_settings = { cliff_elevation_interval = 0, cliff_elevation_0 = 0 }
    map_gen_settings.autoplace_controls = {
        ['coal'] = { frequency = 6.5, size = 0.34, richness = 0.24 },
        ['water'] = {
            frequency = 10,
            size = 0.3,
            richness = 0.1,
        },
        ['stone'] = { frequency = 6, size = 0.385, richness = 0.25 },
        ['copper-ore'] = { frequency = 8.05, size = 0.352, richness = 0.35 },
        ['iron-ore'] = { frequency = 8.5, size = 0.8, richness = 0.23 },
        ['uranium-ore'] = { frequency = 2.2, size = 1, richness = 1 },
        ['crude-oil'] = { frequency = 8, size = 1.4, richness = 0.45 },
        ['trees'] = {
            frequency = 0.65,
            size = 0.04,
            richness = 0.002,
        },
        ['enemy-base'] = { frequency = 0, size = 0, richness = 0 },
    }
    mixed_ore_map_special.adjust_map_gen_settings(map_gen_settings)
end

---@enum area_intersection
area_intersection = {
    none = 1,
    partial = 2,
    full = 3,
}

---Analyzes partiality of intersection of a north chunk and the biter area
---@param chunk_pos {x: int, y: int} north chunk position (not tile position)
---@return area_intersection
local function chunk_biter_area_intersection(chunk_pos)
    local left_top_x = chunk_pos.x * 32
    local right_top_x = left_top_x + 32 - 1

    local bitera_area_distance = bb_config.bitera_area_distance * -1
    local min_slope = bitera_area_distance - (math_abs(left_top_x) * bb_config.biter_area_slope)
    local max_slope = bitera_area_distance - (math_abs(right_top_x) * bb_config.biter_area_slope)
    if min_slope > max_slope then
        min_slope, max_slope = max_slope, min_slope
    end
    local top = chunk_pos.y * 32
    local bottom = top + 32 - 1
    if top - 70 > max_slope then
        return area_intersection.none
    elseif bottom + 70 < min_slope then
        return area_intersection.full
    else
        return area_intersection.partial
    end
end

---@enum chunk_type
chunk_type = {
    river = 1,
    ordinary = 2,
    biter_area_border = 3,
    biter_area = 4,
}

---@param chunk_pos {x: int, y: int} north chunk position (not tile position)
---@return chunk_type
function chunk_type_at(chunk_pos)
    if chunk_pos.y == -1 or (chunk_pos.y == -2 and (chunk_pos.x == -1 or chunk_pos.x == 0)) then
        return chunk_type.river
    end

    local biterland_intersection = chunk_biter_area_intersection(chunk_pos)
    if biterland_intersection == area_intersection.none then
        return chunk_type.ordinary
    elseif biterland_intersection == area_intersection.partial then
        return chunk_type.biter_area_border
    else
        return chunk_type.biter_area
    end
end

local function create_mirrored_tile_chain(surface, tile, count, straightness)
    if not surface then
        return
    end
    if not tile then
        return
    end
    if not count then
        return
    end

    local position = { x = tile.position.x, y = tile.position.y }

    local modifiers = {
        { x = 0, y = -1 },
        { x = -1, y = 0 },
        { x = 1, y = 0 },
        { x = 0, y = 1 },
        { x = -1, y = 1 },
        { x = 1, y = -1 },
        { x = 1, y = 1 },
        { x = -1, y = -1 },
    }
    modifiers = shuffle(modifiers)

    for _ = 1, count, 1 do
        local tile_placed = false

        if storage.random_generator(0, 100) > straightness then
            modifiers = shuffle(modifiers)
        end
        for b = 1, 4, 1 do
            local pos = { x = position.x + modifiers[b].x, y = position.y + modifiers[b].y }
            if surface.get_tile(pos).name ~= tile.name then
                surface.set_tiles({ { name = 'dirt-1', position = pos } }, true)
                surface.set_tiles({ { name = tile.name, position = pos } }, true)
                --surface.set_tiles({{name = "landfill", position = {pos.x * -1, (pos.y * -1) - 1}}}, true)
                --surface.set_tiles({{name = tile.name, position = {pos.x * -1, (pos.y * -1) - 1}}}, true)
                position = { x = pos.x, y = pos.y }
                tile_placed = true
                break
            end
        end

        if not tile_placed then
            position = { x = position.x + modifiers[1].x, y = position.y + modifiers[1].y }
        end
    end
end

local function draw_noise_ore_patch(position, name, surface, radius, richness)
    if not position then
        return
    end
    if not name then
        return
    end
    if not surface then
        return
    end
    if not radius then
        return
    end
    if not richness then
        return
    end
    local seed = game.surfaces[storage.bb_surface_name].map_gen_settings.seed
    local noise_seed_add = 25000
    local richness_part = richness / radius
    for y = radius * -3, radius * 3, 1 do
        for x = radius * -3, radius * 3, 1 do
            local pos = { x = x + position.x + 0.5, y = y + position.y + 0.5 }
            local noise_1 = simplex_noise(pos.x * 0.0125, pos.y * 0.0125, seed)
            local noise_2 = simplex_noise(pos.x * 0.1, pos.y * 0.1, seed + 25000)
            local noise = noise_1 + noise_2 * 0.12
            local distance_to_center = math_sqrt(x ^ 2 + y ^ 2)
            local a = richness - richness_part * distance_to_center
            if distance_to_center < radius - math_abs(noise * radius * 0.85) and a > 1 then
                if surface.can_place_entity({ name = name, position = pos, amount = a }) then
                    surface.create_entity({ name = name, position = pos, amount = a })
                    for _, e in
                        pairs(surface.find_entities_filtered({
                            position = pos,
                            name = { 'wooden-chest', 'stone-wall', 'gun-turret' },
                        }))
                    do
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
    if math_abs(pos.x) > spawn_island_size then
        return false
    end
    if math_abs(pos.y) > spawn_island_size then
        return false
    end
    if tile_distance_to_center(pos) > spawn_island_size then
        return false
    end
    return true
end

local function is_horizontal_border_river(pos, seed)
    if tile_distance_to_center(pos) < river_circle_size then
        return true
    end

    -- Offset contains coefficient in a range between [0,4]. Select it
    -- from pre-computed table. Position X coordinate is used to determinate
    -- which offset is selected.
    local offset = river.offset[(pos.x + seed) % river.size]
    local y = -(pos.y + offset)
    return (y <= river_width_half)
end

local DEFAULT_HIDDEN_TILE = 'dirt-3'
local function generate_starting_area(pos, surface)
    local spawn_wall_radius = 116
    local noise_multiplier = 15
    local min_noise = -noise_multiplier * 1.25

    local seed = game.surfaces[storage.bb_surface_name].map_gen_settings.seed
    if is_horizontal_border_river(pos, seed) then
        return
    end

    local distance_to_center = tile_distance_to_center(pos)
    -- Avoid calculating noise, see comment below
    if (distance_to_center + min_noise - spawn_wall_radius) > 4.5 then
        return
    end

    local noise = get_noise(spawn_wall_noise, pos.x, pos.y, seed, 25000) * noise_multiplier
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
        if storage.random_generator(1, 100) > 23 then
            for _, tree in
                pairs(surface.find_entities_filtered({
                    type = 'tree',
                    area = { { pos.x, pos.y }, { pos.x + 1, pos.y + 1 } },
                }))
            do
                tree.destroy()
            end
        end
    end

    if distance_from_spawn_wall < -10 then
        surface.set_tiles({ { name = 'refined-concrete', position = pos } }, true)
        surface.set_hidden_tile(pos, DEFAULT_HIDDEN_TILE)
        return
    end

    if
        surface.can_place_entity({ name = 'wooden-chest', position = pos })
        and (
            surface.can_place_entity({ name = 'coal', position = pos })
            or storage.active_special_games['mixed_ore_map']
        )
    then
        local noise_2 = get_noise(spawn_wall_2_noise, pos.x, pos.y, seed, 0)
        if noise_2 < 0.40 then
            if noise_2 > -0.40 then
                if distance_from_spawn_wall > -1.75 and distance_from_spawn_wall < 0 then
                    local e = surface.create_entity({ name = 'stone-wall', position = pos, force = 'north' })
                end
            else
                if distance_from_spawn_wall > -1.95 and distance_from_spawn_wall < 0 then
                    local e = surface.create_entity({ name = 'stone-wall', position = pos, force = 'north' })
                elseif distance_from_spawn_wall > 0 and distance_from_spawn_wall < 4.5 then
                    local name = 'wooden-chest'
                    local r_max = math_floor(math.abs(distance_from_spawn_wall)) + 2
                    if storage.random_generator(1, 3) == 1 then
                        name = name .. '-remnants'
                    end
                    if storage.random_generator(1, r_max) == 1 then
                        local e = surface.create_entity({ name = name, position = pos, force = 'north' })
                    end
                elseif distance_from_spawn_wall > -6 and distance_from_spawn_wall < -3 then
                    if storage.random_generator(1, 16) == 1 then
                        if surface.can_place_entity({ name = 'gun-turret', position = pos }) then
                            local e = surface.create_entity({ name = 'gun-turret', position = pos, force = 'north' })
                            e.insert({ name = 'firearm-magazine', count = storage.random_generator(2, 16) })
                            AiTargets.start_tracking(e)
                        end
                    else
                        if storage.random_generator(1, 24) == 1 then
                            if surface.can_place_entity({ name = 'gun-turret', position = pos }) then
                                surface.create_entity({
                                    name = 'gun-turret-remnants',
                                    position = pos,
                                    force = 'neutral',
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

---@param chunk_pos {x: number, y: number}
local function is_outside_spawn(chunk_pos)
    return chunk_pos.x < -5 or chunk_pos.x >= 5 or chunk_pos.y < -5
end

local ore_template = { name = 'iron-ore', position = { 0, 0 }, amount = 1 }

---@param can_place_entity fun(LuaSurface.can_place_entity_param): boolean
---@param create_entity fun(LuaSurface.create_entity_param): LuaEntity?
---@param seed uint
---@param x number
---@param y number
---@param rng LuaRandomGenerator
local function generate_ordinary_tile(can_place_entity, create_entity, seed, x, y, rng)
    ore_template.position[1], ore_template.position[2] = x, y
    ore_template.name = 'iron-ore'
    ore_template.amount = 1
    if can_place_entity(ore_template) then
        local noise = get_lower_bounded_noise(mixed_ore_noise, mixed_ore_noise_amp_sum, x, y, seed, 10000, 0.6)
        if noise then
            local i = math_floor(noise * 25 + math_abs(x) * 0.05) % 15 + 1
            local amount = (rng(800, 1000) + math_sqrt(x ^ 2 + y ^ 2) * 3) * mixed_ore_multiplier[i]
            ore_template.name = ores[i]
            ore_template.amount = amount
            create_entity(ore_template)
        end
    end
end

local impactful_mixed_ore_noise = { mixed_ore_noise[1] }

local function chunk_noise_hint(seed, chunk_pos)
    local mid_x, mid_y = chunk_pos.x * 32 + 16, chunk_pos.y * 32 + 16
    return get_noise(impactful_mixed_ore_noise, mid_x, mid_y, seed, 10000)
end

-- calculate_chunk_has_ore_hint()
-- local chunk_has_ore_hint = -0.081660016785248 -- way too conservative
local chunk_has_ore_hint = 0.16

---@param surface LuaSurface
---@param chunk_pos {x: number, y: number}
---@return fun(x: number, y: number, rng: LuaRandomGenerator)?
local function get_tile_generator(surface, chunk_pos)
    local special_gen = mixed_ore_map_special.get_tile_generator(surface, chunk_pos)
    local suppress_tile_gen = special_gen == false
    if suppress_tile_gen then
        return nil
    elseif special_gen ~= nil then
        return special_gen ---@type fun(x: number, y: number, rng: LuaRandomGenerator)
    end
    if not is_outside_spawn(chunk_pos) then
        return nil
    end
    local seed = surface.map_gen_settings.seed
    if chunk_noise_hint(seed, chunk_pos) < chunk_has_ore_hint then
        return nil
    end
    local can_place_entity = surface.can_place_entity
    local create_entity = surface.create_entity
    return function(x, y, rng)
        generate_ordinary_tile(can_place_entity, create_entity, seed, x, y, rng)
    end
end

--- Calculates tile y coordinate which has top border closest to the intersection point of the middle
---  of a vertical column and the top (negative) part of a circle at the origin, ties prefer tile below (towards positive)
---@param column_x number tile column x coordinate
---@param circle_radius number
---@return number? tile_y # intersection point, if any
local function tile_near_column_with_origin_circle_intersection(column_x, circle_radius)
    local tile_center = 0.5
    local circle_y_intersection_sq = circle_radius ^ 2 - (column_x + tile_center) ^ 2
    if circle_y_intersection_sq < 0 then
        return nil
    end
    local circle_y_intersection = -math_sqrt(circle_y_intersection_sq)
    -- round, tie breaker ceil
    circle_y_intersection = math_floor(circle_y_intersection + 0.5)
    return circle_y_intersection
end

---@param surface LuaSurface
---@param chunk_pos {x: number, y: number}
---@param rng LuaRandomGenerator
local function generate_river(surface, chunk_pos, rng)
    local fish_template = { name = 'fish', position = { 0.5, 0.5 } }

    local chunk_pos_x = chunk_pos.x
    local chunk_pos_y = chunk_pos.y
    local left_top_x = chunk_pos.x * 32
    local left_top_y = chunk_pos.y * 32
    local seed = surface.map_gen_settings.seed
    local in_spawn_river_circle_bbox = chunk_pos.x >= -2 and chunk_pos.x < 2
    local create_entity = surface.create_entity
    local tile_gen = get_tile_generator(surface, chunk_pos)

    local tiles = {}
    local i = 1

    -- fill vertically strip by strip, dividing into river/ordinary/spec_island parts
    for x = left_top_x, left_top_x + 32 - 1 do
        -- Offset contains coefficient in a range between [0, 4]. Select it
        -- from pre-computed table. Position X coordinate is used to determinate
        -- which offset is selected.
        local offset = river_offset[(x + seed) % river_size]
        local river_border_start_y = -river_width_half - offset

        if in_spawn_river_circle_bbox then
            local circle_y_intersection = tile_near_column_with_origin_circle_intersection(x, river_circle_size)
            if circle_y_intersection then
                river_border_start_y = math_min(river_border_start_y, circle_y_intersection)
                river_border_start_y = math_max(river_border_start_y, left_top_y)
            end
        end

        local river_border_end_y = left_top_y + 32 - 1
        local is_spec_island_chunk = (chunk_pos_x == -1 or chunk_pos_x == 0) and chunk_pos_y == -1
        if is_spec_island_chunk then
            local circle_y_intersection = tile_near_column_with_origin_circle_intersection(x, spawn_island_size)
            if circle_y_intersection then
                local spec_island_start = math_min(river_border_end_y, circle_y_intersection)
                river_border_end_y = spec_island_start - 1
            end
        end

        if tile_gen then
            for y = left_top_y, river_border_start_y - 1 do
                tile_gen(x, y, rng)
            end
        end

        for y = river_border_start_y, river_border_end_y do
            local tile = preallocated_tiles[next_preallocated_tile]
            next_preallocated_tile = (next_preallocated_tile % (32 * 32)) + 1

            tile.name = 'deepwater'
            tile.position[1], tile.position[2] = x, y
            tiles[i] = tile
            i = i + 1
            if rng(1, 64) == 1 then
                fish_template.position[1], fish_template.position[2] = x + 0.5, y + 0.5
                create_entity(fish_template)
            end
        end
    end
    surface.set_tiles(tiles)
end

local scrap_vectors = {}
for x = -8, 8, 1 do
    for y = -8, 8, 1 do
        if math_sqrt(x ^ 2 + y ^ 2) <= 8 then
            scrap_vectors[#scrap_vectors + 1] = { x, y }
        end
    end
end
local size_of_scrap_vectors = #scrap_vectors

local function populate_with_extra_worm_turrets(surface, chunk_pos, rng)
    local worm_template = { name = '', position = { 0, 0 }, force = 'north_biters' }
    local scrap_template = { name = '', position = { 0, 0 }, force = 'neutral' }

    local left_top_x = chunk_pos.x * 32
    local left_top_y = chunk_pos.y * 32

    local chunk_distance_to_center = math_sqrt(left_top_x ^ 2 + left_top_y ^ 2)
    if bb_config.bitera_area_distance > chunk_distance_to_center then
        return
    end

    local amount = (chunk_distance_to_center - bb_config.bitera_area_distance) * 0.0005
    if amount < 0 then
        return
    end
    local floor_amount = math_floor(amount)
    local r = math.round(amount - floor_amount, 3) * 1000
    if rng(0, 999) <= r then
        floor_amount = floor_amount + 1
    end

    if floor_amount > 64 then
        floor_amount = 64
    end

    local find_non_colliding_position = surface.find_non_colliding_position
    local create_entity = surface.create_entity
    for _ = 1, floor_amount, 1 do
        local worm_turret_name = biter_raffle_roll('worm', chunk_distance_to_center * 0.00015)
        local v = chunk_tile_vectors[rng(1, size_of_chunk_tile_vectors)]
        local position = find_non_colliding_position(worm_turret_name, { left_top_x + v[1], left_top_y + v[2] }, 8, 1)
        if position then
            worm_template.name = worm_turret_name
            worm_template.position = position
            local worm = create_entity(worm_template)

            -- add some scrap
            for _ = 1, rng(0, 4), 1 do
                local vector = scrap_vectors[rng(1, size_of_scrap_vectors)]
                local position = { worm.position.x + vector[1], worm.position.y + vector[2] }
                local name = wrecks[rng(1, size_of_wrecks)]
                position = find_non_colliding_position(name, position, 16, 1)
                if position then
                    scrap_template.name = name
                    scrap_template.position = position
                    local e = create_entity(scrap_template)
                end
            end
        end
    end
end

---@param x number
---@param y number
---@param seed number
---@param a number biter area slope start
---@return boolean
local function biter_area_noise_test(x, y, seed, a)
    -- original test
    -- return y + (get_noise(biter_area_border_noise, x, y, seed, 0) * 64) <= a
    local noise =
        get_lower_bounded_noise(biter_area_border_noise, biter_area_border_noise_amp_sum, x, y, seed, 0, (a - y) / 64)
    return noise == nil
end

---@param seed uint
---@param x number
---@param y number
---@return boolean
local function is_biter_area(seed, x, y)
    local bitera_area_distance = bb_config_bitera_area_distance * -1
    local a = bitera_area_distance - (math_abs(x) * bb_config_biter_area_slope)
    if y - 70 > a then
        return false
    end
    if y + 70 < a then
        return true
    end
    return biter_area_noise_test(x, y, seed, a)
end

local function populate_biter_area(surface, chunk_pos, rng, is_biter_area_chunk)
    local spitter_spawner_template = { name = 'spitter-spawner', position = { 0, 0 }, force = 'north_biters' }
    local biter_spawner_template = { name = 'biter-spawner', position = { 0, 0 }, force = 'north_biters' }
    local worm_turret_template = { name = '', position = { 0, 0 }, force = 'north_biters' }

    local left_top_x = chunk_pos.x * 32
    local left_top_y = chunk_pos.y * 32
    local seed = surface.map_gen_settings.seed
    local unit_spawners = storage.unit_spawners

    local can_place_entity = surface.can_place_entity
    local create_entity = surface.create_entity

    for _ = 1, 4 do
        local v = chunk_tile_vectors[rng(1, size_of_chunk_tile_vectors)]
        local x, y = left_top_x + v[1], left_top_y + v[2]
        spitter_spawner_template.position[1], spitter_spawner_template.position[2] = x, y
        if (is_biter_area_chunk or is_biter_area(seed, x, y)) and can_place_entity(spitter_spawner_template) then
            local e
            if rng(1, 4) == 1 then
                e = create_entity(spitter_spawner_template)
            else
                biter_spawner_template.position[1], biter_spawner_template.position[2] = x, y
                e = create_entity(biter_spawner_template)
            end
            table_insert(unit_spawners[e.force.name], e)
        end
    end

    local e = (math_abs(left_top_y) - bb_config_bitera_area_distance) * 0.0015
    for _ = 1, rng(5, 10), 1 do
        local v = chunk_tile_vectors[rng(1, size_of_chunk_tile_vectors)]
        local x, y = left_top_x + v[1], left_top_y + v[2]
        worm_turret_template.name = biter_raffle_roll('worm', e)
        worm_turret_template.position[1], worm_turret_template.position[2] = x, y
        if (is_biter_area_chunk or is_biter_area(seed, x, y)) and can_place_entity(worm_turret_template) then
            create_entity(worm_turret_template)
        end
    end
end

---@param seed uint
---@param x number
---@param y number
---@return any out_of_map_tile, any tile # returns params for `set_tile`
local function get_biter_area_tile(seed, x, y)
    -- Maps the relative x/y position into biter_texture with pre-computed 2D grid.
    -- The value from the grid is then mapped into tile name.
    -- + 1, because lua has 1-based indices
    local grid_p_x = ((x + seed) % biter_texture_width) + 1
    local grid_p_y = ((y + seed) % biter_texture_height) + 1
    local name = biter_texture_grid[grid_p_x][grid_p_y]

    local out_of_map = preallocated_out_of_map_tiles[next_preallocated_tile]
    local tile = preallocated_tiles[next_preallocated_tile]
    next_preallocated_tile = (next_preallocated_tile % (32 * 32)) + 1

    out_of_map.position[1], out_of_map.position[2] = x, y
    tile.position[1], tile.position[2] = x, y
    tile.name = name
    return out_of_map, tile
end

---@param surface LuaSurface
---@param chunk_pos {x: number, y: number}
---@param rng LuaRandomGenerator
local function generate_biter_area_border(surface, chunk_pos, rng)
    local bitera_area_distance = bb_config.bitera_area_distance * -1
    local left_top_x = chunk_pos.x * 32
    local left_top_y = chunk_pos.y * 32
    local seed = surface.map_gen_settings.seed
    local tile_gen = get_tile_generator(surface, chunk_pos)

    local out_of_map = {}
    local tiles = {}
    local i = 1

    -- fill vertically strip by strip, dividing into biter_area/transitional/ordinary parts
    for x = left_top_x, left_top_x + 32 - 1 do
        local a = bitera_area_distance - math_abs(x) * bb_config_biter_area_slope

        local transitional_area_start = math_ceil(a - 70)
        local transitional_area_end = math_floor(a + 70)

        local biter_area_end = math_min(left_top_y + 32 - 1, transitional_area_start - 1)
        local ordinary_start = math_max(transitional_area_end + 1, left_top_y)
        transitional_area_start = math_max(transitional_area_start, left_top_y)
        transitional_area_end = math_min(left_top_y + 32 - 1, transitional_area_end)

        for y = left_top_y, biter_area_end do
            out_of_map[i], tiles[i] = get_biter_area_tile(seed, x, y)
            i = i + 1
        end

        for y = transitional_area_start, transitional_area_end do
            local is_biter_area = biter_area_noise_test(x, y, seed, a)
            if is_biter_area then
                out_of_map[i], tiles[i] = get_biter_area_tile(seed, x, y)
                i = i + 1
            elseif tile_gen then
                tile_gen(x, y, rng)
            end
        end

        if tile_gen then
            for y = ordinary_start, left_top_y + 32 - 1 do
                tile_gen(x, y, rng)
            end
        end
    end

    surface.set_tiles(out_of_map, false)
    surface.set_tiles(tiles, true)

    populate_biter_area(surface, chunk_pos, rng, false)
end

---@param surface LuaSurface
---@param chunk_pos {x: number, y: number}
---@param rng LuaRandomGenerator
local function generate_biter_area(surface, chunk_pos, rng)
    local left_top_x = chunk_pos.x * 32
    local left_top_y = chunk_pos.y * 32
    local seed = surface.map_gen_settings.seed

    local out_of_map = chunk_buffer
    local tiles = chunk_buffer2
    local i = 1

    for y = left_top_y, left_top_y + 32 - 1 do
        for x = left_top_x, left_top_x + 32 - 1 do
            out_of_map[i], tiles[i] = get_biter_area_tile(seed, x, y)
            i = i + 1
        end
    end

    surface.set_tiles(out_of_map, false)
    surface.set_tiles(tiles, true)

    populate_biter_area(surface, chunk_pos, rng, true)
end

---@param surface LuaSurface
---@param chunk_pos {x: number, y: number}
---@param rng LuaRandomGenerator
local function generate_ordinary(surface, chunk_pos, rng)
    local tile_gen = get_tile_generator(surface, chunk_pos)
    if not tile_gen then
        return
    end

    local left_top_x = chunk_pos.x * 32
    local left_top_y = chunk_pos.y * 32

    for y = left_top_y, left_top_y + 32 - 1 do
        for x = left_top_x, left_top_x + 32 - 1 do
            tile_gen(x, y, rng)
        end
    end
end

-- this will enable collection of chunk generation profiling statistics, chart huge area around the map origin
-- and enable `chunk-profiling-stats` command to retrieve the statistics
local ENABLE_CHUNK_GEN_PROFILING = false

local chunk_profiling = nil
if ENABLE_CHUNK_GEN_PROFILING then
    local function enabled_mixed_ore_map_special(type, size)
        storage.active_special_games['mixed_ore_map'] = true
        if not size then
            if type == 1 then -- mixed ores
                size = 9
            elseif type == 2 then -- checkerboard, 3 - vertical lines
                size = 5
            elseif type == 4 then -- mixed patches
                size = 4
            elseif type == 5 then -- dots
                size = 7
            end
        end
        storage.special_games_variables['mixed_ore_map'] = { type = type, size = size }
    end

    -- you can uncomment this to test mixed ore map special performance
    -- enabled_mixed_ore_map_special(4, 4)

    local profile_stats = require('utils.profiler_stats')
    local event = require('utils.event')
    local token = require('utils.token')

    chunk_profiling = {
        per_chunk_type = {},
        all = profile_stats.new(),
    }

    for _, i in pairs(chunk_type) do
        chunk_profiling.per_chunk_type[i] = profile_stats.new()
    end

    local function chart_profiling_area(surface)
        game.forces['spectator'].chart(surface, { { x = -1024, y = -1024 }, { x = 1023, y = 1023 } })
    end

    local on_after_init -- pass self reference to the callback below
    on_after_init = token.register(function()
        local bb_surface = game.get_surface(storage.bb_surface_name)
        chart_profiling_area(bb_surface)
        event.remove_removable(defines.events.on_tick, on_after_init)
    end)
    event.add_removable(defines.events.on_tick, on_after_init)

    -- this won't be called if you create a surface during `on_init`
    event.add(defines.events.on_surface_created, function(event)
        local bb_surface = game.get_surface(storage.bb_surface_name)
        if not bb_surface or event.surface_index ~= bb_surface.index then
            return
        end
        chart_profiling_area(bb_surface)
    end)

    -- server and client output won't match
    commands.add_command('chunk-profiling-stats', 'Display and log statistics of chunk generation time', function(cmd)
        local caller = cmd.player_index and game.get_player(cmd.player_index)

        if caller and not caller.admin then
            caller.print('Only admin may run this command')
            return
        end

        local stats = 'Chunk profiling statistics\nall: ' .. chunk_profiling.all.summarize_records()
        for chunk_name, i in pairs(chunk_type) do
            stats = stats .. '\n' .. chunk_name .. ': ' .. chunk_profiling.per_chunk_type[i].summarize_records()
        end
        log(stats)
        if caller then
            caller.print(stats)
        end
    end)
end

function Public.generate(event)
    local profiler = chunk_profiling and helpers.create_profiler(false)

    local surface = event.surface
    local chunk_pos = event.position
    local rng = storage.random_generator

    local chunk_variant = chunk_type_at(chunk_pos)
    if chunk_variant == chunk_type.river then
        generate_river(surface, chunk_pos, rng)
    elseif chunk_variant == chunk_type.ordinary then
        generate_ordinary(surface, chunk_pos, rng)
    elseif chunk_variant == chunk_type.biter_area_border then
        generate_biter_area_border(surface, chunk_pos, rng)
    elseif chunk_variant == chunk_type.biter_area then
        generate_biter_area(surface, chunk_pos, rng)
    end

    populate_with_extra_worm_turrets(surface, chunk_pos, rng)

    if profiler then
        profiler.stop()
        chunk_profiling.all.add_record(profiler)
        chunk_profiling.per_chunk_type[chunk_variant].add_record(profiler)
    end
end

local function draw_spawn_island(surface)
    local tiles = {}
    for x = math_floor(spawn_island_size) * -1, -1, 1 do
        for y = math_floor(spawn_island_size) * -1, -1, 1 do
            local pos = { x = x, y = y }
            if is_within_spawn_island(pos) then
                local distance_to_center = tile_distance_to_center(pos)
                local tile_name = 'refined-concrete'
                if distance_to_center < 6.3 then
                    tile_name = 'sand-1'
                end

                if storage.bb_settings['new_year_island'] then
                    tile_name = 'blue-refined-concrete'
                    if distance_to_center < 6.3 then
                        tile_name = 'sand-1'
                    end
                    if distance_to_center < 4.9 then
                        tile_name = 'lab-white'
                    end
                end

                table_insert(tiles, { name = tile_name, position = pos })
            end
        end
    end

    for i = 1, #tiles, 1 do
        table_insert(tiles, { name = tiles[i].name, position = { tiles[i].position.x * -1 - 1, tiles[i].position.y } })
    end

    surface.set_tiles(tiles, true)

    local island_area = { { -spawn_island_size, -spawn_island_size }, { spawn_island_size, 0 } }
    surface.destroy_decoratives({ area = island_area })
    for _, entity in pairs(surface.find_entities(island_area)) do
        entity.destroy()
    end
end

local function draw_spawn_area(surface)
    local chunk_r = 4
    local r = chunk_r * 32

    for x = r * -1, r, 1 do
        for y = r * -1, -4, 1 do
            generate_starting_area({ x = x, y = y }, surface)
        end
    end

    surface.destroy_decoratives({})
    surface.regenerate_decorative()
end

function Public.draw_water_for_river_ends(surface, chunk_pos)
    local left_top_x = chunk_pos.x * 32
    for x = 0, 31, 1 do
        local pos = { x = left_top_x + x, y = 1 }
        surface.set_tiles({ { name = 'deepwater', position = pos } })
    end
end

local function draw_grid_ore_patch(count, grid, name, surface, size, density)
    -- Takes a random left_top coordinate from grid, removes it and draws
    -- ore patch on top of it. Grid is held by reference, so this function
    -- is reentrant.
    for i = 1, count, 1 do
        local idx = storage.random_generator(1, #grid)
        local pos = grid[idx]
        table.remove(grid, idx)

        -- The draw_noise_ore_patch expects position with x and y keys.
        pos = { x = pos[1], y = pos[2] }
        draw_noise_ore_patch(pos, name, surface, size, density)
    end
end

local function _clear_resources(surface, area)
    local resources = surface.find_entities_filtered({
        area = area,
        type = 'resource',
    })

    local i = 0
    for _, res in pairs(resources) do
        if res.valid then
            res.destroy()
            i = i + 1
        end
    end

    return i
end

local function clear_ore_in_main(surface)
    local area = {
        left_top = { -150, -150 },
        right_bottom = { 150, 0 },
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
        log('Limit reached, some ores might be truncated in spawn area')
        log('If this is a custom build, remove a call to clear_ore_in_main')
        log('If this in a standard value, limit could be tweaked')
    end
end

local function generate_spawn_ore(surface)
    -- This array holds indicies of chunks onto which we desire to
    -- generate ore patches. It is visually representing north spawn
    -- area. One element was removed on purpose - we don't want to
    -- draw ore in the lake which overlaps with chunk [0,-1]. All ores
    -- will be mirrored to south.
    local grid = {
        { -2, -3 },
        { -1, -3 },
        { 0, -3 },
        { 1, -3 },
        { 2, -3 },
        { -2, -2 },
        { -1, -2 },
        { 0, -2 },
        { 1, -2 },
        { 2, -2 },
        { -2, -1 },
        { -1, -1 },
        { 1, -1 },
        { 2, -1 },
    }

    -- Calculate left_top position of a chunk. It will be used as origin
    -- for ore drawing. Reassigns new coordinates to the grid.
    for i, _ in ipairs(grid) do
        grid[i][1] = grid[i][1] * 32 + storage.random_generator(-12, 12)
        grid[i][2] = grid[i][2] * 32 + storage.random_generator(-24, -1)
    end

    for name, props in pairs(spawn_ore) do
        draw_grid_ore_patch(props.big_patches, grid, name, surface, props.size, props.density)
        draw_grid_ore_patch(props.small_patches, grid, name, surface, props.size / 2, props.density)
    end
end

local function generate_additional_rocks(surface)
    local r = 130
    if surface.count_entities_filtered({ type = 'simple-entity', area = { { r * -1, r * -1 }, { r, 0 } } }) >= 12 then
        return
    end
    local position = { x = -96 + storage.random_generator(0, 192), y = -40 - storage.random_generator(0, 96) }
    for _ = 1, storage.random_generator(6, 10) do
        local name = rocks[storage.random_generator(1, 5)]
        local p = surface.find_non_colliding_position(name, {
            position.x + (-10 + storage.random_generator(0, 20)),
            position.y + (-10 + storage.random_generator(0, 20)),
        }, 16, 1)
        if p and p.y < -16 then
            surface.create_entity({ name = name, position = p })
        end
    end
end

local function generate_silo(surface)
    local pos = { x = -32 + storage.random_generator(0, 64), y = -72 }
    local mirror_position = { x = pos.x * -1, y = pos.y * -1 }

    for _, t in
        pairs(surface.find_tiles_filtered({
            area = { { pos.x - 6, pos.y - 6 }, { pos.x + 6, pos.y + 6 } },
            name = { 'water', 'deepwater' },
        }))
    do
        surface.set_tiles({ { name = DEFAULT_HIDDEN_TILE, position = t.position } })
    end
    for _, t in
        pairs(surface.find_tiles_filtered({
            area = {
                { mirror_position.x - 6, mirror_position.y - 6 },
                {
                    mirror_position.x + 6,
                    mirror_position.y + 6,
                },
            },
            name = { 'water', 'deepwater' },
        }))
    do
        surface.set_tiles({ { name = DEFAULT_HIDDEN_TILE, position = t.position } })
    end

    local silo = surface.create_entity({
        name = 'rocket-silo',
        position = pos,
        force = 'north',
    })
    silo.minable_flag = false
    storage.rocket_silo[silo.force.name] = silo
    AiTargets.start_tracking(silo)

    for _ = 1, 32, 1 do
        create_mirrored_tile_chain(surface, { name = 'refined-concrete', position = silo.position }, 32, 10)
    end

    for _, entity in pairs(surface.find_entities({ { pos.x - 4, pos.y - 6 }, { pos.x + 5, pos.y + 5 } })) do
        if entity.type == 'simple-entity' or entity.type == 'tree' then
            entity.destroy()
        end
    end
    local turret1 =
        surface.create_entity({ name = 'gun-turret', position = { x = pos.x, y = pos.y - 5 }, force = 'north' })
    turret1.insert({ name = 'firearm-magazine', count = 10 })
    AiTargets.start_tracking(turret1)
    local turret2 =
        surface.create_entity({ name = 'gun-turret', position = { x = pos.x + 2, y = pos.y - 5 }, force = 'north' })
    turret2.insert({ name = 'firearm-magazine', count = 10 })
    AiTargets.start_tracking(turret2)
end

function Public.generate_initial_structures(surface)
    draw_spawn_area(surface)
    if not storage.active_special_games['mixed_ore_map'] then
        clear_ore_in_main(surface)
        generate_spawn_ore(surface)
    end
    generate_additional_rocks(surface)
    generate_silo(surface)
    draw_spawn_island(surface)
end

---@param entity LuaEntity
---@param player LuaPlayer
function Public.minable_wrecks(entity, player)
    if not valid_wrecks[entity.name] then
        return
    end

    local surface = entity.surface

    local loot_worth = math_floor(math_abs(entity.position.x * 0.02)) + storage.random_generator(16, 32)
    local blacklist = LootRaffle.get_tech_blacklist(math_abs(entity.position.x * 0.0001) + 0.10)
    for k, _ in pairs(loot_blacklist) do
        blacklist[k] = true
    end
    local item_stacks = LootRaffle.roll(loot_worth, storage.random_generator(1, 3), blacklist)

    for k, stack in pairs(item_stacks) do
        local amount = stack.count
        local name = stack.name

        local inserted_count = player.insert({ name = name, count = amount })
        if inserted_count ~= amount then
            local amount_to_spill = amount - inserted_count
            surface.spill_item_stack({
                position = entity.position,
                stack = { name = name, count = amount_to_spill },
                enable_looted = true,
            })
        end

        player.create_local_flying_text({
            position = { entity.position.x, entity.position.y - 0.5 * k },
            text = '+' .. amount .. ' [img=item/' .. name .. ']',
            color = { r = 0.98, g = 0.66, b = 0.22 },
        })
    end
end

--Landfill Restriction
function Public.restrict_landfill(surface, user, tiles)
    local seed = game.surfaces[storage.bb_surface_name].map_gen_settings.seed
    for _, t in pairs(tiles) do
        local check_position = t.position
        if check_position.y > 0 then
            check_position = { x = check_position.x, y = (check_position.y * -1) - 1 }
        end
        local trusted = session.get_trusted_table()
        if is_horizontal_border_river(check_position, seed) then
            surface.set_tiles({ { name = t.old_tile.name, position = t.position } }, true)
            if user ~= nil then
                user.print('You can not landfill the river', { color = { r = 0.22, g = 0.99, b = 0.99 } })
            end
        elseif user ~= nil and not trusted[user.name] then
            surface.set_tiles({ { name = t.old_tile.name, position = t.position } }, true)
            user.print(
                'You have not grown accustomed to this technology yet.',
                { color = { r = 0.22, g = 0.99, b = 0.99 } }
            )
        end
    end
end

function Public.deny_bot_landfill(event)
    if event.item ~= nil and event.item.name == 'landfill' then
        Public.restrict_landfill(event.robot.surface, nil, event.tiles)
    end
end

--Construction Robot Restriction
local robot_build_restriction = {
    ['north'] = function(y)
        if y >= -bb_config.border_river_width / 2 then
            return true
        end
    end,
    ['south'] = function(y)
        if y <= bb_config.border_river_width / 2 then
            return true
        end
    end,
}

function Public.deny_construction_bots(event)
    if not event.entity.valid then
        return
    end
    if not robot_build_restriction[event.robot.force.name] then
        return
    end
    if not robot_build_restriction[event.robot.force.name](event.entity.position.y) then
        return
    end
    local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
    inventory.insert({ name = event.entity.name, count = 1 })
    event.robot.surface.create_entity({ name = 'explosion', position = event.entity.position })
    game.print(
        'Team ' .. event.robot.force.name .. "'s construction drone had an accident.",
        { color = { r = 200, g = 50, b = 100 } }
    )
    event.entity.destroy()
end

function Public.deny_enemy_side_ghosts(event)
    local e = event.entity
    if not e.valid then
        return
    end
    if e.type == 'entity-ghost' or e.type == 'tile-ghost' then
        local player = game.get_player(event.player_index)
        local force = player.force.name
        if not robot_build_restriction[force] then
            return
        end
        if not robot_build_restriction[force](event.entity.position.y) then
            return
        end

        -- If cursor is not cleared before removing ghost of dragged pipe it
        -- will cause segfault from infinite recursion.
        player.clear_cursor()
        local ghosts = player.surface.find_entities_filtered({
            position = e.position,
            -- Undeground pipe creates two ghost tiles, but only one entity
            -- gets corresponding event
            radius = 2,
            name = 'tile-ghost',
        })
        e.order_deconstruction(force)
        for _, g in ipairs(ghosts) do
            if g.valid then
                g.order_deconstruction(force)
            end
        end
    end
end

local function add_gifts(surface)
    -- exclude dangerous goods
    local blacklist = LootRaffle.get_tech_blacklist(0.95)
    for k, _ in pairs(loot_blacklist) do
        blacklist[k] = true
    end

    for i = 1, storage.random_generator(8, 12) do
        local loot_worth = storage.random_generator(1, 35000)
        local item_stacks = LootRaffle.roll(loot_worth, 3, blacklist)
        for k, stack in pairs(item_stacks) do
            surface.spill_item_stack({
                position = { x = storage.random_generator(-10, 10) * 0.1, y = storage.random_generator(-5, 15) * 0.1 },
                stack = { name = stack.name, count = 1 },
                enable_looted = false,
                force = nil,
                allow_belts = true,
            })
        end
    end
end

function Public.add_new_year_island_decorations(surface)
    -- To fix lab-white tiles transition, draw border snow with sprites
    local function draw_sprite_snow(params)
        rendering.draw_sprite({
            surface = surface,
            sprite = params.sprite,
            target = params.target,
            render_layer = '3',
            x_scale = params.x_scale,
            y_scale = params.y_scale,
            orientation = params.orientation or 0,
        })
    end

    -- top and bottom
    draw_sprite_snow({ sprite = 'virtual-signal/shape-horizontal', target = { 0, 5.22 }, x_scale = 4.6, y_scale = 5 })
    draw_sprite_snow({ sprite = 'virtual-signal/shape-horizontal', target = { 0, -5.22 }, x_scale = 4.6, y_scale = 5 })

    -- sides
    draw_sprite_snow({ sprite = 'virtual-signal/shape-vertical', target = { -5.25, 0 }, x_scale = 5, y_scale = 4.5 })
    draw_sprite_snow({ sprite = 'virtual-signal/shape-vertical', target = { 5.25, 0 }, x_scale = 5, y_scale = 4.5 })

    local sprite = 'virtual-signal/shape-diagonal'
    local scale = 5.75
    -- bottom-right
    draw_sprite_snow({ sprite = sprite, target = { 3.48, 3.48 }, x_scale = scale, y_scale = scale })
    draw_sprite_snow({ sprite = sprite, target = { 3, 3 }, x_scale = scale, y_scale = scale })

    -- bottom-left
    draw_sprite_snow({ sprite = sprite, target = { -3.48, 3.48 }, x_scale = scale, y_scale = scale, orientation = 0.25 })
    draw_sprite_snow({ sprite = sprite, target = { -3, 3 }, x_scale = scale, y_scale = scale, orientation = 0.25 })

    -- top-right
    draw_sprite_snow({ sprite = sprite, target = { 3.48, -3.48 }, x_scale = scale, y_scale = scale, orientation = 0.25 })
    draw_sprite_snow({ sprite = sprite, target = { 3, -3 }, x_scale = scale, y_scale = scale, orientation = 0.25 })

    -- top-left
    draw_sprite_snow({ sprite = sprite, target = { -3.48, -3.48 }, x_scale = scale, y_scale = scale })
    draw_sprite_snow({ sprite = sprite, target = { -3, -3 }, x_scale = scale, y_scale = scale })

    for _ = 1, storage.random_generator(0, 4) do
        local stump = surface.create_entity({
            name = 'tree-05-stump',
            position = { x = storage.random_generator(-40, 40) * 0.1, y = storage.random_generator(-40, 40) * 0.1 },
        })
        stump.corpse_expires = false
    end

    local scorchmark = surface.create_entity({
        name = 'medium-scorchmark-tintable',
        position = { x = 0, y = 0 },
    })
    scorchmark.corpse_expires = false

    local tree = surface.create_entity({
        name = 'tree-01',
        position = { x = 0, y = 0.05 },
    })
    tree.minable_flag = false
    tree.destructible = false

    add_gifts(surface)

    local signals = {
        { name = 'rail-signal', position = { -0.5, -5.5 }, direction = defines.direction.west },
        { name = 'rail-signal', position = { 0.5, -5.5 }, direction = defines.direction.west },
        { name = 'rail-signal', position = { 2.5, -4.5 }, direction = defines.direction.northwest },
        { name = 'rail-signal', position = { 4.5, -2.5 }, direction = defines.direction.northwest },
        { name = 'rail-signal', position = { 5.5, -0.5 }, direction = defines.direction.north },
        { name = 'rail-signal', position = { 5.5, 0.5 }, direction = defines.direction.north },
        { name = 'rail-signal', position = { 4.5, 2.5 }, direction = defines.direction.northeast },
        { name = 'rail-signal', position = { 2.5, 4.5 }, direction = defines.direction.northeast },
        { name = 'rail-signal', position = { 0.5, 5.5 }, direction = defines.direction.east },
        { name = 'rail-signal', position = { -0.5, 5.5 }, direction = defines.direction.east },
        { name = 'rail-signal', position = { -2.5, 4.5 }, direction = defines.direction.southeast },
        { name = 'rail-signal', position = { -4.5, 2.5 }, direction = defines.direction.southeast },
        { name = 'rail-signal', position = { -5.5, 0.5 }, direction = defines.direction.south },
        { name = 'rail-signal', position = { -5.5, -0.5 }, direction = defines.direction.south },
        { name = 'rail-signal', position = { -4.5, -2.5 }, direction = defines.direction.southwest },
        { name = 'rail-signal', position = { -2.5, -4.5 }, direction = defines.direction.southwest },
    }
    for _, v in pairs(signals) do
        local signal = surface.create_entity(v)
        signal.minable_flag = false
        signal.destructible = false
    end

    for _ = 1, storage.random_generator(0, 6) do
        surface.create_decoratives({
            check_collision = false,
            decoratives = {
                {
                    name = 'green-asterisk-mini',
                    position = {
                        x = storage.random_generator(-40, 40) * 0.1,
                        y = storage.random_generator(-40, 40) * 0.1,
                    },
                    amount = 1,
                },
            },
        })
    end
    for _ = 1, storage.random_generator(0, 6) do
        surface.create_decoratives({
            check_collision = false,
            decoratives = {
                {
                    name = 'tiny-rock',
                    position = {
                        x = storage.random_generator(-40, 40) * 0.1,
                        y = storage.random_generator(-40, 40) * 0.1,
                    },
                    amount = 1,
                },
            },
        })
    end
end

return Public
