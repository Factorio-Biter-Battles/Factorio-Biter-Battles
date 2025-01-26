local noise = require('maps.biter_battles_v2.predefined_noise')
local multi_octave_noise = require('utils.multi_octave_noise')

local get_noise = multi_octave_noise.get
local get_noise_outside_bounds = multi_octave_noise.get_outside_bounds
local mixed_ore_noise = noise.mixed_ore
local mixed_ore_noise_amp_sum = 1.0 -- normalized
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

local ore_template = { name = 'iron-ore', position = { 0, 0 }, amount = 1 }
local ore_template_no_tree_removal = { name = 'iron-ore', position = { 0, 0 }, amount = 1, enable_tree_removal = false }

---@param can_place_entity fun(LuaSurface.can_place_entity_param): boolean
---@param create_entity fun(LuaSurface.create_entity_param): LuaEntity?
---@param seed uint
---@param x number
---@param y number
---@param rng LuaRandomGenerator
---@param size number
local function generate_mixed_ore_tile(can_place_entity, create_entity, seed, x, y, rng, size)
    ore_template_no_tree_removal.position[1], ore_template_no_tree_removal.position[2] = x, y
    ore_template_no_tree_removal.name = 'iron-ore'
    ore_template_no_tree_removal.amount = 1
    if can_place_entity(ore_template_no_tree_removal) then
        local noise = get_noise(mixed_ore_noise, x, y, seed, 10000)
        local i_raw = math_floor(noise * 25 * size + math_abs(x) * 0.05) % mixed_ore_weight_total
        local i = 1
        for k, v in pairs(mixed_ore_weight) do
            if i_raw < v then
                i = k
                break
            end
        end
        local amount = (rng(80, 100) + math_sqrt(math_abs(x) ^ 1.5 + math_abs(y) ^ 1.5) * 1)
        ore_template_no_tree_removal.name = mixed_ores[i]
        ore_template_no_tree_removal.amount = amount
        create_entity(ore_template_no_tree_removal)
    end
end

local dots_ores = { 'uranium-ore', 'stone', 'copper-ore', 'iron-ore', 'coal' }

---@param can_place_entity fun(LuaSurface.can_place_entity_param): boolean
---@param create_entity fun(LuaSurface.create_entity_param): LuaEntity?
---@param x number
---@param y number
---@param rng LuaRandomGenerator
---@param space number
local function generate_dots_tile(can_place_entity, create_entity, x, y, rng, space)
    ore_template_no_tree_removal.position[1], ore_template_no_tree_removal.position[2] = x, y
    ore_template_no_tree_removal.name = 'iron-ore'
    ore_template_no_tree_removal.amount = 1
    if can_place_entity(ore_template_no_tree_removal) then
        local ore
        local cx = x % (space * 2)
        local cy = y % (space * 2)
        if cx == 0 and cy == 0 then
            ore = dots_ores[2]
        elseif cx == 0 and cy == space then
            ore = dots_ores[3]
        elseif cx == space and cy == 0 then
            ore = dots_ores[4]
        elseif cx == space and cy == space then
            ore = dots_ores[5]
            if rng(1, 1000) > 998 then
                ore = dots_ores[1]
            end
        end
        if ore then
            ore_template_no_tree_removal.name = ore
            ore_template_no_tree_removal.amount = 100000
            create_entity(ore_template_no_tree_removal)
        end
    end
end

local checkerboard_ores = { 'uranium-ore', 'stone', 'copper-ore', 'iron-ore', 'coal' }

---@param can_place_entity fun(LuaSurface.can_place_entity_param): boolean
---@param create_entity fun(LuaSurface.create_entity_param): LuaEntity?
---@param seed uint
---@param x number
---@param y number
---@param cell_size number
---@param uranium_cells {[string]: boolean} # cache
local function generate_checkerboard_tile(can_place_entity, create_entity, seed, x, y, cell_size, uranium_cells)
    ore_template_no_tree_removal.position[1], ore_template_no_tree_removal.position[2] = x, y
    ore_template_no_tree_removal.name = 'iron-ore'
    ore_template_no_tree_removal.amount = 15000
    if can_place_entity(ore_template_no_tree_removal) then
        local ore
        local cell_x, cell_y = x - (x % cell_size), y - (y % cell_size)
        local cell_start_key = cell_x .. '_' .. cell_y
        if uranium_cells[cell_start_key] == nil then
            local new_seed = (cell_x * 374761393 + cell_y * 668265263 + seed) % 4294967296 -- numbers from internet
            local rng = game.create_random_generator(new_seed)
            uranium_cells[cell_start_key] = rng() > 0.999
        end

        if uranium_cells[cell_start_key] then
            ore = checkerboard_ores[1]
        else
            local cx = x % (cell_size * 2)
            local cy = y % (cell_size * 2)
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
        ore_template_no_tree_removal.name = ore
        create_entity(ore_template_no_tree_removal)
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

---@param can_place_entity fun(LuaSurface.can_place_entity_param): boolean
---@param create_entity fun(LuaSurface.create_entity_param): LuaEntity?
---@param seed uint
---@param x number
---@param y number
local function generate_vertical_lines_tile(can_place_entity, create_entity, seed, x, y)
    ore_template_no_tree_removal.position[1], ore_template_no_tree_removal.position[2] = x, y
    ore_template_no_tree_removal.name = 'iron-ore'
    ore_template_no_tree_removal.amount = 1
    if can_place_entity(ore_template_no_tree_removal) then
        local noise = get_noise(vertical_lines_ore_noise, x, y, seed, 10000)
        local i = math.floor(noise * 50 + math.abs(x) * 0.2) % 16 + 1
        local amount = (1000 + math.sqrt(x ^ 2 + y ^ 2) * 3) * 10
        ore_template_no_tree_removal.name = vertical_lines_ores[i]
        ore_template_no_tree_removal.amount = amount
        create_entity(ore_template_no_tree_removal)
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

local mixed_patches_hints = { 0.65, 0.45, 0.25, 0.16, 0.011, nil, nil, nil, nil, nil }
local impactful_mixed_ore_noise = { mixed_ore_noise[1] }

local function chunk_noise_hint(seed, chunk_pos)
    local mid_x, mid_y = chunk_pos.x * 32 + 16, chunk_pos.y * 32 + 16
    return math_abs(get_noise(impactful_mixed_ore_noise, mid_x, mid_y, seed, 10000))
end

local mixed_patches_ore_multiplier = { 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }

---@param can_place_entity fun(LuaSurface.can_place_entity_param): boolean
---@param create_entity fun(LuaSurface.create_entity_param): LuaEntity?
---@param seed uint
---@param x number
---@param y number
---@param rng LuaRandomGenerator
---@param size number
local function generate_mixed_patches_tile(can_place_entity, create_entity, seed, x, y, rng, size)
    local threshold = 0.1 * size
    local noise =
        get_noise_outside_bounds(mixed_ore_noise, mixed_ore_noise_amp_sum, x, y, seed, 10000, -threshold, threshold)
    if noise then
        ore_template.position[1], ore_template.position[2] = x, y
        ore_template.name = 'iron-ore'
        ore_template.amount = 1
        if can_place_entity(ore_template) then
            local i = math_floor(noise * 25 + math_abs(x) * 0.05) % 15 + 1
            local amount = (rng(800, 1000) + math_sqrt(x ^ 2 + y ^ 2) * 3) * mixed_patches_ore_multiplier[i]
            ore_template.name = mixed_patches_ores[i]
            ore_template.amount = amount
            create_entity(ore_template)
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
---@param chunk_pos {x: number, y: number}
---@return boolean|fun(x: number, y: number, rng: LuaRandomGenerator)|nil # nil, if special game disabled and 'false' if tile generation must be suppressed
function Public.get_tile_generator(surface, chunk_pos)
    if not storage.active_special_games['mixed_ore_map'] then
        return nil
    end

    local seed = surface.map_gen_settings.seed
    local can_place_entity = surface.can_place_entity
    local create_entity = surface.create_entity
    local type = storage.special_games_variables['mixed_ore_map']['type']
    local size = storage.special_games_variables['mixed_ore_map']['size']

    if type == 1 then
        local size = 1 + size
        return function(x, y, rng)
            generate_mixed_ore_tile(can_place_entity, create_entity, seed, x, y, rng, size)
        end
    elseif type == 2 then
        local cell_size = size
        if cell_size == 0 then
            cell_size = 1
        end
        local uranium_cells_cache = {}
        return function(x, y, _)
            generate_checkerboard_tile(can_place_entity, create_entity, seed, x, y, cell_size, uranium_cells_cache)
        end
    elseif type == 3 then
        return function(x, y, _)
            generate_vertical_lines_tile(can_place_entity, create_entity, seed, x, y)
        end
    elseif type == 4 then
        local chunk_has_ore_hint = mixed_patches_hints[size]
        if chunk_has_ore_hint and chunk_noise_hint(seed, chunk_pos) < chunk_has_ore_hint then
            return false
        end
        local size = 10 - size
        return function(x, y, rng)
            generate_mixed_patches_tile(can_place_entity, create_entity, seed, x, y, rng, size)
        end
    elseif type == 5 then
        local space = size
        return function(x, y, rng)
            generate_dots_tile(can_place_entity, create_entity, x, y, rng, space)
        end
    end
end

return Public
