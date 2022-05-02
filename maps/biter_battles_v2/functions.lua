local Server = require 'utils.server'
local Muted = require 'utils.muted'
local Tables = require "maps.biter_battles_v2.tables"
local Session = require 'utils.datastore.session_data'
local string_sub = string.sub
local math_random = math.random
local math_round = math.round
local math_abs = math.abs
local math_min = math.min
local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local string_find = string.find
require 'utils/gui_styles'

local Public = {}

-- Only add upgrade research balancing logic in this section
-- All values should be in tables.lua
function Public.ammo_mod(mod_val, ammo_category, force_name, is_endgame_mod)
	if not global.combat_balance[force_name][ammo_category] then
		global.combat_balance[force_name][ammo_category] = get_ammo_modifier(ammo_category)
		global.bb_endgame_unmodified_dmg[force_name][ammo_category] = get_ammo_modifier(ammo_category)
	end
	if is_endgame_mod then
		global.combat_balance[force_name][ammo_category] = global.bb_endgame_unmodified_dmg[force_name][ammo_category] + mod_val
	else
		global.combat_balance[force_name][ammo_category] = global.combat_balance[force_name][ammo_category] + mod_val
		global.bb_endgame_unmodified_dmg[force_name][ammo_category] = global.bb_endgame_unmodified_dmg[force_name][ammo_category] + mod_val
	end
	game.forces[force_name].set_ammo_damage_modifier(ammo_category, math.max(0, global.combat_balance[force_name][ammo_category]))
end

local function turret_mod(mod_val, turret_name, force_name)
	if not global.combat_balance[force_name][turret_name] then global.combat_balance[force_name][turret_name] = get_turret_attack_modifier(turret_name) end
	global.combat_balance[force_name][turret_name] = global.combat_balance[force_name][turret_name] + mod_val - get_upgrade_modifier(turret_name)
	game.forces[force_name].set_turret_attack_modifier(turret_name, math.max(0, global.combat_balance[force_name][turret_name]))
end


local balance_functions = {
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
}

-- I think 20 should be enough infinite research
for i= 1,20 do
	balance_functions[string.format("physical-projectile-damage-%d", i)] = function(force_name)
		Public.ammo_mod(Tables.upgrade_modifiers["bullet"], "bullet", force_name, false)
		Public.ammo_mod(Tables.upgrade_modifiers["shotgun-shell"], "shotgun-shell", force_name, false)
	end
	balance_functions[string.format("refined-flammables-%d", i)] = function(force_name)
		Public.ammo_mod(Tables.upgrade_modifiers["flamethrower"], "flamethrower", force_name, false)
		turret_mod(Tables.upgrade_modifiers["flamethrower-turret"], "flamethrower-turret", force_name)
	end
	balance_functions[string.format("energy-weapons-damage-%d", i)] = function(force_name)
		Public.ammo_mod(Tables.upgrade_modifiers["beam"], "beam", force_name, false)
		Public.ammo_mod(Tables.upgrade_modifiers["laser"], "laser", force_name, false)
		turret_mod(Tables.upgrade_modifiers["laser-turret"], "laser-turret", force_name)
	end
end


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
			if not global.combat_balance[force_name] then
				global.combat_balance[force_name] = {}
				global.bb_endgame_unmodified_dmg[force_name] = {}
			end
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

function Public.no_landfill_by_untrusted_user(event)
	local entity = event.created_entity
	if not entity.valid or not event.player_index or entity.name ~= "tile-ghost" or entity.ghost_name ~= "landfill" then return end
	local player = game.players[event.player_index]
	local trusted = Session.get_trusted_table()
	if not trusted[player.name] then
		player.print('You have not grown accustomed to this technology yet.', {r = 0.22, g = 0.99, b = 0.99})
		entity.destroy()
		return
	end
end

--Share chat with spectator force
function Public.share_chat(event)
	if not event.message or not event.player_index then return end
	local player = game.players[event.player_index]
	local player_name = player.name
	local player_force_name = player.force.name
	local tag = player.tag
	if not tag then tag = "" end
	local color = player.chat_color
	
	local muted = Muted.is_muted(player_name)
	local mute_tag = ""
	if muted then 
		mute_tag = "[muted] "
	end

	local msg = player_name .. tag .. " (" .. player_force_name .. "): ".. event.message
	if not muted and (player_force_name == "north" or player_force_name == "south") then
		game.forces.spectator.print(msg, color)
	end

	if global.tournament_mode and not player.admin then return end

	--Skip messages that would spoil coordinates from spectators and don't send gps coord to discord
	local a, b = string_find(event.message, "gps=", 1, false)
	if a then return end

	local discord_msg = ""
	if muted then 
		discord_msg = mute_tag
		Muted.print_muted_message(player)
	end 
	if not muted and player_force_name == "spectator" then
		game.forces.north.print(msg)
		game.forces.south.print(msg)
	end
	
	discord_msg = discord_msg .. player_name .. " (" .. player_force_name .. "): ".. event.message
	Server.to_discord_player_chat(discord_msg)
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
	element_style({element = b, x = 38, y = 38, pad = -2})
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
