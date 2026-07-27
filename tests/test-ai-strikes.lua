---@diagnostic disable
local lunatest = require('lunatest')

storage = {
    ['_TEST'] = true,
    bb_settings = {
        blitz_pathfinding = true,
        classic_pathfinding = false,
    },
    rocket_silo = {
        north = {},
        south = {},
    },
}

defines = {
    behavior_result = {
        success = 1,
        fail = 2,
        deleted = 3,
        in_progress = 4,
    },
    command = {
        attack = 1,
        attack_area = 2,
        compound = 3,
        go_to_location = 4,
        wander = 5,
    },
    compound_command = {
        logical_and = 1,
        return_last = 2,
    },
    distraction = {
        by_damage = 1,
        by_enemy = 2,
    },
    events = {
        on_unit_removed_from_group = 1,
    },
}

function table_size(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

package.loaded['maps.biter_battles_v2.ai_targets'] = {
    get_random_target = function()
        return nil
    end,
}
package.loaded['utils.event'] = {
    add = function() end,
}
package.loaded['maps.biter_battles_v2.config'] = {
    border_river_width = 44,
}
package.loaded['utils.force'] = {
    get_player_force_name = function()
        return 'north'
    end,
}
package.loaded['comfy_panel.special_games.multi_silo'] = {
    is_disabled = function()
        return true
    end,
}
package.loaded['utils.table'] = {
    shuffle_indices = function(list)
        local indices = {}
        for i = 1, #list do
            indices[i] = i
        end
        return indices
    end,
}

local requests = {}
local next_request_id = 0
local entities = {}
local surface = {
    index = 1,
    valid = true,
}

function surface.request_path(parameters)
    next_request_id = next_request_id + 1
    requests[next_request_id] = parameters
    return next_request_id
end

function surface.find_entities_filtered()
    return entities
end

function surface.find_non_colliding_position(_, position)
    return position
end

local last_group_command
local group = {
    valid = true,
    position = { x = 0, y = -700 },
}

function group.set_command(command)
    last_group_command = command
end

game = {
    tick = 100,
    forces = {
        north = { name = 'north' },
    },
    get_surface = function(index)
        if index == surface.index then
            return surface
        end
    end,
}

local AiStrikes = require('maps.biter_battles_v2.ai_strikes')

local function reset_requests()
    requests = {}
    next_request_id = 0
    last_group_command = nil
    storage.ai_blitz = nil
end

function test_existing_advanced_chain_has_no_blitz_wanders()
    local command = AiStrikes._test.build_attack_command_chain('north', { x = 10, y = -300 }, { x = 0, y = -44 }, false)

    lunatest.assert_equal(2, #command.commands)
    lunatest.assert_equal(defines.command.go_to_location, command.commands[1].type)
    lunatest.assert_equal(defines.command.attack_area, command.commands[2].type)
end

function test_blitz_chain_keeps_objective_focused_wanders()
    local command = AiStrikes._test.build_attack_command_chain('north', { x = 10, y = -300 }, { x = 0, y = -44 }, true)

    lunatest.assert_equal(4, #command.commands)
    lunatest.assert_equal(defines.command.wander, command.commands[2].type)
    lunatest.assert_equal(defines.distraction.by_damage, command.commands[2].distraction)
    lunatest.assert_equal(defines.command.wander, command.commands[4].type)
    lunatest.assert_equal(defines.distraction.by_damage, command.commands[4].distraction)
end

function test_turret_snapshot_indexes_nearby_damage()
    entities = {
        {
            valid = true,
            name = 'laser-turret',
            position = { x = 33, y = 0 },
            force = {
                get_turret_attack_modifier = function()
                    return 0
                end,
            },
            prototype = {
                turret_range = 20,
                attack_parameters = {
                    min_range = 0,
                },
            },
        },
    }

    local snapshot = AiStrikes._test.build_turret_snapshot(
        surface,
        { left_top = { x = -32, y = -32 }, right_bottom = { x = 64, y = 32 } },
        game.forces.north
    )

    lunatest.assert_equal(1, snapshot.turret_count)
    lunatest.assert_true(AiStrikes._test.incoming_damage_per_tick_at({ x = 15, y = 0 }, snapshot) > 0)
    lunatest.assert_equal(0, AiStrikes._test.incoming_damage_per_tick_at({ x = 60, y = 0 }, snapshot))
    entities = {}
end

function test_blitz_candidates_are_evenly_spaced_on_one_valid_arc()
    local unit = {
        position = { x = 0, y = -700 },
    }
    local target = { x = 0, y = -44 }
    local starts = AiStrikes._test.calculate_blitz_candidate_starts(unit, target, 8)

    lunatest.assert_equal(8, #starts)
    local previous_chord
    for index, start in ipairs(starts) do
        local target_dx = start.x - target.x
        local target_dy = start.y - target.y
        local radius = math.sqrt(target_dx * target_dx + target_dy * target_dy)
        lunatest.assert_equal(384, radius, 0.000001)
        lunatest.assert_true(start.y <= -22)

        if index > 1 then
            local previous = starts[index - 1]
            local chord_dx = start.x - previous.x
            local chord_dy = start.y - previous.y
            local chord = math.sqrt(chord_dx * chord_dx + chord_dy * chord_dy)
            if previous_chord then
                lunatest.assert_equal(previous_chord, chord, 0.000001)
            else
                lunatest.assert_true(chord > 0)
            end
            previous_chord = chord
        end
    end
end

function test_blitz_pathfinds_ingress_then_egress_for_every_candidate()
    reset_requests()
    local unit = {
        valid = true,
        name = 'small-biter',
        position = { x = 0, y = -700 },
        speed = 0.1,
        surface = surface,
        force = { name = 'north_biters' },
        prototype = {
            collision_box = {
                left_top = { x = -0.2, y = -0.2 },
                right_bottom = { x = 0.2, y = 0.2 },
            },
            collision_mask = { layers = { object = true } },
        },
    }
    local target = { x = 0, y = -44 }
    local batch_id = AiStrikes.request_least_damage_paths(unit, target, game.forces.north, nil, {
        blitz_mode = true,
        max_starts = 2,
        unit_group = group,
        target_force_name = 'north',
        target_position = target,
    })

    lunatest.assert_not_nil(batch_id)
    lunatest.assert_equal(2, #requests)
    for request_id = 1, 2 do
        lunatest.assert_equal(group.position.x, requests[request_id].start.x)
        lunatest.assert_equal(group.position.y, requests[request_id].start.y)
        lunatest.assert_equal(16, requests[request_id].radius)
        AiStrikes.on_script_path_request_finished({
            id = request_id,
            try_again_later = false,
            path = {
                {
                    position = requests[request_id].goal,
                    needs_destroy_to_reach = false,
                },
            },
        })
    end

    lunatest.assert_equal(4, #requests)
    for request_id = 3, 4 do
        lunatest.assert_equal(32, requests[request_id].radius)
        lunatest.assert_equal(target.x, requests[request_id].goal.x)
        lunatest.assert_equal(target.y, requests[request_id].goal.y)
        AiStrikes.on_script_path_request_finished({
            id = request_id,
            try_again_later = false,
            path = {
                {
                    position = target,
                    needs_destroy_to_reach = false,
                },
            },
        })
    end

    local state = AiStrikes.ensure_state()
    lunatest.assert_equal(4, state.stats.requested)
    lunatest.assert_equal(4, state.stats.completed)
    lunatest.assert_equal(0, state.stats.no_path)
    lunatest.assert_equal(0, table_size(state.pending))
    lunatest.assert_true(state.batches[batch_id].done)
    lunatest.assert_not_nil(last_group_command)
end

lunatest.run()
