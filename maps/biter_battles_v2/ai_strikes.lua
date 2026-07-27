local Public = {}

local AiTargets = require('maps.biter_battles_v2.ai_targets')
local Event = require('utils.event')
local bb_config = require('maps.biter_battles_v2.config')
local Force = require('utils.force')
local MultiSilo = require('comfy_panel.special_games.multi_silo')
local Table = require('utils.table')

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
    sample_step_tiles = 4,
    damage_grid_cell_size = 32,
    turret_scan_margin = 128,
    blitz_ingress_radius = 16,
    target_attack_radius = 32,
    ingress_distance_penalty_per_tile = 0.05,
    breaker_probe_radius = 2.0,
    min_speed_tiles_per_tick = 0.02,
    effective_dps_by_turret = {
        ['gun-turret'] = 18,
        ['laser-turret'] = 24,
        ['flamethrower-turret'] = 40,
        ['tesla-turret'] = 35,
    },
    effective_turret_names = {
        'gun-turret',
        'laser-turret',
        'flamethrower-turret',
        'tesla-turret',
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

local function ensure_state()
    storage.ai_blitz = storage.ai_blitz or {}
    local state = storage.ai_blitz
    if not state.max_starts_per_batch then
        state.max_starts_per_batch = 8
    end
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
    return storage.bb_settings and storage.bb_settings.blitz_pathfinding or false
end

local vector_radius = 512
local attack_vectors = {}
attack_vectors.north = {}
attack_vectors.south = {}
--awesomepatrol's pathing  updates
for p = 0.3, 0.71, 0.1 do
    local a = math.pi * p
    local x = vector_radius * math.cos(a)
    local y = vector_radius * math.sin(a)
    attack_vectors.north[#attack_vectors.north + 1] = { x, y * -1 }
    attack_vectors.south[#attack_vectors.south + 1] = { x, y }
end
local size_of_vectors = #attack_vectors.north

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

local function deterministic_strike_distance(source_target_distance)
    local max_distance = math_min(source_target_distance, MAX_STRIKE_DISTANCE)
    return (MIN_STRIKE_DISTANCE + max_distance) / 2
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
    local strike_distance = deterministic_strike_distance(source_target_distance)
    local strike_angle_range = calculate_strike_range(
        source_target_dx,
        source_target_dy,
        source_target_distance,
        STRIKE_TARGET_CLEARANCE,
        strike_distance
    )
    if boundary_offset > normalized_target.y - strike_distance then
        local boundary_angle_range = calculate_boundary_range(boundary_offset, normalized_target, strike_distance)
        strike_angle_range.start = math_max(strike_angle_range.start, boundary_angle_range.start)
        strike_angle_range.finish = math_min(strike_angle_range.finish, boundary_angle_range.finish)
    end
    local magnitude = strike_angle_range.finish - strike_angle_range.start
    if magnitude <= 0 then
        return { { x = source_position.x, y = source_position.y } }
    end

    local point_count = math_max(1, math_floor(max_starts or 1))
    local starts = {}
    for i = 1, point_count, 1 do
        -- Sample the center of each equal angular sector so every candidate is
        -- safely inside the legal arc rather than exactly on a tangent boundary.
        local ratio = (i - 0.5) / point_count
        local strike_angle = strike_angle_range.start + magnitude * ratio
        local point = {
            x = normalized_target.x + strike_distance * math_cos(strike_angle),
            y = normalized_target.y + strike_distance * math_sin(strike_angle),
        }
        if source_position.y < 0 then
            point.y = -point.y
        end
        starts[#starts + 1] = point
    end
    return starts
end

--- Append shuffled silo attack commands to an existing command chain.
--- In multi-silo mode, uses position-based attack_area so the chain
--- survives silo destruction; otherwise targets the silo entity directly.
---@param chain defines.command[] Compound command list to append to.
---@param target_force_name string Force name ('north' or 'south').
---@param distraction defines.distraction Distraction behaviour for the appended commands.
function Public.append_silo_commands(chain, target_force_name, distraction)
    local silos = storage.rocket_silo[target_force_name]
    if not silos then
        return
    end
    local indices = Table.shuffle_indices(silos)
    local multi_silo = not MultiSilo.is_disabled()
    for _, i in ipairs(indices) do
        local silo = silos[i]
        if silo and silo.valid then
            if multi_silo then
                chain[#chain + 1] = {
                    type = defines.command.attack_area,
                    destination = silo.position,
                    radius = 32,
                    distraction = distraction,
                }
            else
                chain[#chain + 1] = {
                    type = defines.command.attack,
                    target = silo,
                    distraction = distraction,
                }
            end
        end
    end
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
        if blitz_mode then
            chain[#chain + 1] = {
                type = defines.command.wander,
                radius = ingress_radius,
                ticks_to_wait = 1,
                distraction = defines.distraction.by_damage,
            }
        end
    end

    chain[#chain + 1] = {
        type = defines.command.attack_area,
        destination = target_position,
        radius = CFG.target_attack_radius,
        distraction = target_distraction,
    }
    if blitz_mode then
        chain[#chain + 1] = {
            type = defines.command.wander,
            radius = CFG.target_attack_radius,
            ticks_to_wait = 1,
            distraction = defines.distraction.by_damage,
        }
    end
    Public.append_silo_commands(chain, target_force_name, defines.distraction.by_damage)

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

---Provides the command chain for a new biter group using classic pathfinding logic, see notes in ai_strikes.lua for an explanation
---of the differences between advanced and classic pathfinding
---This biter group will take a direct path to the target_position using classic attack_vectors in ai_strikes.lua
---@param unit_group LuaCommandable
---@param target_force_name string
---@param target_position MapPosition
function Public.initiate_classic_attack(unit_group, target_force_name, target_position)
    if storage.bb_game_won_by_team then
        return
    end
    if not (unit_group and unit_group.valid and target_position) then
        return
    end

    local chain = {}
    local vector = attack_vectors[target_force_name][math_random(1, size_of_vectors)]
    local distance_modifier = math_random(25, 100) * 0.01

    local position = {
        target_position.x + (vector[1] * distance_modifier),
        target_position.y + (vector[2] * distance_modifier),
    }
    position = unit_group.surface.find_non_colliding_position('stone-furnace', position, 96, 1)
    if position then
        if math_abs(position.y) < math_abs(unit_group.position.y) then
            chain[#chain + 1] = {
                type = defines.command.go_to_location,
                destination = position,
                radius = 32,
                distraction = defines.distraction.by_enemy,
            }
        end
    end

    chain[#chain + 1] = {
        type = defines.command.attack_area,
        destination = target_position,
        radius = 32,
        distraction = defines.distraction.by_enemy,
    }

    Public.append_silo_commands(chain, target_force_name, defines.distraction.by_damage)

    unit_group.set_command({
        type = defines.command.compound,
        structure_type = defines.compound_command.logical_and,
        commands = chain,
    })
end

---Provides the command chain for a new biter group using advanced pathfinding logic, see notes in ai_strikes.lua for an explanation
---of the differences between advanced and classic pathfinding.
---This biter group will travel to the strike_position before attacking the target_position
---@param unit_group LuaCommandable
---@param target_force_name string
---@param strike_position MapPosition
---@param target_position MapPosition
function Public.initiate_advanced_attack(unit_group, target_force_name, strike_position, target_position)
    Public.initiate(unit_group, target_force_name, strike_position, target_position, false)
end

local function vec_sub(a, b)
    return { x = a.x - b.x, y = a.y - b.y }
end

local function vec_len(v)
    return math_sqrt(v.x * v.x + v.y * v.y)
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

local function merge_bbox(first, second)
    return {
        left_top = {
            x = math_min(first.left_top.x, second.left_top.x),
            y = math_min(first.left_top.y, second.left_top.y),
        },
        right_bottom = {
            x = math_max(first.right_bottom.x, second.right_bottom.x),
            y = math_max(first.right_bottom.y, second.right_bottom.y),
        },
    }
end

local function bbox_from_positions(positions, anchor, source)
    local min_x = anchor.x
    local max_x = anchor.x
    local min_y = anchor.y
    local max_y = anchor.y
    if source then
        min_x = math_min(min_x, source.x)
        max_x = math_max(max_x, source.x)
        min_y = math_min(min_y, source.y)
        max_y = math_max(max_y, source.y)
    end
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
    local speed = unit.speed or unit.effective_speed or 0
    if speed <= 0 then
        return CFG.min_speed_tiles_per_tick
    end
    return math_max(speed, CFG.min_speed_tiles_per_tick)
end

local function get_biter_structure_dps(unit_name)
    return CFG.structure_dps_by_biter[unit_name] or 10
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

local function add_turret_to_damage_grid(cells, cell_x, cell_y, turret)
    local column = cells[cell_x]
    if not column then
        column = {}
        cells[cell_x] = column
    end
    local bucket = column[cell_y]
    if not bucket then
        bucket = {}
        column[cell_y] = bucket
    end
    bucket[#bucket + 1] = turret
end

local function build_turret_snapshot(surface, area, enemy_force)
    local entities = surface.find_entities_filtered({
        area = area,
        force = enemy_force,
        name = CFG.effective_turret_names,
    })
    local cell_size = CFG.damage_grid_cell_size
    local cells = {}
    local turret_count = 0
    local max_range = 0
    local profile_by_name = {}
    for _, entity in pairs(entities) do
        if entity.valid then
            local turret_name = entity.name
            local profile = profile_by_name[turret_name]
            if profile == nil then
                local prototype = entity.prototype
                local attack_parameters = prototype and prototype.attack_parameters
                local range = prototype and (prototype.turret_range or (attack_parameters and attack_parameters.range))
                    or 0
                local min_range = attack_parameters and attack_parameters.min_range or 0
                local dps = estimate_turret_damage_per_second(entity)
                if dps > 0 and range > 0 then
                    profile = {
                        range = range,
                        range_squared = range * range,
                        min_range_squared = min_range * min_range,
                        damage_per_tick = dps / 60.0,
                    }
                else
                    profile = false
                end
                profile_by_name[turret_name] = profile
            end
            if profile then
                turret_count = turret_count + 1
                max_range = math_max(max_range, profile.range)
                local position = entity.position
                local turret = {
                    x = position.x,
                    y = position.y,
                    profile = profile,
                }
                add_turret_to_damage_grid(
                    cells,
                    math_floor(position.x / cell_size),
                    math_floor(position.y / cell_size),
                    turret
                )
            end
        end
    end
    return {
        cells = cells,
        cell_size = cell_size,
        max_range = max_range,
        turret_count = turret_count,
    }
end

local function incoming_damage_per_tick_at(position, threat_grid)
    local cell_size = threat_grid.cell_size
    local cell_x = math_floor(position.x / cell_size)
    local cell_y = math_floor(position.y / cell_size)
    local cell_radius = math_ceil(threat_grid.max_range / cell_size)
    local damage_per_tick = 0
    for nearby_x = cell_x - cell_radius, cell_x + cell_radius, 1 do
        local column = threat_grid.cells[nearby_x]
        if column then
            for nearby_y = cell_y - cell_radius, cell_y + cell_radius, 1 do
                local bucket = column[nearby_y]
                if bucket then
                    for _, turret in ipairs(bucket) do
                        local dx = position.x - turret.x
                        local dy = position.y - turret.y
                        local distance_squared = dx * dx + dy * dy
                        local profile = turret.profile
                        if
                            distance_squared <= profile.range_squared
                            and distance_squared >= profile.min_range_squared
                        then
                            damage_per_tick = damage_per_tick + profile.damage_per_tick
                        end
                    end
                end
            end
        end
    end
    return damage_per_tick
end

local function estimate_break_delay_ticks(surface, position, enemy_force, structure_dps)
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
    local dps = math_max(structure_dps, 0.1)
    return best_hp / dps * 60.0
end

local function score_path_damage_ticks(surface, path, meta)
    if not path then
        return math_huge
    end
    local enemy_force = meta.enemy_force
    local threat_grid = meta.threat_grid
    local speed_tiles_per_tick = meta.speed_tiles_per_tick
    local total_damage = 0
    local previous = meta.start
    for i = 1, #path, 1 do
        local waypoint = path[i]
        local current = waypoint.position
        local segment = vec_sub(current, previous)
        local segment_length = vec_len(segment)
        if segment_length > 0 then
            if meta.distance_penalty_per_tile then
                total_damage = total_damage + segment_length * meta.distance_penalty_per_tile
            end
            local sample_count = math_max(1, math_ceil(segment_length / CFG.sample_step_tiles))
            local dt_per_sample = (segment_length / sample_count) / speed_tiles_per_tick
            for s = 1, sample_count, 1 do
                local point = lerp(previous, current, (s - 0.5) / sample_count)
                local damage_per_tick = incoming_damage_per_tick_at(point, threat_grid)
                total_damage = total_damage + damage_per_tick * dt_per_sample
            end
        end
        if waypoint.needs_destroy_to_reach then
            local delay_ticks = estimate_break_delay_ticks(surface, current, enemy_force, meta.structure_dps)
            if delay_ticks > 0 then
                local local_damage_per_tick = incoming_damage_per_tick_at(current, threat_grid)
                total_damage = total_damage + local_damage_per_tick * delay_ticks
            else
                total_damage = total_damage + 50
            end
        end
        previous = current
    end
    return total_damage
end

local function finalize_batch(state, batch)
    batch.done = true
    batch.finished = game.tick
    batch.elapsed_ticks = batch.finished - batch.started
    local strike_position = batch.best_start
    if batch.best_damage == math_huge then
        batch.best_damage = nil
        batch.best_waypoints = 0
        state.stats.no_path = state.stats.no_path + 1
        local fallback_group = batch.unit_group
        if not (fallback_group and fallback_group.valid) then
            fallback_group = batch.unit_group_boss
        end
        if fallback_group and fallback_group.valid then
            strike_position = Public.calculate_strike_position(fallback_group, batch.target_position)
        end
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
    batch.bounding_box = nil
    batch.candidates = nil
    batch.collision_mask = nil
    batch.threat_grid = nil
    batch.unit_group = nil
    batch.unit_group_boss = nil
    local completed_order = state.completed_order
    completed_order[#completed_order + 1] = batch.batch_id
    while #completed_order > state.max_completed_batches do
        local oldest_batch_id = table_remove(completed_order, 1)
        state.batches[oldest_batch_id] = nil
    end
end

local function request_path_leg(state, batch, candidate_index, leg, start_position, goal_position, radius)
    local surface = game.get_surface(batch.surface_index)
    if not surface or not surface.valid then
        return nil
    end
    local request_id = surface.request_path({
        bounding_box = batch.bounding_box,
        collision_mask = batch.collision_mask,
        start = start_position,
        goal = goal_position,
        force = batch.path_force_name,
        radius = radius,
        can_open_gates = true,
        path_resolution_modifier = 0,
        max_gap_size = 0,
        pathfind_flags = {
            cache = false,
            low_priority = true,
            prefer_straight_paths = false,
        },
    })
    if not request_id then
        return nil
    end
    state.pending[request_id] = {
        batch_id = batch.batch_id,
        candidate_index = candidate_index,
        leg = leg,
        start = { x = start_position.x, y = start_position.y },
    }
    batch.outstanding = batch.outstanding + 1
    state.stats.requested = state.stats.requested + 1
    return request_id
end

function Public.request_least_damage_paths(unit, target_position, enemy_force, base_bbox, meta)
    local state = ensure_state()
    if not Public.is_blitz_enabled() then
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
    local command_source = unit
    if meta and meta.unit_group and meta.unit_group.valid then
        command_source = meta.unit_group
    end
    local source_position = { x = command_source.position.x, y = command_source.position.y }
    local route_bbox = bbox_from_positions(starts, target_position, source_position)
    if base_bbox then
        route_bbox = merge_bbox(route_bbox, base_bbox)
    end
    local scan_area = expand_bbox(route_bbox, CFG.turret_scan_margin)
    local threat_grid = build_turret_snapshot(surface, scan_area, enemy)
    local batch_id = state.next_batch_id
    state.next_batch_id = batch_id + 1
    local candidates = {}
    for index, start_position in ipairs(starts) do
        candidates[index] = {
            start = { x = start_position.x, y = start_position.y },
            failed = false,
        }
    end
    local batch = {
        batch_id = batch_id,
        bounding_box = unit.prototype.collision_box,
        candidates = candidates,
        collision_mask = unit.prototype.collision_mask,
        enemy_force_name = enemy.name,
        path_force_name = unit.force.name,
        speed_tiles_per_tick = get_unit_speed_tiles_per_tick(unit),
        structure_dps = get_biter_structure_dps(unit.name),
        surface_index = surface.index,
        threat_grid = threat_grid,
        started = game.tick,
        outstanding = 0,
        best_damage = math_huge,
        best_waypoints = 0,
        best_start = nil,
        done = false,
        source_position = source_position,
        blitz_mode = meta and meta.blitz_mode or false,
        unit_group = meta and meta.unit_group or nil,
        unit_group_boss = meta and meta.unit_group_boss or nil,
        target_force_name = meta and meta.target_force_name or nil,
        target_position = meta and meta.target_position or { x = target_position.x, y = target_position.y },
    }
    state.batches[batch_id] = batch
    for candidate_index, candidate in ipairs(candidates) do
        request_path_leg(
            state,
            batch,
            candidate_index,
            'ingress',
            source_position,
            candidate.start,
            CFG.blitz_ingress_radius
        )
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
    local candidate = batch.candidates[request.candidate_index]
    if not candidate or candidate.failed then
        if batch.outstanding == 0 then
            finalize_batch(state, batch)
        end
        return
    end
    if event.try_again_later then
        state.stats.try_again_later = state.stats.try_again_later + 1
        candidate.failed = true
    elseif event.path then
        local surface = game.get_surface(batch.surface_index)
        if not surface or not surface.valid then
            candidate.failed = true
        else
            local score = score_path_damage_ticks(surface, event.path, {
                enemy_force = batch.enemy_force_name,
                threat_grid = batch.threat_grid,
                speed_tiles_per_tick = batch.speed_tiles_per_tick,
                structure_dps = batch.structure_dps,
                distance_penalty_per_tile = request.leg == 'ingress' and CFG.ingress_distance_penalty_per_tile or nil,
                start = request.start,
            })
            if request.leg == 'ingress' then
                candidate.ingress_score = score
                candidate.ingress_waypoints = #event.path
                local last_waypoint = event.path[#event.path]
                local egress_start = last_waypoint and last_waypoint.position or request.start
                if
                    not request_path_leg(
                        state,
                        batch,
                        request.candidate_index,
                        'egress',
                        egress_start,
                        batch.target_position,
                        CFG.target_attack_radius
                    )
                then
                    candidate.failed = true
                end
            else
                local total_score = candidate.ingress_score + score
                if total_score < batch.best_damage then
                    batch.best_damage = total_score
                    batch.best_waypoints = candidate.ingress_waypoints + #event.path
                    batch.best_start = candidate.start
                end
            end
        end
    else
        candidate.failed = true
    end
    if batch.outstanding == 0 then
        finalize_batch(state, batch)
    end
end

function Public.dispatch(unit_group, unit_group_boss, planner_unit, target_force_name, target_position, enemy_force)
    if storage.bb_settings.classic_pathfinding then
        Public.initiate_classic_attack(unit_group, target_force_name, target_position)
        Public.initiate_classic_attack(unit_group_boss, target_force_name, target_position)
        return false
    end

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
    if not strike_position then
        log('No strike position found for ' .. target_force_name .. '_biters, skipping flank')
    end
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

--- When a biter unit is removed from its group (e.g. the group is disbanded
--- or the unit is separated), this function re-commands the orphaned unit with
--- the group's current command when available, falling back to a freshly built
--- chain targeting a random player structure and the rocket silo.
---@param event LuaOnUnitRemovedFromGroup
local function on_unit_removed_from_group(event)
    if storage.bb_game_won_by_team then
        return
    end

    local unit = event.unit
    if not unit.valid then
        return
    end

    -- BUG: During threat farming with poison capsules, biters form
    -- attack waves that target closest player structures.  This
    -- happens even with negative threat.  If in that period some
    -- biters get orphaned, they will trigger this event and acquire
    -- new command chain, unless we exit early.
    if storage.bb_threat[unit.force.name] < 0 then
        return
    end

    local commandable = unit.commandable
    if not commandable then
        return
    end

    local group = event.group
    if group.valid and group.has_command then
        commandable.set_command(group.command)
        return
    end

    local chain = {}
    local target_force_name = Force.get_player_force_name(unit.force.name)
    local target_position = AiTargets.get_random_target(target_force_name)
    if target_position then
        chain[#chain + 1] = {
            type = defines.command.attack_area,
            destination = target_position,
            radius = 32,
            distraction = defines.distraction.by_enemy,
        }
    end
    Public.append_silo_commands(chain, target_force_name, defines.distraction.by_damage)

    if #chain > 0 then
        commandable.set_command({
            type = defines.command.compound,
            structure_type = defines.compound_command.return_last,
            commands = chain,
        })
    else
        log('unit_removed_from_group: no valid silos to chain for force=' .. target_force_name)
    end
end

Event.add(defines.events.on_unit_removed_from_group, on_unit_removed_from_group)

if storage._TEST then
    Public._test = {
        build_attack_command_chain = build_attack_command_chain,
        build_turret_snapshot = build_turret_snapshot,
        calculate_blitz_candidate_starts = calculate_blitz_candidate_starts,
        incoming_damage_per_tick_at = incoming_damage_per_tick_at,
    }
end

return Public
