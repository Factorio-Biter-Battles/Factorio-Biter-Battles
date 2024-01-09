local Tables = require "maps.biter_battles_v2.tables"
local bb_config = require "maps.biter_battles_v2.config"
local simplex_noise = require 'utils.simplex_noise'.d2
local string_sub = string.sub
local math_random = math.random
local math_round = math.round
local math_abs = math.abs
local math_min = math.min
local math_floor = math.floor
local string_find = string.find
local gui_style = require 'utils.utils'.gui_style

-- Only add upgrade research balancing logic in this section
-- All values should be in tables.lua
local function proj_buff(current_value,force_name)
	if not global.combat_balance[force_name].bullet then global.combat_balance[force_name].bullet = get_ammo_modifier("bullet") end
	global.combat_balance[force_name].bullet = global.combat_balance[force_name].bullet + current_value
	game.forces[force_name].set_ammo_damage_modifier("bullet", global.combat_balance[force_name].bullet)
end
local function laser_buff(current_value,force_name)
		if not global.combat_balance[force_name].laser_damage then global.combat_balance[force_name].laser_damage = get_turret_attack_modifier("laser-turret") end
		global.combat_balance[force_name].laser_damage = global.combat_balance[force_name].laser_damage + current_value - get_upgrade_modifier("laser-turret")
		game.forces[force_name].set_turret_attack_modifier("laser-turret", current_value)	
end
local function flamer_buff(current_value_ammo,current_value_turret,force_name)
		if not global.combat_balance[force_name].flame_damage then global.combat_balance[force_name].flame_damage = get_ammo_modifier("flamethrower") end
		global.combat_balance[force_name].flame_damage = global.combat_balance[force_name].flame_damage + current_value_ammo - get_upgrade_modifier("flamethrower")
		game.forces[force_name].set_ammo_damage_modifier("flamethrower", global.combat_balance[force_name].flame_damage)
		
		if not global.combat_balance[force_name].flamethrower_damage then global.combat_balance[force_name].flamethrower_damage = get_turret_attack_modifier("flamethrower-turret") end
		global.combat_balance[force_name].flamethrower_damage = global.combat_balance[force_name].flamethrower_damage +current_value_turret - get_upgrade_modifier("flamethrower-turret")
		game.forces[force_name].set_turret_attack_modifier("flamethrower-turret", global.combat_balance[force_name].flamethrower_damage)	
end
local balance_functions = {
	["refined-flammables"] = function(force_name)
		flamer_buff(get_upgrade_modifier("flamethrower")*2,get_upgrade_modifier("flamethrower-turret")*2,force_name)
	end,
	["refined-flammables-1"] = function(force_name)
		flamer_buff(0.06,0.06,force_name)
	end,
	["refined-flammables-2"] = function(force_name)
		flamer_buff(0.06,0.06,force_name)
	end,
	["refined-flammables-3"] = function(force_name)
		flamer_buff(0.06,0.06,force_name)
	end,
	["refined-flammables-4"] = function(force_name)
		flamer_buff(0.06,0.06,force_name)
	end,
	["refined-flammables-5"] = function(force_name)
		flamer_buff(0.06,0.06,force_name)
	end,
	["refined-flammables-6"] = function(force_name)
		flamer_buff(0.06,0.06,force_name)
	end,
	["refined-flammables-7"] = function(force_name)
		flamer_buff(0.06,0.06,force_name)
	end,
	["energy-weapons-damage"] = function(force_name)
		laser_buff(get_upgrade_modifier("laser-turret")*2,force_name)
	end,
	["energy-weapons-damage-1"] = function(force_name)
		laser_buff(0.2,force_name)
	end,
	["energy-weapons-damage-2"] = function(force_name)
		laser_buff(0.2,force_name)
	end,
	["energy-weapons-damage-3"] = function(force_name)
		laser_buff(0.4,force_name)
	end,
	["energy-weapons-damage-4"] = function(force_name)
		laser_buff(0.4,force_name)
	end,
	["energy-weapons-damage-5"] = function(force_name)
		laser_buff(0.4,force_name)
	end,
	["energy-weapons-damage-6"] = function(force_name)
		laser_buff(0.5,force_name)
	end,
	["energy-weapons-damage-7"] = function(force_name)
		laser_buff(0.5,force_name)
	end,
	["stronger-explosives"] = function(force_name)
		if not global.combat_balance[force_name].grenade_damage then global.combat_balance[force_name].grenade_damage = get_ammo_modifier("grenade") end			
		global.combat_balance[force_name].grenade_damage = global.combat_balance[force_name].grenade_damage + get_upgrade_modifier("grenade")
		game.forces[force_name].set_ammo_damage_modifier("grenade", global.combat_balance[force_name].grenade_damage)

		if not global.combat_balance[force_name].land_mine then global.combat_balance[force_name].land_mine = get_ammo_modifier("landmine") end
		global.combat_balance[force_name].land_mine = global.combat_balance[force_name].land_mine + get_upgrade_modifier("landmine")								
		game.forces[force_name].set_ammo_damage_modifier("landmine", global.combat_balance[force_name].land_mine)
	end,
	["stronger-explosives-1"] = function(force_name)
		if not global.combat_balance[force_name].land_mine then global.combat_balance[force_name].land_mine = get_ammo_modifier("landmine") end
		global.combat_balance[force_name].land_mine = global.combat_balance[force_name].land_mine - get_upgrade_modifier("landmine")								
		game.forces[force_name].set_ammo_damage_modifier("landmine", global.combat_balance[force_name].land_mine)
	end,
	["physical-projectile-damage"] = function(force_name)
		if not global.combat_balance[force_name].shotgun then global.combat_balance[force_name].shotgun = get_ammo_modifier("shotgun-shell") end
		global.combat_balance[force_name].shotgun = global.combat_balance[force_name].shotgun + get_upgrade_modifier("shotgun-shell")	
		game.forces[force_name].set_ammo_damage_modifier("shotgun-shell", global.combat_balance[force_name].shotgun)
		game.forces[force_name].set_turret_attack_modifier("gun-turret",0)
	end,
	["physical-projectile-damage-1"] = function(force_name)
		proj_buff(0.3,force_name)
	end,
	["physical-projectile-damage-2"] = function(force_name)
		proj_buff(0.3,force_name)
	end,
	["physical-projectile-damage-3"] = function(force_name)
		proj_buff(0.3,force_name)
	end,
	["physical-projectile-damage-4"] = function(force_name)
		proj_buff(0.3,force_name)
	end,
	["physical-projectile-damage-5"] = function(force_name)
		proj_buff(0.3,force_name)
	end,
	["physical-projectile-damage-6"] = function(force_name)
		proj_buff(0.3,force_name)
	end,
	["physical-projectile-damage-7"] = function(force_name)
		proj_buff(0.3,force_name)
	end,
}

local no_turret_blacklist = {
	["ammo-turret"] = true,
	["artillery-turret"] = true,
	["electric-turret"] = true,
	["fluid-turret"] = true
}

local landfill_biters_vectors = {{0,0}, {1,0}, {0,1}, {-1,0}, {0,-1}}
local landfill_biters = {
	["big-biter"] = true,
	["big-spitter"] = true,
	["behemoth-biter"] = true,	
	["behemoth-spitter"] = true,
}

local spawn_positions = {}
local spawn_r = 7
local spawn_r_square = spawn_r ^ 2
for x = spawn_r * -1, spawn_r, 0.5 do
	for y = spawn_r * -1, spawn_r, 0.5 do
		if x ^ 2 + y ^ 2 < spawn_r_square then
			table.insert(spawn_positions, {x, y})
		end
	end
end
local size_of_spawn_positions = #spawn_positions

local Public = {}

function Public.biters_landfill(entity)
	if not landfill_biters[entity.name] then return end	
	local position = entity.position
	if math_abs(position.y) < 8 then return true end
	local surface = entity.surface
	for _, vector in pairs(landfill_biters_vectors) do
		local tile = surface.get_tile({position.x + vector[1], position.y + vector[2]})
		if tile.collides_with("resource-layer") then
			surface.set_tiles({{name = "landfill", position = tile.position}})
			local particle_pos = {tile.position.x + 0.5, tile.position.y + 0.5}
			for _ = 1, 50, 1 do
				surface.create_particle({
					name = "stone-particle",
					position = particle_pos,
					frame_speed = 0.1,
					vertical_speed = 0.12,
					height = 0.01,
					movement = {-0.05 + math_random(0, 100) * 0.001, -0.05 + math_random(0, 100) * 0.001}
				})
			end
		end
	end
	return true
end

function Public.combat_balance(event)
	local research_name = event.research.name
	local force_name = event.research.force.name		
	local key
	for b = 1, string.len(research_name), 1 do
		key = string_sub(research_name, 0, b)
		if balance_functions[key] then
			if not global.combat_balance[force_name] then global.combat_balance[force_name] = {} end
			balance_functions[key](force_name)
		end
	end
end

function Public.init_player(player)
	if not player.connected then
		if player.force.index ~= 1 then
			player.force = game.forces.player
		end
		return
	end	
		
	if player.character and player.character.valid then
		player.character.destroy()
		player.set_controller({type = defines.controllers.god})
		player.create_character()	
	end
	player.clear_items_inside()
	player.spectator = true
	player.force = game.forces.spectator
	
	local surface = game.surfaces[global.bb_surface_name]
	local p = spawn_positions[math_random(1, size_of_spawn_positions)]
	if surface.is_chunk_generated({0,0}) then
		player.teleport(surface.find_non_colliding_position("character", p, 4, 0.5), surface)
	else
		player.teleport(p, surface)
	end
	if player.character and player.character.valid then player.character.destructible = false end
	game.permissions.get_group("spectator").add_player(player)
end

function Public.get_noise(name, pos)
	local seed = game.surfaces[global.bb_surface_name].map_gen_settings.seed
	local noise_seed_add = 25000
	if name == 1 then
		local noise = simplex_noise(pos.x * 0.0042, pos.y * 0.0042, seed)
		seed = seed + noise_seed_add
		noise = noise + simplex_noise(pos.x * 0.031, pos.y * 0.031, seed) * 0.08
		seed  = seed + noise_seed_add
		noise = noise + simplex_noise(pos.x * 0.1, pos.y * 0.1, seed) * 0.025
		return noise
	end

	if name == 2 then
		local noise = simplex_noise(pos.x * 0.011, pos.y * 0.011, seed)
		seed = seed + noise_seed_add
		noise = noise + simplex_noise(pos.x * 0.08, pos.y * 0.08, seed) * 0.2
		return noise
	end

	if name == 3 then
		local noise = simplex_noise(pos.x * 0.005, pos.y * 0.005, seed)
		noise = noise + simplex_noise(pos.x * 0.02, pos.y * 0.02, seed) * 0.3
		noise = noise + simplex_noise(pos.x * 0.15, pos.y * 0.15, seed) * 0.025
		return noise
	end
end

function Public.is_biter_area(position,noise_Enabled)
	local bitera_area_distance = bb_config.bitera_area_distance * -1
	local biter_area_angle = 0.45
	local a = bitera_area_distance - (math_abs(position.x) * biter_area_angle)
	if position.y - 70 > a then return false end
	if position.y + 70 < a then return true end	
	if noise_Enabled then
		if position.y + (Public.get_noise(3, position) * 64) > a then return false end
	else
		if position.y > a then return false end
	end
	return true
end

function Public.no_turret_creep(event)
	local entity = event.created_entity
	if not entity.valid then return end
	if not no_turret_blacklist[event.created_entity.type] then return end
	
	local posEntity = entity.position
	if posEntity.y > 0 then posEntity.y = (posEntity.y + 100) * -1 end
	if posEntity.y < 0 then posEntity.y = posEntity.y - 100 end
	if not Public.is_biter_area(posEntity,false) then
		return
	end
	
	local surface = event.created_entity.surface				
	local spawners = surface.find_entities_filtered({type = "unit-spawner", area = {{entity.position.x - 70, entity.position.y - 70}, {entity.position.x + 70, entity.position.y + 70}}})
	if #spawners == 0 then return end
	
	local allowed_to_build = true
	
	for _, e in pairs(spawners) do
		if (e.position.x - entity.position.x)^2 + (e.position.y - entity.position.y)^2 < 4096 then
			allowed_to_build = false
			break
		end			
	end
	
	if allowed_to_build then return end
	
	if event.player_index then
		game.players[event.player_index].insert({name = entity.name, count = 1})		
	else	
		local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
		inventory.insert({name = entity.name, count = 1})													
	end
	
	surface.create_entity({
		name = "flying-text",
		position = entity.position,
		text = "Turret too close to spawner!",
		color = {r=0.98, g=0.66, b=0.22}
	})
	
	entity.destroy()
end

function Public.no_landfill_by_untrusted_user(event, trusted_table)
	local entity = event.created_entity
	if not entity.valid or not event.player_index or entity.name ~= "tile-ghost" or entity.ghost_name ~= "landfill" then return end
	local player = game.players[event.player_index]
	if not trusted_table[player.name] then
		player.print('You have not grown accustomed to this technology yet.', {r = 0.22, g = 0.99, b = 0.99})
		entity.destroy()
		return
	end
end

function Public.print_message_to_players(forcePlayerList, playerNameSendingMessage, msgToPrint, colorChosen)
	for _, playerOfForce in pairs(forcePlayerList) do
		if playerOfForce.connected then
			if global.ignore_lists[playerOfForce.name] == nil or (global.ignore_lists[playerOfForce.name] and not global.ignore_lists[playerOfForce.name][playerNameSendingMessage]) then
				if colorChosen == nil then
					playerOfForce.print(msgToPrint)
				else
					playerOfForce.print(msgToPrint, colorChosen)
				end
			end
		end
	end
end

function Public.spy_fish(player, event)
	local button = event.button
	local shift = event.shift
	if not player.character then return end
	if event.control then return end
	local duration_per_unit = 2700
	local i2 = player.get_inventory(defines.inventory.character_main)
	if not i2 then return end
	local owned_fish = i2.get_item_count("raw-fish")
	local send_amount = 1
	if owned_fish == 0 then
		player.print("You have no fish in your inventory.",{ r=0.98, g=0.66, b=0.22})
	else
		if shift then
			if button == defines.mouse_button_type.left then
				send_amount = owned_fish
			elseif button == defines.mouse_button_type.right then
				send_amount = math_floor(owned_fish / 2)
			end
		else
			if button == defines.mouse_button_type.left then
				send_amount = 1
			elseif button == defines.mouse_button_type.right then
				send_amount = math_min(owned_fish, 5)
			end
		end

		local x = i2.remove({name="raw-fish", count=send_amount})
		if x == 0 then i2.remove({name="raw-fish", count=send_amount}) end
		local enemy_team = "south"
		if player.force.name == "south" then enemy_team = "north" end													 
		if global.spy_fish_timeout[player.force.name] - game.tick > 0 then 
			global.spy_fish_timeout[player.force.name] = global.spy_fish_timeout[player.force.name] + duration_per_unit * send_amount
			spy_time_seconds = math_floor((global.spy_fish_timeout[player.force.name] - game.tick) / 60)
			if spy_time_seconds > 60 then
				local minute_label = " minute and "
				if spy_time_seconds > 120 then
					minute_label = " minutes and "
				end
				player.print(math_floor(spy_time_seconds / 60) .. minute_label .. math_floor(spy_time_seconds % 60) .. " seconds of enemy vision left.", { r=0.98, g=0.66, b=0.22})
			else
				player.print(spy_time_seconds .. " seconds of enemy vision left.", { r=0.98, g=0.66, b=0.22})
			end
		else
			game.print(player.name .. " sent " .. send_amount .. " fish to spy on " .. enemy_team .. " team!", {r=0.98, g=0.66, b=0.22})
			global.spy_fish_timeout[player.force.name] = game.tick + duration_per_unit * send_amount
		end		
	end
end

function Public.create_map_intro_button(player)
	if player.gui.top["map_intro_button"] then return end
	local b = player.gui.top.add({type = "sprite-button", caption = "?", name = "map_intro_button", tooltip = "Map Info"})
	b.style.font_color = {r=0.5, g=0.3, b=0.99}
	b.style.font = "heading-1"
	gui_style(b, {width = 38, height = 38, padding = -2})
end

function Public.show_intro(player)
	if player.gui.center["map_intro_frame"] then player.gui.center["map_intro_frame"].destroy() end
	local frame = player.gui.center.add {type = "frame", name = "map_intro_frame", direction = "vertical"}
	local frame = frame.add {type = "frame"}
	local l = frame.add {type = "label", caption = {"biter_battles.map_info"}, name = "biter_battles_map_intro"}
	l.style.single_line = false
	l.style.font_color = {r=255, g=255, b=255}
end

function Public.map_intro_click(player, element)
	if element.name == "close_map_intro_frame" then player.gui.center["map_intro_frame"].destroy() return true end	
	if element.name == "biter_battles_map_intro" then player.gui.center["map_intro_frame"].destroy() return true end	
	if element.name == "map_intro_button" then
		if player.gui.center["map_intro_frame"] then
			player.gui.center["map_intro_frame"].destroy()
			return true
		else
			Public.show_intro(player)
			return true
		end
	end	
end

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

-- Player can be nil
function Public.calc_send_command(params, global_passed_in, player_count, player)
	if params == nil then
		params = ""
	end
	local difficulty = global_passed_in.difficulty_vote_value * 100
	local evo = nil
	local print_help = false
	local error_msg
	local flask_color
	local flask_count
	local force_to_send_to
	local help_text = "\nUsage: /calc-send evo=20.0 difficulty=30 players=4 color=green count=1000" ..
		"\nUsage: /calc-send force=north color=white count=1000"
	if player and player.force.name == "north" then
		force_to_send_to = "south"
	elseif player and player.force.name == "south" then
		force_to_send_to = "north"
	end
	-- indexed by strings like "automation-science-pack"
	local foods = {}
	for param in string.gmatch(params, "([^%s]+)") do
		local k, v = string.match(param, "^(%w+)=([%w%p]+)$")
		if k and v then
			if k == "force" then
				if v == "n" or v == "nth" or v == "north" then
					force_to_send_to = "north"
				elseif v == "s" or v == "sth" or v == "south" then
					force_to_send_to = "south"
				else
					error_msg = "Invalid force"
				end
			elseif k == "evo" then
				evo = tonumber(v)
				if evo == nil or evo < 0 or evo > 100000 then
					error_msg = "Invalid evo"
				end
			elseif k == "difficulty" then
				difficulty = tonumber(v)
				if difficulty == nil or difficulty < 0 or difficulty > 10000 then
					error_msg = "Invalid difficulty"
				end
			elseif k == "players" then
				player_count = tonumber(v)
				if player_count == nil or player_count < 0 or player_count > 10000 then
					error_msg = "Invalid player count"
				end
			elseif k == "color" then
				if v == "red" then v = "automation-science-pack" end
				if v == "green" then v = "logistic-science-pack" end
				if v == "gray" or v == "grey" then v = "military-science-pack" end
				if v == "blue" then v = "chemical-science-pack" end
				if v == "purple" then v = "production-science-pack" end
				if v == "yellow" then v = "utility-science-pack" end
				if v == "white" then v = "space-science-pack" end
				local values = Tables.food_values[v]
				if values == nil then
					error_msg = "Invalid science pack color"
				else
					flask_color = v
				end
			elseif k == "count" then
				if flask_color == nil then
					error_msg = "Must specify flask color before count"
				else
					flask_count = tonumber(v)
					if flask_count == nil or flask_count <= 0 or flask_count > 1000000000 then
						error_msg = "Invalid flask count"
					end
					if foods[flask_color] == nil then foods[flask_color] = 0 end
					foods[flask_color] = foods[flask_color] + flask_count
				end
				flask_count = tonumber(v)
				if flask_count == nil or flask_count <= 0 or flask_count > 1000000000 then
					error_msg = "Invalid flask count"
				end
				flask_color = nil
			else
				error_msg = string.format("Invalid parameter: %q", k)
			end
		else
			error_msg = string.format("Invalid parameter: %q, must do things like \"evo=120\"", param)
		end
		if error_msg then break end
	end
	if flask_color ~= nil then
		error_msg = "Must specify \"count\" after \"color\""
	end
	if error_msg == nil and #foods == 0 and player ~= nil then
		local i = player.get_main_inventory()
		for food_type, _ in pairs(Tables.food_values) do
			local flask_amount = i.get_item_count(food_type)
			if flask_amount > 0 then
				foods[food_type] = flask_amount
			end
		end
	end
	if evo == nil and force_to_send_to then
		local biter_force_name = force_to_send_to .. "_biters"
		evo = global_passed_in.bb_evolution[biter_force_name] * 100
	end
	if error_msg == nil and evo == nil then
		error_msg = "Must specify evo (or force)"
	end
	if error_msg then
		return error_msg .. help_text
	end
	local total_food = 0
	local debug_command_str = string.format("evo=%.1f difficulty=%d players=%d", evo,
										    math.floor(difficulty), player_count)
	for k, v in pairs(foods) do
		total_food = total_food + v * Tables.food_values[k].value
		debug_command_str = debug_command_str .. string.format(" color=%s count=%d", k, v)
	end
	if total_food == 0 then
		error_msg = "no \"color\"/\"count\" specified and nothing found in inventory"
	end
	if error_msg then
		return error_msg .. help_text
	end
	local effects = Public.calc_feed_effects(evo / 100, total_food * difficulty / 100, 1,
										     player_count, global_passed_in.max_reanim_thresh)
	return string.format("/calc-send %s\nevo_increase: %.1f new_evo: %.1f\nthreat_increase: %d",
						 debug_command_str, effects.evo_increase * 100, evo + effects.evo_increase * 100,
						 math.floor(effects.threat_increase))
end

function get_ammo_modifier(ammo_category)
	local result = 0
	if Tables.base_ammo_modifiers[ammo_category] then
        result = Tables.base_ammo_modifiers[ammo_category]
	end
    return result
end
function get_turret_attack_modifier(turret_category)
	local result = 0
	if Tables.base_turret_attack_modifiers[turret_category] then
        result = Tables.base_turret_attack_modifiers[turret_category]
	end
    return result
end

function get_upgrade_modifier(ammo_category)
    result = 0
    if Tables.upgrade_modifiers[ammo_category] then
        result = Tables.upgrade_modifiers[ammo_category]
    end
    return result
end

return Public
