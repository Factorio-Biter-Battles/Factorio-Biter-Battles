local math_floor = math.floor

local Public = {}

local function get_instant_threat_player_count_modifier(current_player_count)
	local minimum_modifier = 125
	local maximum_modifier = 250
	local player_amount_for_maximum_threat_gain = 20
	local gain_per_player = (maximum_modifier - minimum_modifier) / player_amount_for_maximum_threat_gain
	local m = minimum_modifier + gain_per_player * current_player_count
	return math.min(m, maximum_modifier)
end

function Public.calc_feed_effects(initial_evo, food_value, num_flasks, current_player_count, max_reanim_thresh)
	local threat = 0
	local evo = initial_evo
	local food = food_value * num_flasks
	while food > 0 do
		local clamped_evo = math.min(evo, 1)
		---SET EVOLUTION
		local e2 = (clamped_evo * 100) + 1
		local diminishing_modifier = (1 / (10 ^ (e2 * 0.015))) / (e2 * 0.5)
		local amount_of_food_this_iteration
		if evo >= 1 then
			-- Everything is linear after evo=1.0, so we can just feed everything at once.
			amount_of_food_this_iteration = food
		else
			local max_evo_gain_per_iteration = 0.01
			amount_of_food_this_iteration = math.min(food, max_evo_gain_per_iteration / diminishing_modifier)
		end
		local evo_gain = (amount_of_food_this_iteration * diminishing_modifier)
		evo = evo + evo_gain

		--ADD INSTANT THREAT
		local diminishing_modifier = 1 / (0.2 + (e2 * 0.016))
		threat = threat + (amount_of_food_this_iteration * diminishing_modifier)

		food = food - amount_of_food_this_iteration
	end
	-- Calculates reanimation chance. This value is normalized onto
	-- maximum re-animation threshold. For example if real evolution is 150
	-- and max is 350, then 150 / 350 = 42% chance.
	local reanim_chance = math_floor(math.max(evo - 1.0, 0) * 100.0)
	reanim_chance = reanim_chance / max_reanim_thresh * 100
	reanim_chance = math.min(math_floor(reanim_chance), 90.0)

	threat = threat * get_instant_threat_player_count_modifier(current_player_count)
	-- Adjust threat for revive.
	-- Note that the fact that this is done at the end, after reanim_chance is calculated
	-- is what gives a bonus to large single throws of science rather than many smaller
	-- throws (in the case where final evolution is above 100%). Specifically, all of the
	-- science thrown gets the threat increase that would be used for the final evolution
	-- value.
	if reanim_chance > 0 then
		threat = threat * (100 / (100.001 - reanim_chance))
	end

	return {
		evo_increase = evo - initial_evo,
		threat_increase = threat,
		reanim_chance = reanim_chance
	}
end

return Public
