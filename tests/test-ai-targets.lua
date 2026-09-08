---@diagnostic disable
local lunatest = require('lunatest')

storage = {
    ['_TEST'] = true,
    target_entity_type = { ['rocket-silo'] = true },
    ai_targets = {
        north = {
            available = {},
            available_list = {},
        },
        south = {
            available = { [1] = 1 },
            available_list = {
                { id = 1, position = { x = 10, y = 20 } },
            },
        },
        unindexed = {
            available = { [2] = 1 },
            available_list = {
                { id = 2, position = { x = 30, y = 40 }, unit_number = 99 },
            },
        },
    },
    ai_target_destroyed_map = { [1] = 'south', [2] = 'unindexed' },
}

defines = { events = { on_object_destroyed = 1 } }
game = {
    get_entity_by_unit_number = function()
        return nil
    end,
}
script = {
    on_event = function() end,
    register_on_object_destroyed = function()
        return 1, 42, 1
    end,
}

local AiTargets = require('maps.biter_battles_v2.ai_targets')

function test_position_only_target_entries_remain_attackable()
    local target = AiTargets.get_random_target('south')
    lunatest.assert_not_nil(target)
    lunatest.assert_equal(10, target.x)
    lunatest.assert_equal(20, target.y)
    lunatest.assert_equal(1, #storage.ai_targets.south.available_list)
end

function test_missing_force_targets_return_nil()
    lunatest.assert_nil(AiTargets.get_random_target('missing'))
end

function test_target_selection_does_not_require_get_by_unit_number_prototype_flag()
    local target = AiTargets.get_random_target('unindexed')
    lunatest.assert_not_nil(target)
    lunatest.assert_equal(30, target.x)
    lunatest.assert_equal(40, target.y)
    lunatest.assert_equal(1, #storage.ai_targets.unindexed.available_list)
end

function test_tracking_the_same_entity_twice_is_idempotent()
    local entity = {
        valid = true,
        type = 'rocket-silo',
        unit_number = 42,
        force = { name = 'north' },
        position = { x = -5, y = -10 },
    }

    AiTargets.start_tracking(entity)
    AiTargets.start_tracking(entity)

    lunatest.assert_equal(1, #storage.ai_targets.north.available_list)
    lunatest.assert_equal(1, storage.ai_targets.north.available[42])
    lunatest.assert_equal('north', storage.ai_target_destroyed_map[42])
end

lunatest.run()
