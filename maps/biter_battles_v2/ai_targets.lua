local Public = {}

local math_sqrt = math.sqrt
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove

-- the current dirt simple "strike" model assumes the target is part of a spherical base with a perimeter less than 256-512
-- the ideal target entity would lie at the center of that, in the "core" of a base
local target_entity_type = {
    ["boiler"] = true,
    ["reactor"] = true,
    ["heat-interface"] = true,
    ["generator"] = true,
    ["solar-panel"] = true,
    ["accumulator"] = true,
    ["mining-drill"] = true,
    ["offshore-pump"] = true,
    ["furnace"] = true,
    ["assembling-machine"] = true,
    ["beacon"] = true,
    ["roboport"] = true,
    ["lab"] = true,
    ["rocket-silo"] = true,
    -- the entities below don't make sense to center strike calculations around due to:
    -- 1. these generally lie at the edge of a base, along with walls.
    -- 2. they already generate a distraction command for biters when in range. we don't need to increase their chances of an encounter any more
    -- 3. players spam these mid to late game. they command a disproportionate presence in the current uniform sampling approach
    -- 4. biter groups should (by chance) avoid turrets/walls during a strike instead of actively picking them as a target and suiciding into them
    ["ammo-turret"] = false,
    ["artillery-turret"] = false,
    ["electric-turret"] = false,
    ["fluid-turret"] = false,
    ["radar"] = false,
}

local function origin_distance(position)
    local x = position.x
    local y = position.y
    return math_sqrt(x * x + y * y)
end

local function simple_random_sample(population_list, sample_size)
    local population_size = #population_list
    local sample = {}
    if population_size > 0 then
        for _ = 1, sample_size, 1 do
            local random_index = math_random(1, population_size)
            local individual = population_list[random_index]
            table_insert(sample, individual)
        end
    end
    return sample
end

function Public.start_tracking(entity)
    if not entity then return end
    if not entity.valid then return end
    if target_entity_type[entity.type] and entity.unit_number then
        local targets = global.ai_targets[entity.force.name]
        if targets ~= nil then
            targets.available[entity.unit_number] = entity
        end
    end
end

function Public.stop_tracking(entity)
    if target_entity_type[entity.type] and entity.unit_number then
        local targets = global.ai_targets[entity.force.name]
        if targets ~= nil then
            targets.available[entity.unit_number] = nil
        end
    end
end

function Public.select(force_name)
    local population_list = {}
    local targets = global.ai_targets[force_name]
    local available = targets.available
    for unit_number, entity in pairs(available) do
        if entity.valid then
            table_insert(population_list, entity.position)
        else
            available[unit_number] = nil
        end
    end
    -- (max) 7 targets per wave * 2 sub-sample size = 14 global sample size per wave
    local sample = simple_random_sample(population_list, 14)
    local selected = {}
    for i = 1, #sample, 2 do
        local first = sample[i]
        local second = sample[i + 1]
        local selection
        if origin_distance(first) < origin_distance(second) then selection = first else selection = second end
        table_insert(selected, { x = selection.x, y = selection.y })
    end
    targets.selected = selected
end

function Public.poll(force_name)
    local targets = global.ai_targets[force_name]
    local target = table_remove(targets.selected)
    -- If you have no more side-targets to attack, then attack silo.
    if not target then
            target = global.rocket_silo[force_name].position
    end

    return target
end

return Public
