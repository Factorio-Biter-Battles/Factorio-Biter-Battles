local lunatest = require "lunatest"
bit32 = require "bit32"
serpent = require "serpent"

local Functions = require "maps.biter_battles_v2.functions"
local Tables = require "maps.biter_battles_v2.tables"

local function effects_str(effects)
	return string.format("evo_increase: %.3f threat: %.0f", effects.evo_increase, effects.threat_increase)
end

function test_feed_effects_1()
	-- Simple early-game send
	local difficulty = 25
	local current_player_count = 4
	local evo = 0.01
	local num_flasks = 100
	local flask_food_value = Tables.food_values["logistic-science-pack"].value * difficulty / 100
	local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count)
	lunatest.assert_equal("evo_increase: 0.029 threat: 33", effects_str(calc))
end

function test_feed_effects_2()
	-- Simple FnF send
	local difficulty = 500
	local current_player_count = 4
	local evo = 0.15
	local num_flasks = 100
	local flask_food_value = Tables.food_values["automation-science-pack"].value * difficulty / 100
	local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count)
	lunatest.assert_equal("evo_increase: 0.028 threat: 141", effects_str(calc))
end

function test_feed_effects_3()
	-- Big yellow rush send to push above 90%
	local difficulty = 30
	local current_player_count = 4
	local evo = 0.25
	local num_flasks = 4500
	local flask_food_value = Tables.food_values["utility-science-pack"].value * difficulty / 100
	local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count)
	lunatest.assert_equal("evo_increase: 0.656 threat: 24225", effects_str(calc))
end

function test_feed_effects_4()
	-- Huge/stalling mega send in a captains game
	local difficulty = 35
	local current_player_count = 40
	local evo = 0.30
	local num_flasks = 23000
	local flask_food_value = Tables.food_values["space-science-pack"].value * difficulty / 100
	local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count)
	lunatest.assert_equal("evo_increase: 2.929 threat: 564978", effects_str(calc))
end

function test_feed_effects_5()
	-- Late game rocket push send
	local difficulty = 40
	local current_player_count = 4
	local evo = 1.20
	local num_flasks = 3000
	local flask_food_value = Tables.food_values["space-science-pack"].value * difficulty / 100
	local calc = Functions.calc_feed_effects(evo, flask_food_value, num_flasks, current_player_count)
	lunatest.assert_equal("evo_increase: 0.363 threat: 49559", effects_str(calc))
end

local function feed_split_up(evo, total_flasks, flask_food_value, num_splits)
	local flasks_per_split = total_flasks / num_splits
	lunatest.assert_equal(math.floor(flasks_per_split), flasks_per_split)
	local current_player_count = 4
	local threat = 0
	for i = 1, num_splits, 1 do
		local calc = Functions.calc_feed_effects(evo, flask_food_value, total_flasks / num_splits, current_player_count)
		evo = evo + calc.evo_increase
		threat = threat + calc.threat_increase
	end
	return {evo = evo, threat = threat}
end

function test_split_up_feed()
	-- test demonstrating that splitting up a send into multiple smaller sends gives a
	-- smaller total threat increase (this is a worst-case scenario)
	evo = 1.0
	num_flasks = 20000
	difficulty = 30
	flask_food_value = Tables.food_values["space-science-pack"].value * difficulty / 100
	local big_send = feed_split_up(evo, num_flasks, flask_food_value, 1)
	local many_send = feed_split_up(evo, num_flasks, flask_food_value, 10)
	lunatest.assert_equal(big_send.evo, many_send.evo, 0.00001, "evo")
	-- Right now, this is true because we haven't put the revive-chance scaling into the
	-- threat calculation. I'll fix that in the next commit.
	lunatest.assert_equal(big_send.threat, many_send.threat, 0.1, "threat")
	print("big_send: ", serpent.block(big_send))
end

lunatest.run()
