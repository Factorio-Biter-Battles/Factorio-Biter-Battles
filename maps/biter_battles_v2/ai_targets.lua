local Public = {}

local math_sqrt = math.sqrt
local math_random = math.random
local table_insert = table.insert
local table_remove = table.remove

-- the current dirt simple "strike" model assumes the target is part of a spherical base with a perimeter less than 256-512
-- the ideal target entity would lie at the center of that, in the "core" of a base
function Public.refresh_target_types()
    storage.target_entity_type = {
        ['boiler'] = true,
        ['reactor'] = true,
        ['heat-interface'] = true,
        ['generator'] = true,
        ['solar-panel'] = true,
        ['accumulator'] = true,
        ['mining-drill'] = true,
        ['furnace'] = true,
        ['assembling-machine'] = true,
        ['beacon'] = true,
        ['roboport'] = true,
        ['lab'] = true,
        ['rocket-silo'] = true,
        -- logic forks for entities below for classic and advanced pathfinding based
        -- offshore pumps were added to the target list with the addition of advanced pathfinding
        -- all turrets and radars were removed from the target list with advanced pathfinding
        -- the idea with the changes in advanced pathfinding was to:
        -- 1) Avoid entities which generate distractions
        -- 2) Avoid entities (turrets) which are spammed disproportionally late game
        -- 3) Avoid entities which are placed on the perimeter of bases
        -- 4) Avoid making biter waves suicide into defenses
        -- offshore pump was also added to the target list with advanced pathfinding to encourage
        -- attacks on power
        ['offshore-pump'] = not storage.bb_settings.classic_pathfinding,
        ['ammo-turret'] = storage.bb_settings.classic_pathfinding,
        ['artillery-turret'] = storage.bb_settings.classic_pathfinding,
        ['electric-turret'] = storage.bb_settings.classic_pathfinding,
        ['fluid-turret'] = storage.bb_settings.classic_pathfinding,
        ['radar'] = storage.bb_settings.classic_pathfinding,
    }
end

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
    if not entity then
        return
    end
    if not entity.valid then
        return
    end
    if storage.target_entity_type[entity.type] and entity.unit_number then
        local targets = storage.ai_targets[entity.force.name]
        if targets ~= nil then
            local _, id, _ = script.register_on_object_destroyed(entity)
            storage.ai_target_destroyed_map[id] = entity.force.name
            table_insert(targets.available_list, { id = id, position = entity.position })
            targets.available[id] = #targets.available_list
        end
    end
end

local function on_object_destroyed(event)
    local map = storage.ai_target_destroyed_map
    local id = event.useful_id
    local force = map[id]
    map[id] = nil
    local targets = storage.ai_targets[force]
    if targets ~= nil then
        local target_list_index = targets.available[id]
        if target_list_index ~= nil then
            if target_list_index ~= #targets.available_list then
                -- swap the last element with the element to be removed
                local last = targets.available_list[#targets.available_list]
                targets.available[last.id] = target_list_index
                targets.available_list[target_list_index] = last
            end
            table_remove(targets.available_list)
            targets.available[id] = nil
        end
    end
end

script.on_event(defines.events.on_object_destroyed, on_object_destroyed)

function Public.get_random_target(force_name)
    local targets = storage.ai_targets[force_name]
    local available_list = targets.available_list
    local first_entity = simple_random_sample(available_list)
    local second_entity = simple_random_sample(available_list)
    if not first_entity or not second_entity then
        return nil
    end
    local first = first_entity.position
    local second = second_entity.position
    if origin_distance(first) < origin_distance(second) then
        return first
    else
        return second
    end
end

return Public
