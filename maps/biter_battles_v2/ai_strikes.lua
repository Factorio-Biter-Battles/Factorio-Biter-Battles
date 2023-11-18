local Public = {}

local bb_config = require "maps.biter_battles_v2.config"

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

-- these parameters roughly approximate the radius of the average player base
-- TODO: use some metric to drive adjustments on these values as the game progresses
local max_strike_distance = 512
local min_strike_distance = 256
local strike_target_clearance = 255

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
        c = -t
    }
end

local function normalize_angle(angle)
    angle = math_fmod(angle + math_2pi, math_2pi)
    if angle > math_pi then
        angle = angle - math_2pi
    end
    return angle
end

local function calculate_strike_range(source_target_dx, source_target_dy, source_target_distance, inner_radius, outer_radius)
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
    if source_target_distance < min_strike_distance then
        return {
            x = source_position.x,
            y = source_position.y,
        }
    end
    local strike_distance = math_random(min_strike_distance, math_min(source_target_distance, max_strike_distance))
    local strike_angle_range = calculate_strike_range(source_target_dx, source_target_dy, source_target_distance, strike_target_clearance, strike_distance)
    if boundary_offset > target_position.y - strike_distance then
        local boundary_angle_range = calculate_boundary_range(boundary_offset, target_position, strike_distance)
        strike_angle_range.start = math_max(strike_angle_range.start, boundary_angle_range.start)
        strike_angle_range.finish = math_min(strike_angle_range.finish, boundary_angle_range.finish)
    end
    local strike_angle_magnitude = strike_angle_range.finish - strike_angle_range.start
    local strike_zone_arc_length = math_floor(strike_distance * strike_angle_magnitude)
    local random_angle_offset = (math_random(0, strike_zone_arc_length) / strike_zone_arc_length) * strike_angle_magnitude
    local strike_angle = strike_angle_range.start + random_angle_offset
    local dx = strike_distance * math_cos(strike_angle)
    local dy = strike_distance * math_sin(strike_angle)
    return {
        x = target_position.x + dx,
        y = target_position.y + dy,
    }
end

local function move(unit_group, position)
    unit_group.set_command({
        type = defines.command.go_to_location,
        destination = position,
        radius = 32,
        distraction = defines.distraction.by_enemy
    })
end

local function attack(unit_group, position)
    unit_group.set_command({
        type = defines.command.attack_area,
        destination = position,
        radius = 32,
        distraction = defines.distraction.by_enemy
    })
end

local function assassinate(unit_group, target)
    unit_group.set_command({
        type = defines.command.attack,
        target = target,
        distraction = defines.distraction.by_damage
    })
end

function Public.initiate(unit_group, target_force_name, target_position)
    local strike_info = {
        unit_group = unit_group,
        target_force_name = target_force_name,
        source_position = { x = unit_group.position.x, y = unit_group.position.y },
        target_position = target_position,
    }
    local normalized_source_position = { x = strike_info.source_position.x, y = math_abs(strike_info.source_position.y) }
    local normalized_target_position = { x = strike_info.target_position.x, y = math_abs(strike_info.target_position.y) }
    local boundary_offset = bb_config.border_river_width / 2
    local nominal_strike_position = select_strike_position(normalized_source_position, normalized_target_position, boundary_offset)
    if strike_info.source_position.y < 0 then
        nominal_strike_position.y = -nominal_strike_position.y
    end
    local strike_position = unit_group.surface.find_non_colliding_position("stone-furnace", nominal_strike_position, 96, 1);
    if strike_position ~= nil then
        strike_info.strike_position = strike_position
        strike_info.phase = 1
        move(unit_group, strike_position)
    else
        strike_info.strike_position = strike_info.current_position
        strike_info.phase = 2
        attack(unit_group, strike_info.target_position)
    end
    global.ai_strikes[unit_group.group_number] = strike_info
end

function Public.step(group_number, result)
    local strike = global.ai_strikes[group_number]
    if strike ~= nil then
        if result == defines.behavior_result.success then
            strike.phase = strike.phase + 1
            if strike.phase == 2 then
                attack(strike.unit_group, strike.target_position)
            elseif strike.phase == 3 then
                local rocket_silo = global.rocket_silo[strike.target_force_name]
                assassinate(strike.unit_group, rocket_silo)
            else
                global.ai_strikes[group_number] = nil
            end
        elseif result == defines.behavior_result.fail or result == defines.behavior_result.deleted then
            global.ai_strikes[group_number] = nil
        end
    end
end

return Public