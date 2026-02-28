local Public = {}

local bb_config = require('maps.biter_battles_v2.config')
local Pool = require('maps.biter_battles_v2.pool')

local math_abs = math.abs
local math_atan2 = math.atan2
local math_ceil = math.ceil
local math_cos = math.cos
local math_floor = math.floor
local math_fmod = math.fmod
local math_huge = math.huge
local math_max = math.max
local math_min = math.min
local math_pi = math.pi
local math_random = math.random
local math_sin = math.sin
local math_sqrt = math.sqrt
local table_remove = table.remove

local math_2pi = 2 * math_pi

-- these parameters roughly approximate the radius of the average player base
-- TODO: use some metric to drive adjustments on these values as the game progresses
local MAX_STRIKE_DISTANCE = 512
local MIN_STRIKE_DISTANCE = 256
local STRIKE_TARGET_CLEARANCE = 255

local CFG = {
    sample_step_tiles = 0.5,
    ingress_spacing = 12,
    max_distance_candidates = 4,
    start_candidate_oversample = 3,
    blitz_ingress_radius = 16,
    source_to_start_distance_penalty_per_tile = 0.05,
    breaker_probe_radius = 2.0,
    min_speed_tiles_per_tick = 0.02,
    effective_dps_by_turret = {
        ['gun-turret'] = 18,
        ['laser-turret'] = 24,
        ['flamethrower-turret'] = 40,
        ['tesla-turret'] = 35,
    },
    structure_dps_by_biter = {
        ['small-biter'] = 7,
        ['medium-biter'] = 15,
        ['big-biter'] = 30,
        ['behemoth-biter'] = 60,
    },
    turret_modifier_category_by_name = {
        ['gun-turret'] = 'gun-turret',
        ['laser-turret'] = 'laser-turret',
        ['flamethrower-turret'] = 'flamethrower-turret',
        ['tesla-turret'] = 'tesla-turret',
    },
}

local _DEBUG = false

local function table_count(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function ensure_state()
    storage.ai_blitz = storage.ai_blitz or {}
    local state = storage.ai_blitz
    if state.enabled == nil then
        state.enabled = false
    end
    if not state.max_starts_per_batch then
        state.max_starts_per_batch = 8
    end
    state.vote = state.vote or {}
    if state.vote.resolved == nil then
        state.vote.resolved = false
    end
    state.vote.yes_votes = state.vote.yes_votes or 0
    state.vote.no_votes = state.vote.no_votes or 0
    state.pending = state.pending or {}
    state.batches = state.batches or {}
    state.next_batch_id = state.next_batch_id or 1
    state.stats = state.stats or {}
    state.stats.requested = state.stats.requested or 0
    state.stats.completed = state.stats.completed or 0
    state.stats.try_again_later = state.stats.try_again_later or 0
    state.stats.no_path = state.stats.no_path or 0
    state.completed_order = state.completed_order or {}
    state.max_completed_batches = state.max_completed_batches or 64
    return state
end

Public.ensure_state = ensure_state

function Public.is_blitz_enabled()
    return ensure_state().enabled
end

function Public.set_blitz_enabled(enabled)
    local state = ensure_state()
    state.enabled = not not enabled
    return state.enabled
end

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

local function select_random_strike_position(source_position, target_position, boundary_offset)
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
    if strike_zone_arc_length <= 0 then
        local dx = strike_distance * math_cos(strike_angle_range.start)
        local dy = strike_distance * math_sin(strike_angle_range.start)
        return {
            x = target_position.x + dx,
            y = target_position.y + dy,
        }
    end
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

function Public.calculate_strike_position(unit_group, target_position)
    local source_position = unit_group.position
    local normalized_source_position = { x = source_position.x, y = math_abs(source_position.y) }
    local normalized_target_position = { x = target_position.x, y = math_abs(target_position.y) }
    local boundary_offset = bb_config.border_river_width / 2
    local nominal_strike_position =
        select_random_strike_position(normalized_source_position, normalized_target_position, boundary_offset)
    if source_position.y < 0 then
        nominal_strike_position.y = -nominal_strike_position.y
    end
    return unit_group.surface.find_non_colliding_position('stone-furnace', nominal_strike_position, 96, 1)
end

local function build_strike_distance_candidates(max_distance, max_starts)
    if max_distance <= MIN_STRIKE_DISTANCE then
        return { max_distance }
    end
    local distance_count = 1
    if max_starts and max_starts > 1 then
        distance_count = math_max(2, math_min(CFG.max_distance_candidates, math_floor(max_starts / 2)))
    end
    if distance_count <= 1 then
        return { (MIN_STRIKE_DISTANCE + max_distance) / 2 }
    end
    local distances = {}
    local span = max_distance - MIN_STRIKE_DISTANCE
    for i = 0, distance_count - 1, 1 do
        local ratio = i / (distance_count - 1)
        distances[#distances + 1] = MIN_STRIKE_DISTANCE + span * ratio
    end
    return distances
end

local function append_starts_for_distance(starts, strike_distance, source_target, max_points_for_distance)
    local strike_angle_range = calculate_strike_range(
        source_target.dx,
        source_target.dy,
        source_target.distance,
        STRIKE_TARGET_CLEARANCE,
        strike_distance
    )
    if source_target.boundary_offset > source_target.normalized_target.y - strike_distance then
        local boundary_angle_range =
            calculate_boundary_range(source_target.boundary_offset, source_target.normalized_target, strike_distance)
        strike_angle_range.start = math_max(strike_angle_range.start, boundary_angle_range.start)
        strike_angle_range.finish = math_min(strike_angle_range.finish, boundary_angle_range.finish)
    end
    local magnitude = strike_angle_range.finish - strike_angle_range.start
    if magnitude <= 0 then
        return 0
    end
    local arc_length = strike_distance * magnitude
    local max_segments = math_max(0, max_points_for_distance - 1)
    local segments = math_max(0, math_floor(arc_length / CFG.ingress_spacing))
    segments = math_min(segments, max_segments)
    local point_count = segments + 1
    for i = 0, point_count - 1, 1 do
        local ratio = point_count == 1 and 0.5 or (i / (point_count - 1))
        local strike_angle = strike_angle_range.start + magnitude * ratio
        local point = {
            x = source_target.normalized_target.x + strike_distance * math_cos(strike_angle),
            y = source_target.normalized_target.y + strike_distance * math_sin(strike_angle),
        }
        if source_target.source_y < 0 then
            point.y = -point.y
        end
        starts[#starts + 1] = point
    end
    return point_count
end

local function calculate_blitz_candidate_starts(unit, target_position, max_starts)
    local source_position = unit.position
    local normalized_source = { x = source_position.x, y = math_abs(source_position.y) }
    local normalized_target = { x = target_position.x, y = math_abs(target_position.y) }
    local boundary_offset = bb_config.border_river_width / 2
    local source_target_dx = normalized_source.x - normalized_target.x
    local source_target_dy = normalized_source.y - normalized_target.y
    local source_target_distance = math_sqrt(source_target_dx * source_target_dx + source_target_dy * source_target_dy)
    if source_target_distance < MIN_STRIKE_DISTANCE then
        return { { x = source_position.x, y = source_position.y } }
    end
    local strike_distance_max = math_min(source_target_distance, MAX_STRIKE_DISTANCE)
    local distance_candidates = build_strike_distance_candidates(strike_distance_max, max_starts)
    local candidate_budget = math_max(max_starts, max_starts * CFG.start_candidate_oversample)
    local max_points_for_distance = math_max(1, math_floor(candidate_budget / #distance_candidates))
    local source_target = {
        dx = source_target_dx,
        dy = source_target_dy,
        distance = source_target_distance,
        normalized_target = normalized_target,
        boundary_offset = boundary_offset,
        source_y = source_position.y,
    }
    local starts = {}
    for _, strike_distance in ipairs(distance_candidates) do
        append_starts_for_distance(starts, strike_distance, source_target, max_points_for_distance)
    end
    if #starts == 0 then
        starts[1] = { x = source_position.x, y = source_position.y }
    end
    return starts
end

local function downsample_starts(starts, max_count)
    local count = #starts
    if count <= max_count then
        return starts
    end
    local selected = {}
    local step = count / max_count
    for i = 1, max_count, 1 do
        local index = math_floor((i - 0.5) * step) + 1
        if index < 1 then
            index = 1
        elseif index > count then
            index = count
        end
        selected[#selected + 1] = starts[index]
    end
    return selected
end

local function shuffle_indices(list)
    local indices = Pool.malloc(#list)
    for i = 1, #list do
        indices[i] = i
    end

    -- Fisher-Yates shuffle
    for i = #indices, 2, -1 do
        local j = math_random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    return indices
end

local function build_attack_command_chain(target_force_name, strike_position, target_position, blitz_mode)
    local chain = {}
    local ingress_radius = blitz_mode and CFG.blitz_ingress_radius or 32
    local ingress_distraction = blitz_mode and defines.distraction.by_damage or defines.distraction.by_enemy
    local target_distraction = blitz_mode and defines.distraction.by_damage or defines.distraction.by_enemy
    if strike_position then
        chain[#chain + 1] = {
            type = defines.command.go_to_location,
            destination = strike_position,
            radius = ingress_radius,
            distraction = ingress_distraction,
        }
        chain[#chain + 1] = {
            type = defines.command.wander,
            radius = ingress_radius,
            ticks_to_wait = 1,
        }
    end
    chain[#chain + 1] = {
        type = defines.command.attack_area,
        destination = target_position,
        radius = 32,
        distraction = target_distraction,
    }
    chain[#chain + 1] = {
        type = defines.command.wander,
        radius = 32,
        ticks_to_wait = 1,
    }
    -- Chain all possible silos in random order so biters always have something to do.
    local list = storage.rocket_silo[target_force_name]
    if list and #list > 0 then
        local indices = shuffle_indices(list)
        for _, i in ipairs(indices) do
            local silo = list[i]
            if silo and silo.valid then
                chain[#chain + 1] = {
                    type = defines.command.attack,
                    target = silo,
                    distraction = defines.distraction.by_damage,
                }
            end
        end
    end
    return {
        type = defines.command.compound,
        structure_type = defines.compound_command.return_last,
        commands = chain,
    }
end

function Public.initiate(unit_group, target_force_name, strike_position, target_position, blitz_mode)
    if storage.bb_game_won_by_team then
        return
    end
    if not (unit_group and unit_group.valid and target_position) then
        return
    end
    unit_group.set_command(build_attack_command_chain(target_force_name, strike_position, target_position, blitz_mode))
end

function Public.initiate_pair(
    unit_group,
    unit_group_boss,
    target_force_name,
    strike_position,
    target_position,
    blitz_mode
)
    Public.initiate(unit_group, target_force_name, strike_position, target_position, blitz_mode)
    Public.initiate(unit_group_boss, target_force_name, strike_position, target_position, blitz_mode)
end

local function vec_sub(a, b)
    return { x = a.x - b.x, y = a.y - b.y }
end

local function vec_len(v)
    return math_sqrt(v.x * v.x + v.y * v.y)
end

local function dist(a, b)
    local dx = a.x - b.x
    local dy = a.y - b.y
    return math_sqrt(dx * dx + dy * dy)
end

local function lerp(a, b, t)
    return { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t }
end

local function expand_bbox(bbox, margin)
    return {
        left_top = { x = bbox.left_top.x - margin, y = bbox.left_top.y - margin },
        right_bottom = { x = bbox.right_bottom.x + margin, y = bbox.right_bottom.y + margin },
    }
end

local function bbox_from_positions(positions, anchor)
    local min_x = anchor.x
    local max_x = anchor.x
    local min_y = anchor.y
    local max_y = anchor.y
    for _, p in ipairs(positions) do
        if p.x < min_x then
            min_x = p.x
        elseif p.x > max_x then
            max_x = p.x
        end

        if p.y < min_y then
            min_y = p.y
        elseif p.y > max_y then
            max_y = p.y
        end
    end
    return {
        left_top = { x = min_x, y = min_y },
        right_bottom = { x = max_x, y = max_y },
    }
end

local function get_unit_speed_tiles_per_tick(unit)
    local speed = unit.effective_speed or unit.speed or 0
    if speed <= 0 then
        return CFG.min_speed_tiles_per_tick
    end
    return math_max(speed, CFG.min_speed_tiles_per_tick)
end

local function get_biter_structure_dps(unit)
    return CFG.structure_dps_by_biter[unit.name] or 10
end

local function estimate_turret_damage_per_second(turret)
    local proto = turret.prototype
    local attack_parameters = proto and proto.attack_parameters
    if not attack_parameters then
        return 0
    end
    local dps = CFG.effective_dps_by_turret[turret.name] or 0
    if dps <= 0 then
        return 0
    end
    if turret.force then
        local category = CFG.turret_modifier_category_by_name[turret.name]
        if category then
            local ok, modifier = pcall(function()
                return turret.force.get_turret_attack_modifier(category)
            end)
            if ok and modifier then
                dps = dps * (1 + modifier)
            end
        end
        if attack_parameters.ammo_categories and attack_parameters.ammo_categories[1] then
            local ammo_category = attack_parameters.ammo_categories[1]
            local ok, modifier = pcall(function()
                return turret.force.get_ammo_damage_modifier(ammo_category)
            end)
            if ok and modifier then
                dps = dps * (1 + modifier)
            end
        end
    end
    return dps
end

local function build_turret_snapshot(surface, area, enemy_force)
    local entities = surface.find_entities_filtered({ area = area, force = enemy_force })
    local turrets = {}
    for _, entity in pairs(entities) do
        if
            entity.valid
            and entity.prototype
            and entity.prototype.turret_range
            and entity.prototype.attack_parameters
        then
            local attack_parameters = entity.prototype.attack_parameters
            local range = entity.prototype.turret_range or attack_parameters.range or 0
            local min_range = attack_parameters.min_range or 0
            local dps = estimate_turret_damage_per_second(entity)
            if dps > 0 and range > 0 then
                turrets[#turrets + 1] = {
                    entity = entity,
                    pos = { x = entity.position.x, y = entity.position.y },
                    range = range,
                    min_range = min_range,
                    dps = dps,
                }
            end
        end
    end
    return turrets
end

local function incoming_damage_per_tick_at(position, turrets)
    local dps_sum = 0
    for _, turret in pairs(turrets) do
        if turret.entity.valid then
            local distance = dist(position, turret.pos)
            if distance <= turret.range and distance >= turret.min_range then
                dps_sum = dps_sum + turret.dps
            end
        end
    end
    return dps_sum / 60.0
end

local function estimate_break_delay_ticks(surface, position, enemy_force, unit)
    local nearby = surface.find_entities_filtered({
        position = position,
        radius = CFG.breaker_probe_radius,
        force = enemy_force,
    })
    local best_hp
    for _, entity in pairs(nearby) do
        if
            entity.valid
            and entity.max_health
            and entity.max_health > 0
            and entity.type ~= 'unit'
            and entity.type ~= 'character'
        then
            local hp = entity.health or entity.max_health
            if not best_hp or hp < best_hp then
                best_hp = hp
            end
        end
    end
    if not best_hp then
        return 0
    end
    local dps = math_max(get_biter_structure_dps(unit), 0.1)
    return best_hp / dps * 60.0
end

local function score_path_damage_ticks(surface, path, meta)
    if not path or #path == 0 then
        return math_huge
    end
    local unit = meta.unit
    local enemy_force = meta.enemy_force
    local turrets = meta.turrets
    local speed_tiles_per_tick = get_unit_speed_tiles_per_tick(unit)
    local total_damage = 0
    if meta.blitz_mode and meta.source and meta.start then
        local source_to_start_distance = dist(meta.source, meta.start)
        if source_to_start_distance > 0 then
            total_damage = total_damage + (source_to_start_distance * CFG.source_to_start_distance_penalty_per_tile)
            local sample_count = math_max(1, math_ceil(source_to_start_distance / CFG.sample_step_tiles))
            local dt_per_sample = (source_to_start_distance / sample_count) / speed_tiles_per_tick
            for s = 1, sample_count, 1 do
                local point = lerp(meta.source, meta.start, s / sample_count)
                local damage_per_tick = incoming_damage_per_tick_at(point, turrets)
                total_damage = total_damage + damage_per_tick * dt_per_sample
            end
        end
    end
    local previous = meta.start
    for i = 1, #path, 1 do
        local waypoint = path[i]
        local current = waypoint.position
        local segment = vec_sub(current, previous)
        local segment_length = vec_len(segment)
        if segment_length > 0 then
            local sample_count = math_max(1, math_ceil(segment_length / CFG.sample_step_tiles))
            local dt_per_sample = (segment_length / sample_count) / speed_tiles_per_tick
            for s = 1, sample_count, 1 do
                local point = lerp(previous, current, s / sample_count)
                local damage_per_tick = incoming_damage_per_tick_at(point, turrets)
                total_damage = total_damage + damage_per_tick * dt_per_sample
            end
        end
        if waypoint.needs_destroy_to_reach then
            local delay_ticks = estimate_break_delay_ticks(surface, current, enemy_force, unit)
            if delay_ticks > 0 then
                local local_damage_per_tick = incoming_damage_per_tick_at(current, turrets)
                total_damage = total_damage + local_damage_per_tick * delay_ticks
            else
                total_damage = total_damage + 50
            end
        end
        previous = current
    end
    if meta.goal then
        local current = meta.goal
        local segment = vec_sub(current, previous)
        local segment_length = vec_len(segment)
        if segment_length > 0 then
            local sample_count = math_max(1, math_ceil(segment_length / CFG.sample_step_tiles))
            local dt_per_sample = (segment_length / sample_count) / speed_tiles_per_tick
            for s = 1, sample_count, 1 do
                local point = lerp(previous, current, s / sample_count)
                local damage_per_tick = incoming_damage_per_tick_at(point, turrets)
                total_damage = total_damage + damage_per_tick * dt_per_sample
            end
        end
    end
    return total_damage
end

local function finalize_batch(state, batch)
    batch.done = true
    batch.finished = game.tick
    batch.elapsed_ticks = batch.finished - batch.started
    local strike_position = batch.best_start or batch.fallback_start
    if batch.best_damage == math_huge then
        batch.best_damage = nil
        batch.best_waypoints = 0
        state.stats.no_path = state.stats.no_path + 1
        if storage.bb_debug then
            game.print(('AI Blitz batch %d no path'):format(batch.batch_id))
        end
    elseif storage.bb_debug then
        game.print(
            ('AI Blitz batch %d score=%.1f waypoints=%d elapsed=%d'):format(
                batch.batch_id,
                batch.best_damage,
                batch.best_waypoints,
                batch.elapsed_ticks
            )
        )
    end
    Public.initiate_pair(
        batch.unit_group,
        batch.unit_group_boss,
        batch.target_force_name,
        strike_position,
        batch.target_position,
        batch.blitz_mode
    )
    batch.unit = nil
    batch.enemy_force = nil
    batch.turrets = nil
    batch.unit_group = nil
    batch.unit_group_boss = nil
    local completed_order = state.completed_order
    completed_order[#completed_order + 1] = batch.batch_id
    while #completed_order > state.max_completed_batches do
        local oldest_batch_id = table_remove(completed_order, 1)
        state.batches[oldest_batch_id] = nil
    end
end

function Public.request_least_damage_paths(unit, target_position, enemy_force, base_bbox, meta)
    local state = ensure_state()
    if not state.enabled then
        return nil
    end
    if not (unit and unit.valid and target_position and target_position.x and target_position.y) then
        return nil
    end
    local surface = unit.surface
    if not surface or not surface.valid then
        return nil
    end
    local enemy = enemy_force
    if not enemy and meta and meta.target_force_name then
        enemy = game.forces[meta.target_force_name]
    end
    if not enemy then
        return nil
    end
    local max_starts = state.max_starts_per_batch
    if meta and meta.max_starts and meta.max_starts > 0 then
        max_starts = meta.max_starts
    end
    max_starts = math_max(1, math_floor(max_starts or 1))
    local starts = calculate_blitz_candidate_starts(unit, target_position, max_starts)
    if #starts == 0 then
        return nil
    end
    starts = downsample_starts(starts, max_starts)
    local scan_area = expand_bbox(base_bbox or bbox_from_positions(starts, target_position), 64)
    local turrets = build_turret_snapshot(surface, scan_area, enemy)
    local batch_id = state.next_batch_id
    state.next_batch_id = batch_id + 1
    local batch = {
        batch_id = batch_id,
        unit = unit,
        enemy_force = enemy,
        turrets = turrets,
        started = game.tick,
        outstanding = 0,
        best_damage = math_huge,
        best_waypoints = 0,
        best_start = nil,
        fallback_start = starts[1],
        done = false,
        source_position = { x = unit.position.x, y = unit.position.y },
        blitz_mode = meta and meta.blitz_mode or false,
        unit_group = meta and meta.unit_group or nil,
        unit_group_boss = meta and meta.unit_group_boss or nil,
        target_force_name = meta and meta.target_force_name or nil,
        target_position = meta and meta.target_position or { x = target_position.x, y = target_position.y },
    }
    state.batches[batch_id] = batch
    local unit_collision_box = unit.prototype.collision_box
    local collision_mask = unit.prototype.collision_mask
    for _, start_position in pairs(starts) do
        if not unit.valid then
            break
        end
        local request_id = surface.request_path({
            bounding_box = unit_collision_box,
            collision_mask = collision_mask,
            start = start_position,
            goal = target_position,
            force = unit.force,
            radius = 0.5,
            can_open_gates = true,
            path_resolution_modifier = 0,
            max_gap_size = 0,
            pathfind_flags = {
                cache = false,
                low_priority = true,
                prefer_straight_paths = false,
            },
        })
        if request_id then
            state.pending[request_id] = {
                batch_id = batch_id,
                start = start_position,
                goal = { x = target_position.x, y = target_position.y },
            }
            batch.outstanding = batch.outstanding + 1
            state.stats.requested = state.stats.requested + 1
        end
    end
    if batch.outstanding == 0 then
        state.batches[batch_id] = nil
        return nil
    end
    return batch_id
end

function Public.on_script_path_request_finished(event)
    local state = ensure_state()
    local request = state.pending[event.id]
    if not request then
        return
    end
    state.pending[event.id] = nil
    local batch = state.batches[request.batch_id]
    if not batch or batch.done then
        return
    end
    batch.outstanding = math_max(0, batch.outstanding - 1)
    state.stats.completed = state.stats.completed + 1
    if event.try_again_later then
        state.stats.try_again_later = state.stats.try_again_later + 1
    elseif event.path and batch.unit and batch.unit.valid then
        local score = score_path_damage_ticks(batch.unit.surface, event.path, {
            unit = batch.unit,
            enemy_force = batch.enemy_force,
            turrets = batch.turrets,
            source = batch.source_position,
            start = request.start,
            goal = request.goal,
            blitz_mode = batch.blitz_mode,
        })
        if score < batch.best_damage then
            batch.best_damage = score
            batch.best_waypoints = #event.path
            batch.best_start = request.start
        end
    end
    if batch.outstanding == 0 then
        finalize_batch(state, batch)
    end
end

function Public.dispatch(unit_group, unit_group_boss, planner_unit, target_force_name, target_position, enemy_force)
    local blitz_enabled = Public.is_blitz_enabled()
    if blitz_enabled and planner_unit and planner_unit.valid then
        local ok = Public.request_least_damage_paths(planner_unit, target_position, enemy_force, nil, {
            blitz_mode = true,
            unit_group = unit_group,
            unit_group_boss = unit_group_boss,
            target_force_name = target_force_name,
            target_position = target_position,
        })
        if ok then
            return true
        end
    end
    local strike_position = Public.calculate_strike_position(unit_group, target_position)
    Public.initiate_pair(
        unit_group,
        unit_group_boss,
        target_force_name,
        strike_position,
        target_position,
        blitz_enabled
    )
    return false
end

local BEHAVIOR_RESULT = {
    [defines.behavior_result.success] = 'success',
    [defines.behavior_result.fail] = 'fail',
    [defines.behavior_result.deleted] = 'deleted',
    [defines.behavior_result.in_progress] = 'in_progress',
}

function Public.step(id, result)
    if storage.bb_game_won_by_team then
        return
    end

    if _DEBUG then
        log('ai: ' .. id .. ' ' .. BEHAVIOR_RESULT[result])
    end
end

return Public
