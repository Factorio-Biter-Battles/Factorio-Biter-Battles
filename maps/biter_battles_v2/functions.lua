local Server = require 'utils.server'
local Tables = require "maps.biter_battles_v2.tables"
local string_sub = string.sub
local math_random = math.random
local math_round = math.round
local math_abs = math.abs
local math_min = math.min
local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local string_find = string.find

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

local target_entity_types = {
	["assembling-machine"] = true,
	["boiler"] = true,
	["furnace"] = true,
	["generator"] = true,
	["lab"] = true,
	["mining-drill"] = true,
	["radar"] = true,
	["reactor"] = true,
	["roboport"] = true,
	["rocket-silo"] = true,
	["ammo-turret"] = true,
	["artillery-turret"] = true,
	["beacon"] = true,
	["electric-turret"] = true,
	["fluid-turret"] = true,
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

function Public.add_target_entity(entity)
	if not entity then return end
	if not entity.valid then return end
	if not target_entity_types[entity.type] then return end
	table_insert(global.target_entities[entity.force.index], entity)
end

function Public.get_random_target_entity(force_index)
	local target_entities = global.target_entities[force_index]
	local size_of_target_entities = #target_entities
	if size_of_target_entities == 0 then return end
	for _ = 1, size_of_target_entities, 1 do
		local i = math_random(1, size_of_target_entities)
		local entity = target_entities[i]
		if entity and entity.valid then
			return entity
		else
			table_remove(target_entities, i)
			size_of_target_entities = size_of_target_entities - 1
			if size_of_target_entities == 0 then return end
		end
	end
end

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

function Public.no_turret_creep(event)
	local entity = event.created_entity
	if not entity.valid then return end
	if not no_turret_blacklist[event.created_entity.type] then return end
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

--Share chat with spectator force
function Public.share_chat(event)
	if not event.message then return end
	if not event.player_index then return end
	local player = game.players[event.player_index]
	local tag = player.tag
	if not tag then tag = "" end
	local color = player.chat_color

	local msg = player.name .. tag .. " (" .. player.force.name .. "): ".. event.message
	if player.force.name == "north" or player.force.name == "south" then
		game.forces.spectator.print(player.name .. tag .. " (" .. player.force.name .. "): ".. event.message, color)
	end

	if global.tournament_mode and not player.admin then return end

	if player.force.name == "player" then
		game.forces.north.print(player.name .. tag .. " (spawn): ".. event.message, color)
		game.forces.south.print(player.name .. tag .. " (spawn): ".. event.message, color)
		game.forces.spectator.print(player.name .. tag .. " (spawn): ".. event.message, color)
	end

	--Skip messages that would spoil coordinates from spectators and don't send gps coord to discord
	local a, b = string_find(event.message, "gps=", 1, false)
	if a then return end

	local discord_msg = player.name .. " (" .. player.force.name .. "): ".. event.message
	Server.to_discord_player_chat(discord_msg)

	if player.force.name == "spectator" then
		game.forces.north.print(player.name .. tag .. " (spectator): ".. event.message, color)
		game.forces.south.print(player.name .. tag .. " (spectator): ".. event.message, color)
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
	b.style.minimal_height = 38
	b.style.minimal_width = 38
	b.style.top_padding = 1
	b.style.left_padding = 1
	b.style.right_padding = 1
	b.style.bottom_padding = 1
end

function Public.show_intro(player)
	if player.gui.center["map_intro_frame"] then player.gui.center["map_intro_frame"].destroy() end
	local frame = player.gui.center.add {type = "frame", name = "map_intro_frame", direction = "vertical"}
	local frame = frame.add {type = "frame"}
	local l = frame.add {type = "label", caption = {"biter_battles.map_info"}, name = "biter_battles_map_intro"}
	l.style.single_line = false
	l.style.font = "heading-2"
	l.style.font_color = {r=0.7, g=0.6, b=0.99}
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
