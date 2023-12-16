local bb_config = require "maps.biter_battles_v2.config"
local Functions = require "maps.biter_battles_v2.functions"
local Server = require 'utils.server'

local tables = require "maps.biter_battles_v2.tables"
local food_values = tables.food_values
local force_translation = tables.force_translation
local enemy_team_of = tables.enemy_team_of
local math_floor = math.floor
local math_round = math.round

local minimum_modifier = 125
local maximum_modifier = 250
local player_amount_for_maximum_threat_gain = 20
local Public = {}
function get_instant_threat_player_count_modifier()
	local current_player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
	local gain_per_player = (maximum_modifier - minimum_modifier) / player_amount_for_maximum_threat_gain
	local m = minimum_modifier + gain_per_player * current_player_count
	if m > maximum_modifier then m = maximum_modifier end
	return m
end


local function update_boss_modifiers(force_name_biter,damage_mod_mult,speed_mod_mult)
	local damage_mod = math_round((global.bb_evolution[force_name_biter]) * 1.0, 3) * damage_mod_mult
	local speed_mod = math_round((global.bb_evolution[force_name_biter]) *0.25, 3) * speed_mod_mult
	local force = game.forces[force_name_biter .. "_boss"]
	force.set_ammo_damage_modifier("melee", damage_mod) 
	force.set_ammo_damage_modifier("biological", damage_mod)
	force.set_ammo_damage_modifier("artillery-shell", damage_mod)
	force.set_ammo_damage_modifier("flamethrower", damage_mod)
	force.set_gun_speed_modifier("melee", speed_mod)
	force.set_gun_speed_modifier("biological", speed_mod)
	force.set_gun_speed_modifier("artillery-shell", speed_mod)
	force.set_gun_speed_modifier("flamethrower", speed_mod)
end

local function set_biter_endgame_modifiers(force)
	if force.evolution_factor ~= 1 then return end

	-- Calculates reanimation chance. This value is normalized onto
	-- maximum re-animation threshold. For example if real evolution is 150
	-- and max is 350, then 150 / 350 = 42% chance.
	local threshold = global.bb_evolution[force.name]
	threshold = math_floor((threshold - 1.0) * 100.0)
	threshold = threshold / global.max_reanim_thresh * 100
	threshold = math_floor(threshold)
	if threshold > 90.0 then
		threshold = 90.0
	end
	global.reanim_chance[force.index] = threshold

	local damage_mod = math_round((global.bb_evolution[force.name] - 1) * 1.0, 3)
	force.set_ammo_damage_modifier("melee", damage_mod)
	force.set_ammo_damage_modifier("biological", damage_mod)
	force.set_ammo_damage_modifier("artillery-shell", damage_mod)
	force.set_ammo_damage_modifier("flamethrower", damage_mod)
end

local function get_enemy_team_of(team)
	if global.training_mode then
		return team
	else
		return enemy_team_of[team]
	end
end

local function print_feeding_msg(player, food, flask_amount)
	if not get_enemy_team_of(player.force.name) then return end
	
	local n = bb_config.north_side_team_name
	local s = bb_config.south_side_team_name
	if global.tm_custom_name["north"] then n = global.tm_custom_name["north"] end
	if global.tm_custom_name["south"] then s = global.tm_custom_name["south"] end	
	local team_strings = {
		["north"] = table.concat({"[color=120, 120, 255]", n, "'s[/color]"}),
		["south"] = table.concat({"[color=255, 65, 65]", s, "'s[/color]"})
	}
	
	local colored_player_name = table.concat({"[color=", player.color.r * 0.6 + 0.35, ",", player.color.g * 0.6 + 0.35, ",", player.color.b * 0.6 + 0.35, "]", player.name, "[/color]"})
	local formatted_food = table.concat({"[color=", food_values[food].color, "]", food_values[food].name, " juice[/color]", "[img=item/", food, "]"})
	local formatted_amount = table.concat({"[font=heading-1][color=255,255,255]" .. flask_amount .. "[/color][/font]"})
	
	if flask_amount >= 20 then
		local enemy = get_enemy_team_of(player.force.name)
		game.print(table.concat({colored_player_name, " fed ", formatted_amount, " flasks of ", formatted_food, " to team ", team_strings[enemy], " biters!"}), {r = 0.9, g = 0.9, b = 0.9})
		Server.to_discord_bold(table.concat({player.name, " fed ", flask_amount, " flasks of ", food_values[food].name, " to team ", enemy, " biters!"}))
	else
		local target_team_text = "the enemy"
		if global.training_mode then
			target_team_text = "your own"
		end
		if flask_amount == 1 then
			player.print("You fed one flask of " .. formatted_food .. " to " .. target_team_text .. " team's biters.", {r = 0.98, g = 0.66, b = 0.22})
		else
			player.print("You fed " .. formatted_amount .. " flasks of " .. formatted_food .. " to " .. target_team_text .. " team's biters.", {r = 0.98, g = 0.66, b = 0.22})
		end				
	end	
end

local function add_stats(player, food, flask_amount,biter_force_name,evo_before_science_feed,threat_before_science_feed)
	local colored_player_name = table.concat({"[color=", player.color.r * 0.6 + 0.35, ",", player.color.g * 0.6 + 0.35, ",", player.color.b * 0.6 + 0.35, "]", player.name, "[/color]"})
	local formatted_food = table.concat({"[color=", food_values[food].color, "][/color]", "[img=item/", food, "]"})
	local formatted_amount = table.concat({"[font=heading-1][color=255,255,255]" .. flask_amount .. "[/color][/font]"})	
	local n = bb_config.north_side_team_name
	local s = bb_config.south_side_team_name
	if global.tm_custom_name["north"] then n = global.tm_custom_name["north"] end
	if global.tm_custom_name["south"] then s = global.tm_custom_name["south"] end
	local team_strings = {
		["north"] = table.concat({"[color=120, 120, 255]", n, "[/color]"}),
		["south"] = table.concat({"[color=255, 65, 65]", s, "[/color]"})
	}
	if flask_amount > 0 then
		local tick = game.ticks_played
		local feed_time_mins = math_round(tick / (60*60), 0)
		local minute_unit = ""
		if feed_time_mins <= 1 then
			minute_unit = "min"
		else
			minute_unit = "mins"
		end
		
		local shown_feed_time_hours = ""
		local shown_feed_time_mins = ""
		shown_feed_time_mins = feed_time_mins .. minute_unit
		local formatted_feed_time = shown_feed_time_hours .. shown_feed_time_mins
		evo_before_science_feed = math_round(evo_before_science_feed*100,1) 
		threat_before_science_feed = math_round(threat_before_science_feed,0) 
		local formatted_evo_after_feed = math_round(global.bb_evolution[biter_force_name]*100,1)
		local formatted_threat_after_feed = math_round(global.bb_threat[biter_force_name],0)
		local evo_jump = table.concat({evo_before_science_feed .. " to " .. formatted_evo_after_feed})
		local threat_jump = table.concat({threat_before_science_feed .. " to ".. formatted_threat_after_feed})
		local evo_jump_difference =  math_round(formatted_evo_after_feed - evo_before_science_feed,1)
		local threat_jump_difference =  math_round(formatted_threat_after_feed - threat_before_science_feed,0)
		local line_log_stats_to_add = table.concat({ formatted_amount .. " " .. formatted_food .. " by " .. colored_player_name .. " to " })
		local team_name_fed_by_science = get_enemy_team_of(player.force.name)
		
		if global.science_logs_total_north == nil then
			global.science_logs_total_north = { 0 }
			global.science_logs_total_south = { 0 }
			for _ = 1, 7 do
				table.insert(global.science_logs_total_north, 0)
				table.insert(global.science_logs_total_south, 0)
			end
		end
		
		local total_science_of_player_force = nil
		if player.force.name == "north" then
			total_science_of_player_force  = global.science_logs_total_north
		else
			total_science_of_player_force  = global.science_logs_total_south
		end
		
		local indexScience = tables.food_long_to_short[food].indexScience
		total_science_of_player_force[indexScience] = total_science_of_player_force[indexScience] + flask_amount
		
		if global.science_logs_text then
			table.insert(global.science_logs_date,1, formatted_feed_time)
			table.insert(global.science_logs_text,1, line_log_stats_to_add)
			table.insert(global.science_logs_evo_jump,1, evo_jump)
			table.insert(global.science_logs_evo_jump_difference,1, evo_jump_difference)
			table.insert(global.science_logs_threat,1, threat_jump)
			table.insert(global.science_logs_threat_jump_difference,1, threat_jump_difference)
			table.insert(global.science_logs_fed_team,1, team_name_fed_by_science)
			table.insert(global.science_logs_food_name,1, food)
		else
			global.science_logs_date = { formatted_feed_time }
			global.science_logs_text = { line_log_stats_to_add }
			global.science_logs_evo_jump = { evo_jump }
			global.science_logs_evo_jump_difference = { evo_jump_difference }
			global.science_logs_threat = { threat_jump }
			global.science_logs_threat_jump_difference = { threat_jump_difference }
			global.science_logs_fed_team = { team_name_fed_by_science }
			global.science_logs_food_name = { food }
		end
	end
end

function set_evo_and_threat(flask_amount, food, biter_force_name)
	local decimals = 9
	
	local instant_threat_player_count_modifier = get_instant_threat_player_count_modifier()
	
	local food_value = food_values[food].value * global.difficulty_vote_value

	local evo = global.bb_evolution[biter_force_name]
	local biter_evo = game.forces[biter_force_name].evolution_factor
	local threat = 0.0
	
	for _ = 1, flask_amount, 1 do
		---SET EVOLUTION
		local e2 = (biter_evo * 100) + 1
		local diminishing_modifier = (1 / (10 ^ (e2 * 0.015))) / (e2 * 0.5)
		local evo_gain = (food_value * diminishing_modifier)
		evo = evo + evo_gain
		if evo <= 1 then
			biter_evo = evo
		else
			biter_evo = 1
		end
		
		--ADD INSTANT THREAT
		local diminishing_modifier = 1 / (0.2 + (e2 * 0.016))
		threat = threat + (food_value * instant_threat_player_count_modifier * diminishing_modifier)
	end
	evo = math_round(evo, decimals)
	
	--SET THREAT INCOME
	global.bb_threat_income[biter_force_name] = evo * 25
	
	game.forces[biter_force_name].evolution_factor = biter_evo
	global.bb_evolution[biter_force_name] = evo
	set_biter_endgame_modifiers(game.forces[biter_force_name])
	
	if evo > 1 then
		update_boss_modifiers(biter_force_name, 2,1)
	end
	if evo > 3.3 then -- 330% evo => 3.3
		global.max_group_size[biter_force_name] = 50
	elseif evo > 2.3 then
		global.max_group_size[biter_force_name] = 75
	elseif evo > 1.3 then  
		global.max_group_size[biter_force_name] = 100
	elseif evo > 0.7 then 
		global.max_group_size[biter_force_name] = 200
	end
	
	-- Adjust threat for revive.
	-- Note that the fact that this is done at the end, after set_biter_endgame_modifiers
	-- (which updated reanim_chance), is what gives a bonus to large single throws of
	-- science rather than many smaller throws (in the case where final evolution is above
	-- 100%). Specifically, all of the science thrown gets the threat increase that would
	-- be used for the final evolution value.
	local force_index = game.forces[biter_force_name].index
	local reanim_chance = global.reanim_chance[force_index]
	if reanim_chance ~= nil and reanim_chance > 0 then
		threat = threat * (100 / (100.001 - reanim_chance))
	end
	global.bb_threat[biter_force_name] = math_round(global.bb_threat[biter_force_name] + threat, decimals)
	
	if global.active_special_games["shared_science_throw"] then
		local enemyBitersForceName = enemy_team_of[force_translation[biter_force_name]] .. "_biters"
		game.forces[enemyBitersForceName].evolution_factor = game.forces[biter_force_name].evolution_factor
		global.bb_evolution[enemyBitersForceName] = global.bb_evolution[biter_force_name]
		global.bb_threat_income[enemyBitersForceName] = global.bb_threat_income[biter_force_name]
		global.bb_threat[enemyBitersForceName] = math_round(global.bb_threat[enemyBitersForceName] + threat, decimals)
	end
end

function Public.feed_biters(player, food)	
		if game.ticks_played < global.difficulty_votes_timeout then
		player.print("Please wait for voting to finish before feeding")
		return
	end

	local enemy_force_name = get_enemy_team_of(player.force.name)  ---------------
	--enemy_force_name = player.force.name
	
	local biter_force_name = enemy_force_name .. "_biters"
	
	local i = player.get_main_inventory()
	local flask_amount = i.get_item_count(food)
	if flask_amount == 0 then
		player.print("You have no " .. food_values[food].name .. " flask in your inventory.", {r = 0.98, g = 0.66, b = 0.22})
		return
	end
	
	i.remove({name = food, count = flask_amount})
	
	print_feeding_msg(player, food, flask_amount)	
	local evolution_before_feed = global.bb_evolution[biter_force_name]
	local threat_before_feed = global.bb_threat[biter_force_name]						
	
	set_evo_and_threat(flask_amount, food, biter_force_name)
	
	add_stats(player, food, flask_amount ,biter_force_name, evolution_before_feed, threat_before_feed)
	
	if (food == "space-science-pack") then
		global.spy_fish_timeout[player.force.name] = game.tick + 99999999
	end
end

function Public.feed_biters_mixed(player, button)
	if game.ticks_played < global.difficulty_votes_timeout then
		player.print("Please wait for voting to finish before feeding")
		return
	end
	local enemy_force_name = get_enemy_team_of(player.force.name)
	local biter_force_name = enemy_force_name .. "_biters"
	local food = {
		"automation-science-pack",
		"logistic-science-pack",
		"military-science-pack",
		"chemical-science-pack",
		"production-science-pack",
		"utility-science-pack",
		"space-science-pack"
	}
	if button == defines.mouse_button_type.right then
		food = {
			"space-science-pack",
			"utility-science-pack",
			"production-science-pack",
			"chemical-science-pack",
			"military-science-pack",
			"logistic-science-pack",
			"automation-science-pack",
		}
	end
	local i = player.get_main_inventory()
	local colored_player_name = table.concat({"[color=", player.color.r * 0.6 + 0.35, ",", player.color.g * 0.6 + 0.35, ",", player.color.b * 0.6 + 0.35, "]", player.name, "[/color]"})
	local message = {colored_player_name, " fed "}
	for k, v in pairs(food) do
		local evolution_before_feed = global.bb_evolution[biter_force_name]
		local threat_before_feed = global.bb_threat[biter_force_name]	
		local flask_amount = i.get_item_count(v)
		if flask_amount ~= 0 then
			table.insert(message, "[font=heading-1][color=255,255,255]" .. flask_amount .. "[/color][/font]" .. "[img=item." .. v .. "], ")
			Server.to_discord_bold(table.concat({player.name, " fed ", flask_amount, " flasks of ", food_values[v].name, " to team ", enemy_force_name, " biters!"}))
			set_evo_and_threat(flask_amount, v, biter_force_name)
			add_stats(player, v, flask_amount ,biter_force_name, evolution_before_feed, threat_before_feed)
			i.remove({name = v, count = flask_amount})
		end
	end
	if #message == 2 then
		player.print("You have no flasks in your inventory", {r = 0.98, g = 0.66, b = 0.22})
		return
	end
	local n = bb_config.north_side_team_name
	local s = bb_config.south_side_team_name
	if global.tm_custom_name["north"] then n = global.tm_custom_name["north"] end
	if global.tm_custom_name["south"] then s = global.tm_custom_name["south"] end	
	local team_strings = {
		["north"] = table.concat({"[color=120, 120, 255]", n, "'s[/color]"}),
		["south"] = table.concat({"[color=255, 65, 65]", s, "'s[/color]"})
	}
	table.insert(message, "to team " .. team_strings[enemy_force_name] .. " biters!")
	game.print(table.concat(message), {r = 0.9, g = 0.9, b = 0.9})
end

return Public
