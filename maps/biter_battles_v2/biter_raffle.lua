local Public = {}
local math_random = math.random
local math_floor = math.floor
local math_max = math.max

local function get_raffle_table(level)
    if level < 500 then
        return {
            ['small-'] = 1000 - level * 1.75,
            ['medium-'] = math_max(-250 + level * 1.5, 0), -- only this one can be negative for level < 500
            ['big-'] = 0,
            ['behemoth-'] = 0,
        }
    end
    if level < 900 then
        return {
            ['small-'] = math_max(1000 - level * 1.75, 0), -- only this one can be negative for level < 900
            ['medium-'] = 1000 - level,
            ['big-'] = (level - 500) * 2,
            ['behemoth-'] = 0,
        }
    end
    return {
        ['small-'] = 0,
        ['medium-'] = math_max(1000 - level, 0),
        ['big-'] = (level - 500) * 2,
        ['behemoth-'] = (level - 900) * 8,
    }
end

local function roll(evolution_factor)
    local raffle = get_raffle_table(math_floor(evolution_factor * 1000))
    local r = math_random(0, math_floor(raffle[1] + raffle[2] + raffle[3] + raffle[4]))
    local current_chance = 0
    for k, v in pairs(raffle) do
        current_chance = current_chance + v
        if r <= current_chance then
            return k
        end
    end
end

local function get_biter_name(evolution_factor)
    return roll(evolution_factor) .. 'biter'
end

local function get_spitter_name(evolution_factor)
    return roll(evolution_factor) .. 'spitter'
end

local function get_worm_raffle_table(level)
    local raffle = {
        ['small-worm-turret'] = 1000 - level * 1.75,
        ['medium-worm-turret'] = level,
        ['big-worm-turret'] = 0,
        ['behemoth-worm-turret'] = 0,
    }

    if level > 500 then
        raffle['medium-worm-turret'] = 500 - (level - 500)
        raffle['big-worm-turret'] = (level - 500) * 2
    end
    if level > 900 then
        raffle['behemoth-worm-turret'] = (level - 900) * 3
    end
    for k, _ in pairs(raffle) do
        if raffle[k] < 0 then
            raffle[k] = 0
        end
    end
    return raffle
end

local function get_worm_name(evolution_factor)
    local raffle = get_worm_raffle_table(math_floor(evolution_factor * 1000))
    local max_chance = 0
    for _, v in pairs(raffle) do
        max_chance = max_chance + v
    end
    local r = math_random(0, math_floor(max_chance))
    local current_chance = 0
    for k, v in pairs(raffle) do
        current_chance = current_chance + v
        if r <= current_chance then
            return k
        end
    end
end

local function get_unit_name(evolution_factor)
    if math_random(1, 3) == 1 then
        return get_spitter_name(evolution_factor)
    else
        return get_biter_name(evolution_factor)
    end
end

local type_functions = {
    ['spitter'] = get_spitter_name,
    ['biter'] = get_biter_name,
    ['mixed'] = get_unit_name,
    ['worm'] = get_worm_name,
}

---@param entity_type 'spitter'|'biter'|'mixed'|'worm'
---@param evolution_factor number?
---@return string?
function Public.roll(entity_type, evolution_factor)
    if not entity_type then
        return
    end
    if not type_functions[entity_type] then
        return
    end
    local evo = evolution_factor
    if not evo then
        evo = game.forces.enemy.get_evolution_factor(storage.bb_surface_name)
    end
    return type_functions[entity_type](evo)
end

return Public
