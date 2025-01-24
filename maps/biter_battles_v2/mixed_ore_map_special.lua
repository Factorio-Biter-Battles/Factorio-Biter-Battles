local noise = require('maps.biter_battles_v2.predefined_noise')

local get_noise = require('utils.multi_octave_noise').get
local mixed_ore_noise = noise.mixed_ore
local vertical_lines_ore_noise = noise.vertical_lines_ore

local math_floor = math.floor
local math_abs = math.abs
local math_sqrt = math.sqrt

local mixed_ores = { 'uranium-ore', 'stone', 'copper-ore', 'iron-ore', 'coal' }
local mixed_ore_weight = {}
local mixed_ore_weight_total = 0
for k, v in ipairs({ 0.3, 6, 8.05, 8.5, 6.5 }) do
    mixed_ore_weight_total = mixed_ore_weight_total + v
    mixed_ore_weight[k] = mixed_ore_weight_total
end

---@param surface LuaSurface
---@param seed uint
---@param pos {x: number, y: number}
---@param rng LuaRandomGenerator
---@param size number
local function generate_mixed_ore_tile(surface, seed, pos, rng, size)
    if surface.can_place_entity({ name = 'iron-ore', position = pos }) then
        local noise = get_noise(mixed_ore_noise, pos, seed, 10000)
        local i_raw = math_floor(noise * 25 * size + math_abs(pos.x) * 0.05) % mixed_ore_weight_total
        local i = 1
        for k, v in ipairs(mixed_ore_weight) do
            if i_raw < v then
                i = k
                break
            end
        end
        local amount = (rng(80, 100) + math_sqrt(math_abs(pos.x) ^ 1.5 + math_abs(pos.y) ^ 1.5) * 1)
        surface.create_entity({
            name = mixed_ores[i],
            position = pos,
            amount = amount,
            enable_tree_removal = false,
        })
    end
end

local dots_ores = { 'uranium-ore', 'stone', 'copper-ore', 'iron-ore', 'coal' }

---@param surface LuaSurface
---@param pos {x: number, y: number}
---@param space number
local function generate_dots_tile(surface, pos, space)
    if surface.can_place_entity({ name = 'iron-ore', position = pos }) then
        local ore
        local cx = pos.x % (space * 2)
        local cy = pos.y % (space * 2)
        if cx == 0 and cy == 0 then
            ore = dots_ores[2]
        elseif cx == 0 and cy == space then
            ore = dots_ores[3]
        elseif cx == space and cy == 0 then
            ore = dots_ores[4]
        elseif cx == space and cy == space then
            ore = dots_ores[5]
            if math.random(1, 1000) > 998 then
                ore = dots_ores[1]
            end
        end
        if ore then
            surface.create_entity({ name = ore, position = pos, amount = 100000, enable_tree_removal = false })
        end
    end
end

local checkerboard_ores = { 'uranium-ore', 'stone', 'copper-ore', 'iron-ore', 'coal' }

---@param surface LuaSurface
---@param seed uint
---@param pos {x: number, y: number}
---@param cell_size number
---@param uranium_cells {[string]: boolean} # cache
local function generate_checkerboard_tile(surface, seed, pos, cell_size, uranium_cells)
    if surface.can_place_entity({ name = 'iron-ore', position = pos }) then
        local ore
        local cell_start_pos = {
            x = pos.x - (pos.x % cell_size),
            y = pos.y - (pos.y % cell_size),
        }
        local cell_start_key = cell_start_pos.x .. '_' .. cell_start_pos.y
        if uranium_cells[cell_start_key] == nil then
            local new_seed = (cell_start_pos.x * 374761393 + cell_start_pos.y * 668265263 + seed) % 4294967296 -- numbers from internet
            local rng = game.create_random_generator(new_seed)
            uranium_cells[cell_start_key] = rng() > 0.999
        end

        if uranium_cells[cell_start_key] then
            ore = checkerboard_ores[1]
        else
            local cx = pos.x % (cell_size * 2)
            local cy = pos.y % (cell_size * 2)
            local is_row1 = cy >= 0 and cy < cell_size

            if cx >= 0 and cx < cell_size then -- col 1
                if is_row1 then -- row 1
                    ore = checkerboard_ores[3]
                else -- row 2
                    ore = checkerboard_ores[4]
                end
            else -- col 2
                if is_row1 then -- row 1
                    ore = checkerboard_ores[5]
                else -- row 2
                    ore = checkerboard_ores[2]
                end
            end
        end

        surface.create_entity({ name = ore, position = pos, amount = 15000, enable_tree_removal = false })
    end
end

local vertical_lines_ores = {
    'copper-ore',
    'stone',
    'iron-ore',
    'coal',
    'iron-ore',
    'coal',
    'iron-ore',
    'iron-ore',
    'stone',
    'iron-ore',
    'stone',
    'coal',
    'iron-ore',
    'coal',
    'stone',
    'iron-ore',
}

---@param surface LuaSurface
---@param seed uint
---@param pos {x: number, y: number}
local function generate_vertical_lines_tile(surface, seed, pos)
    if surface.can_place_entity({ name = 'iron-ore', position = pos }) then
        local noise = get_noise(vertical_lines_ore_noise, pos, seed, 10000)
        local i = math.floor(noise * 50 + math.abs(pos.x) * 0.2) % 16 + 1
        local amount = (1000 + math.sqrt(pos.x ^ 2 + pos.y ^ 2) * 3) * 10
        surface.create_entity({
            name = vertical_lines_ores[i],
            position = pos,
            amount = amount,
            enable_tree_removal = false,
        })
    end
end

local mixed_patches_ores = {
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

local mixed_patches_ore_multiplier = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }

---@param surface LuaSurface
---@param seed uint
---@param pos {x: number, y: number}
---@param rng LuaRandomGenerator
---@param size number
local function generate_mixed_patches_tile(surface, seed, pos, rng, size)
    if surface.can_place_entity({ name = 'iron-ore', position = pos }) then
        local noise = get_noise(mixed_ore_noise, pos, seed, 10000)
        if noise > 0.1 * size or noise < -0.1 * size then
            local i = math_floor(noise * 25 + math_abs(pos.x) * 0.05) % 15 + 1
            local amount = (rng(800, 1000) + math_sqrt(pos.x ^ 2 + pos.y ^ 2) * 3) * mixed_patches_ore_multiplier[i]
            surface.create_entity({ name = mixed_patches_ores[i], position = pos, amount = amount })
        end
    end
end

local Public = {}

local disabled_ore_gen = { 'stone', 'copper-ore', 'iron-ore', 'coal' }
local uranium_enabled_for = { false, false, true, true, false }

---@param map_gen_settings MapGenSettings
function Public.adjust_map_gen_settings(map_gen_settings)
    if not storage.active_special_games['mixed_ore_map'] then
        return
    end

    for _, ore in ipairs(disabled_ore_gen) do
        map_gen_settings.autoplace_controls[ore] = { frequency = 0, size = 0, richness = 0 }
    end

    local type = storage.special_games_variables['mixed_ore_map']['type']
    if not uranium_enabled_for[type] then
        map_gen_settings.autoplace_controls['uranium-ore'] = { frequency = 0, size = 0, richness = 0 }
    end
end

---@param surface LuaSurface
---@return fun(pos: {x: number, y: number}, rng: LuaRandomGenerator)?
function Public.get_tile_generator(surface)
    if not storage.active_special_games['mixed_ore_map'] then
        return nil
    end

    local seed = surface.map_gen_settings.seed
    local type = storage.special_games_variables['mixed_ore_map']['type']
    local size = storage.special_games_variables['mixed_ore_map']['size']

    if type == 1 then
        local size = 1 + size
        return function(pos, rng)
            generate_mixed_ore_tile(surface, seed, pos, rng, size)
        end
    elseif type == 2 then
        local cell_size = size
        if cell_size == 0 then
            cell_size = 1
        end
        local uranium_cells_cache = {}
        return function(pos, _)
            generate_checkerboard_tile(surface, seed, pos, cell_size, uranium_cells_cache)
        end
    elseif type == 3 then
        return function(pos, _)
            generate_vertical_lines_tile(surface, seed, pos)
        end
    elseif type == 4 then
        local size = 10 - size
        return function(pos, rng)
            generate_mixed_patches_tile(surface, seed, pos, rng, size)
        end
    elseif type == 5 then
        local space = size
        return function(pos, _)
            generate_dots_tile(surface, pos, space)
        end
    end
end

return Public
