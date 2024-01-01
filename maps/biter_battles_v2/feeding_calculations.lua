local Public = {}

local function get_instant_threat_player_count_modifier(current_player_count)
	local minimum_modifier = 125
	local maximum_modifier = 250
	local player_amount_for_maximum_threat_gain = 20
	local gain_per_player = (maximum_modifier - minimum_modifier) / player_amount_for_maximum_threat_gain
	local m = minimum_modifier + gain_per_player * current_player_count
	return math.min(m, maximum_modifier)
end

function Public.calc_feed_effects(initial_evo, food_value, num_flasks, current_player_count)
	local threat_increase = 0
	local evo = initial_evo
	for _ = 1, num_flasks, 1 do
		local clamped_evo = math.min(evo, 1)
		---SET EVOLUTION
		local e2 = (clamped_evo * 100) + 1
		local diminishing_modifier = (1 / (10 ^ (e2 * 0.015))) / (e2 * 0.5)
		local evo_gain = (food_value * diminishing_modifier)
		evo = evo + evo_gain

		--ADD INSTANT THREAT
		local diminishing_modifier = 1 / (0.2 + (e2 * 0.016))
		threat_increase = threat_increase + (food_value * diminishing_modifier)
	end

	threat_increase = threat_increase * get_instant_threat_player_count_modifier(current_player_count)
	return {evo_increase = evo - initial_evo, threat_increase = threat_increase}
end

return Public
