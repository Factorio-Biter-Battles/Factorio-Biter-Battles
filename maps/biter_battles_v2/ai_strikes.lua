local AiTargets = require('maps.biter_battles_v2.ai_targets')
local Color = require('utils.color_presets')

local Public = {}

local bb_config = require('maps.biter_battles_v2.config')
local Color = require('utils.color_presets')

local math_random = math.random
local math_sqrt = math.sqrt
local math_fmod = math.fmod
local math_floor = math.floor
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_2pi = 2 * math_pi
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local f = string.format

-- these parameters roughly approximate the radius of the average player base
-- TODO: use some metric to drive adjustments on these values as the game progresses
local MAX_STRIKE_DISTANCE = 512
local MIN_STRIKE_DISTANCE = 256
local STRIKE_TARGET_CLEARANCE = 255
local _DEBUG = false

local function calculate_secant_intersections(r, a, b, c)
    local t = a * a + b * b
    local x = -a * c / t
    local y = -b * c / t
    local d = r * r - c * c / t
    local m = math_sqrt(d / t)
    local bm = b * m
    local am = a * m
    return {
        a = {
            x = x + bm,
            y = y - am,
        },
        b = {
            x = x - bm,
            y = y + am,
        },
    }
end

local function calculate_tangent_line(r, d)
    local r2 = r * r
    local t = r * math_sqrt(d * d - r2)
    return {
        a = t / d,
        b = d - r2 / d,
        c = -t,
    }
end

local function normalize_angle(angle)
    angle = math_fmod(angle + math_2pi, math_2pi)
    if angle > math_pi then
        angle = angle - math_2pi
    end
    return angle
end

local function calculate_strike_range(
    source_target_dx,
    source_target_dy,
    source_target_distance,
    inner_radius,
    outer_radius
)
    local theta = math_atan2(source_target_dy, source_target_dx)
    local t = calculate_tangent_line(inner_radius, source_target_distance)
    local intersections = calculate_secant_intersections(outer_radius, t.a, t.b, t.c)
    local phi = math_atan2(intersections.b.y, intersections.b.x)
    local start = normalize_angle(theta - phi)
    local finish = normalize_angle(theta + phi)
    if finish < start then
        finish = finish + math_2pi
    end
    return {
        start = start,
        finish = finish,
    }
end

local function calculate_boundary_range(boundary_offset, target_position, strike_radius)
    local c = target_position.y - boundary_offset
    local boundary_intersection = calculate_secant_intersections(strike_radius, 0, 1, c)
    local boundary_angle_start = math_atan2(boundary_intersection.a.y, boundary_intersection.a.x)
    local boundary_angle_finish = math_atan2(boundary_intersection.b.y, boundary_intersection.b.x)
    if boundary_angle_finish < boundary_angle_start then
        boundary_angle_finish = boundary_angle_finish + math_2pi
    end
    return {
        start = boundary_angle_start,
        finish = boundary_angle_finish,
    }
end

local function select_strike_position(source_position, target_position, boundary_offset)
    local source_target_dx = source_position.x - target_position.x
    local source_target_dy = source_position.y - target_position.y
    local source_target_distance = math_sqrt(source_target_dx * source_target_dx + source_target_dy * source_target_dy)
    if source_target_distance < MIN_STRIKE_DISTANCE then
        return {
            x = source_position.x,
            y = source_position.y,
        }
    end
    local strike_distance = math_random(MIN_STRIKE_DISTANCE, math_min(source_target_distance, MAX_STRIKE_DISTANCE))
    local strike_angle_range = calculate_strike_range(
        source_target_dx,
        source_target_dy,
        source_target_distance,
        STRIKE_TARGET_CLEARANCE,
        strike_distance
    )
    if boundary_offset > target_position.y - strike_distance then
        local boundary_angle_range = calculate_boundary_range(boundary_offset, target_position, strike_distance)
        strike_angle_range.start = math_max(strike_angle_range.start, boundary_angle_range.start)
        strike_angle_range.finish = math_min(strike_angle_range.finish, boundary_angle_range.finish)
    end
    local strike_angle_magnitude = strike_angle_range.finish - strike_angle_range.start
    local strike_zone_arc_length = math_floor(strike_distance * strike_angle_magnitude)
    local random_angle_offset = (math_random(0, strike_zone_arc_length) / strike_zone_arc_length)
        * strike_angle_magnitude
    local strike_angle = strike_angle_range.start + random_angle_offset
    local dx = strike_distance * math_cos(strike_angle)
    local dy = strike_distance * math_sin(strike_angle)
    return {
        x = target_position.x + dx,
        y = target_position.y + dy,
    }
end

local function print_admins(message, color)
    if not _DEBUG then
        return
    end
    for _, p in pairs(game.connected_players) do
        if p.admin then
            p.print(message, { color = color or Color.dark_gray })
        end
    end
end

---@class AIStrikeData
---@field unit_group LuaUnitGroup
---@field stage AIStage
---@field position MapPosition
---@field target? LuaEntity
---@field failed_attempts? number

local AI = {}

AI.stages = {
    pending = 1,
    move = 2,
    scout = 3,
    attack = 4,
    assassinate = 5,
    fail = 6,
}

AI.commands = {
    move = function(unit_group, position)
        local data = AI.take_control(unit_group)
        if not position then
            AI.processor(unit_group)
            return
        end
        data.position = position
        data.stage = AI.stages.move
        unit_group.set_command({
            type = defines.command.go_to_location,
            destination = position,
            radius = 3,
            distraction = defines.distraction.by_enemy,
        })
        unit_group.start_moving()
        print_admins(
            f(
                'AI [id=%d] | cmd: MOVE [gps=%.2f,%.2f,%s]',
                unit_group.unique_id,
                position.x,
                position.y,
                unit_group.surface.name
            )
        )
    end,
    scout = function(unit_group, position)
        local data = AI.take_control(unit_group)
        if not position then
            AI.processor(unit_group)
            return
        end
        data.position = position
        data.stage = AI.stages.scout
        unit_group.set_command({
            type = defines.command.attack_area,
            destination = position,
            radius = 15,
            distraction = defines.distraction.by_enemy,
        })
        unit_group.start_moving()
        print_admins(
            f(
                'AI [id=%d] | cmd: SCOUT [gps=%.2f,%.2f,%s]',
                unit_group.unique_id,
                position.x,
                position.y,
                unit_group.surface.name
            )
        )
    end,
    attack = function(unit_group, target)
        local data = AI.take_control(unit_group)
        if not (target and target.valid) then
            AI.processor(unit_group, nil)
            return
        end
        data.target = target
        data.stage = AI.stages.attack
        unit_group.set_command({
            type = defines.command.attack_area,
            destination = target.position,
            radius = 15,
            distraction = defines.distraction.by_damage,
        })
        print_admins(
            f(
                'AI [id=%d] | cmd: ATTACK [gps=%.2f,%.2f,%s] (type = %s)',
                unit_group.unique_id,
                target.position.x,
                target.position.y,
                unit_group.surface.name,
                target.type
            )
        )
    end,
    assassinate = function(unit_group, target)
        local data = AI.take_control(unit_group)
        if not (target and target.valid) then
            AI.processor(unit_group, nil)
            return
        end
        data.target = target
        data.stage = AI.stages.attack
        unit_group.set_command({
            type = defines.command.attack,
            target = target,
            distraction = defines.distraction.by_damage,
        })
        print_admins(
            f(
                'AI [id=%d] | cmd: ASSASSINATE [gps=%.2f,%.2f,%s] (type = %s)',
                unit_group.unique_id,
                target.position.x,
                target.position.y,
                unit_group.surface.name,
                target.type
            )
        )
    end,
}

AI.take_control = function(unit_group, options)
    if not storage.ai_strikes[unit_group.unique_id] then
        local target_force_name = options.target_force_name or (unit_group.position.y > 0 and 'south' or 'north')
        storage.ai_strikes[unit_group.unique_id] = {
            unit_group = unit_group,
            target_force_name = target_force_name,
            target = options.target,
            position = options.position,
            failed_attempts = options.failed_attempts,
        }
    end
    return storage.ai_strikes[unit_group.unique_id]
end

AI.stage_by_distance = function(posA, posB)
    local x_axis = posA.x - posB.x
    local y_axis = posA.y - posB.y
    local distance = math_sqrt(x_axis * x_axis + y_axis * y_axis)
    if distance <= 15 then
        return AI.stages.attack
    elseif distance <= 32 then
        return AI.stages.scout
    else
        return AI.stages.move
    end
end

AI.processor = function(unit_group, result)
    if not (unit_group and unit_group.valid) then
        return
    end
    local data = storage.ai_strikes[unit_group.unique_id]
    if not data then
        return
    end
    if data.failed_attempts and data.failed_attempts >= 3 then
        storage.ai_strikes[unit_group.unique_id] = nil
        return
    end

    if not result or result == defines.behavior_result.fail or result == defines.behavior_result.deleted then
        data.stage = AI.stages.pending
    end
    if result == defines.behavior_result.success and (data.stage and data.stage == AI.stages.attack) then
        data.stage = AI.stages.pending
    end
    data.stage = data.stage or AI.stages.pending

    if data.stage == AI.stages.pending then
        if not data.target or not data.target.valid then
            data.target = unit_group.surface.find_nearest_enemy_entity_with_owner({
                position = unit_group.position,
                max_distance = MAX_STRIKE_DISTANCE,
                force = unit_group.force,
            })
            --data.target = AiTargets.get_random_target(data.target_force_name)
        end
        if not (data.target and data.target.valid) then
            storage.ai_strikes[unit_group.unique_id] = nil
            print_admins('Could not find target for id ' .. unit_group.unique_id)
            return
        end
        --data.position = Public.calculate_strike_position(unit_group, data.target.position)
        data.position = data.target.position
        data.stage = AI.stage_by_distance(data.position, unit_group.position)
    else
        data.stage = data.stage + 1
    end

    print_admins(f('AI [id=%d] | status: %d', unit_group.unique_id, data.stage))
    if data.stage == AI.stages.move then
        AI.commands.move(unit_group, data.position)
    elseif data.stage == AI.stages.scout then
        AI.commands.scout(unit_group, data.position)
    elseif data.stage == AI.stages.attack then
        AI.commands.attack(unit_group, data.target)
    elseif data.stage == AI.stages.assassinate then
        local rocket_silo = global.rocket_silo[data.target_force_name]
        AI.commands.assassinate(unit_group, rocket_silo)
    else
        data.failed_attempts = (data.failed_attempts or 0) + 1
        print_admins(
            f('AI [id=%d] | FAIL | stage: %d | attempts: %d', unit_group.unique_id, data.stage, data.failed_attempts),
            Color.red
        )
        data.stage, data.position, data.target = nil, nil, nil
        AI.processor(unit_group, nil)
    end
end

function Public.calculate_strike_position(unit_group, target_position)
    local source_position = unit_group.position
    local normalized_source_position = { x = source_position.x, y = math_abs(source_position.y) }
    local normalized_target_position = { x = target_position.x, y = math_abs(target_position.y) }
    local boundary_offset = bb_config.border_river_width / 2
    local nominal_strike_position =
        select_strike_position(normalized_source_position, normalized_target_position, boundary_offset)
    if source_position.y < 0 then
        nominal_strike_position.y = -nominal_strike_position.y
    end
    return unit_group.surface.find_non_colliding_position('stone-furnace', nominal_strike_position, 96, 1)
end

---@param unit_group LuaUnitGroup
---@param target_force_name string
---@param strike_position MapPosition
---@param target LuaEntity
function Public.initiate(unit_group, target_force_name, strike_position, target)
    AI.take_control(unit_group, {
        target_force_name = target_force_name,
        position = strike_position,
        target = target,
    })
    AI.processor(unit_group, nil)
end

function Public.step(id, result)
    if storage.bb_game_won_by_team then
        return
    end

    local data = storage.ai_strikes[id]
    local unit_group = data and data.unit_group
    AI.processor(unit_group, result)
end

return Public
