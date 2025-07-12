---@diagnostic disable
local lunatest = require('lunatest')
bit32 = require('bit32')
serpent = require('serpent')

local Functions = require('maps.biter_battles_v2.feeding_calculations')
local Tables = require('maps.biter_battles_v2.tables')

local max_reanim_thresh = 250

local function effects_str(effects)
    return string.format('evo_increase: %.3f threat: %.0f', effects.evo_increase, effects.threat_increase)
end

function test_feed_effects_1()
    -- Simple early-game send
    local difficulty = 25
    local current_player_count = 4
    local evo = 0.01
    local num_flasks = 100
    local flask_food_value = Tables.food_values['logistic-science-pack'].value * difficulty / 100
    local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count, max_reanim_thresh)
    lunatest.assert_equal('evo_increase: 0.032 threat: 34', effects_str(calc))
end

function test_feed_effects_2()
    -- Simple FnF send
    local difficulty = 500
    local current_player_count = 4
    local evo = 0.15
    local num_flasks = 100
    local flask_food_value = Tables.food_values['automation-science-pack'].value * difficulty / 100
    local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count, max_reanim_thresh)
    lunatest.assert_equal('evo_increase: 0.029 threat: 143', effects_str(calc))
end

function test_feed_effects_3()
    -- Big yellow rush send to push above 90%
    local difficulty = 30
    local current_player_count = 4
    local evo = 0.25
    local num_flasks = 4500
    local flask_food_value = Tables.food_values['utility-science-pack'].value * difficulty / 100
    local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count, max_reanim_thresh)
    lunatest.assert_equal('evo_increase: 0.726 threat: 31373', effects_str(calc))
end

function test_feed_effects_4()
    -- Huge/stalling mega send in a captains game
    local difficulty = 35
    local current_player_count = 40
    local evo = 0.30
    local num_flasks = 23000
    local flask_food_value = Tables.food_values['space-science-pack'].value * difficulty / 100
    local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count, max_reanim_thresh)
    lunatest.assert_equal('evo_increase: 2.629 threat: 1884441', effects_str(calc))
end

function test_feed_effects_5()
    -- Late game rocket push send
    local difficulty = 40
    local current_player_count = 4
    local evo = 1.20
    local num_flasks = 3000
    local flask_food_value = Tables.food_values['space-science-pack'].value * difficulty / 100
    local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count, max_reanim_thresh)
    lunatest.assert_equal('evo_increase: 0.318 threat: 97441', effects_str(calc))
end

local function feed_split_up(evo, total_flasks, flask_food_value, num_splits)
    local flasks_per_split = total_flasks / num_splits
    lunatest.assert_equal(math.floor(flasks_per_split), flasks_per_split)
    local current_player_count = 4
    local threat = 0
    for i = 1, num_splits, 1 do
        local calc = Functions.calc_feed_effects(
            evo,
            flask_food_value,
            total_flasks / num_splits,
            current_player_count,
            max_reanim_thresh
        )
        evo = evo + calc.evo_increase
        threat = threat + calc.threat_increase
    end
    return { evo = evo, threat = threat }
end

function test_split_up_feed()
    -- test demonstrating that splitting up a send into multiple smaller sends gives
    -- identical total threat increase (this did not used to be the case)
    local evo = 1.0
    local difficulty = 30
    local num_flasks = 25000
    local flask_food_value = Tables.food_values['space-science-pack'].value * difficulty / 100

    local big_send = feed_split_up(evo, num_flasks, flask_food_value, 1)
    local many_send = feed_split_up(evo, num_flasks, flask_food_value, 10)
    -- same evolution increase
    lunatest.assert_equal(big_send.evo, many_send.evo, 0.00001, 'evo')
    -- same threat increase (within 2%)
    lunatest.assert_equal(big_send.threat, many_send.threat, big_send.threat / 50, 'threat')
end

function test_calc_send()
    local player_count = 4
    local player = nil
    local training_mode = false
    local difficulty_vote_value = 0.3
    local bb_evolution = { ['north_biters'] = 0.40, ['south_biters'] = 0.90 }

    lunatest.assert_match(
        'Invalid parameter: "foo"',
        Functions.calc_send_command(
            'foo',
            difficulty_vote_value,
            bb_evolution,
            max_reanim_thresh,
            training_mode,
            player_count,
            player
        )
    )
    lunatest.assert_equal(
        '/calc-send evo=20.0 difficulty=30 players=4 color=logistic-science-pack count=1000\n'
            .. 'evo_increase: 2.9 new_evo: 22.9\n'
            .. 'threat_increase: 187',
        Functions.calc_send_command(
            'evo=20 color=green count=1000',
            difficulty_vote_value,
            bb_evolution,
            max_reanim_thresh,
            training_mode,
            player_count,
            player
        )
    )
end

lunatest.run()
