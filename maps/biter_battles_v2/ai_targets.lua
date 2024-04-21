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

local function simple_random_sample(population_list)
    local population_size = #population_list
    if population_size > 0 then
        local random_index = math_random(1, population_size)
        local individual = population_list[random_index]
        return individual
    end
    return nil
end

function Public.start_tracking(entity)
    if not entity then return end
    if not entity.valid then return end
    if target_entity_type[entity.type] and entity.unit_number then
        local targets = global.ai_targets[entity.force.name]
        if targets ~= nil then
            global.ai_target_destroyed_map[script.register_on_entity_destroyed(entity)] = entity.force.name
            table_insert(targets.available_list, {unit_number = entity.unit_number, position = entity.position})
            targets.available[entity.unit_number] = #targets.available_list
        end
    end
end

local function on_entity_destroyed(event)
    local map = global.ai_target_destroyed_map
    local unit_number = event.unit_number
    local force = map[event.registration_number]
    map[event.registration_number] = nil
    local targets = global.ai_targets[force]
    if targets ~= nil then
        local target_list_index = targets.available[unit_number]
        if target_list_index ~= nil then
            if target_list_index ~= #targets.available_list then
                -- swap the last element with the element to be removed
                local last = targets.available_list[#targets.available_list]
                targets.available[last.unit_number] = target_list_index
                targets.available_list[target_list_index] = last
            end
            table_remove(targets.available_list)
            targets.available[unit_number] = nil
        end
    end
end

script.on_event(defines.events.on_entity_destroyed, on_entity_destroyed)

function Public.get_random_target(force_name)
    local targets = global.ai_targets[force_name]
    local available_list = targets.available_list
    local first_entity = simple_random_sample(available_list)
    local second_entity = simple_random_sample(available_list)
    if not first_entity or not second_entity then return nil end
    local first = first_entity.position
    local second = second_entity.position
    if origin_distance(first) < origin_distance(second) then
        return first
    else
        return second
    end
end

return Public