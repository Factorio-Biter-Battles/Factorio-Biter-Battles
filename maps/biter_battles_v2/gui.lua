local Public = {}
local Server = require 'utils.server'

local bb_config = require "maps.biter_battles_v2.config"
local bb_diff = require "maps.biter_battles_v2.difficulty_vote"
local event = require 'utils.event'
local Functions = require "maps.biter_battles_v2.functions"
local feed_the_biters = require "maps.biter_battles_v2.feeding"
local Tables = require "maps.biter_battles_v2.tables"
local utils = require "utils.utils"
local wait_messages = Tables.wait_messages
local food_names = Tables.gui_foods
local Global = require "utils.global"

local math_random = math.random

require "maps.biter_battles_v2.spec_spy"
local gui_style = require 'utils.utils'.gui_style
local gui_values = {
	["north"] = {
		force = "north",
		biter_force = "north_biters",
		c1 = bb_config.north_side_team_name,
		c2 = "JOIN NORTH",
		n1 = "join_north_button",
		t1 = "Evolution of north side biters.",
		t2 = "Threat causes biters to attack. Reduces when biters are slain.",
		color1 = {r = 0.55, g = 0.55, b = 0.99},
		color1_s = "0.55,0.55,0.99",
		color2 = {r = 0.66, g = 0.66, b = 0.99},
		color2_s = "0.66,0.66,0.99",
		tech_spy = "spy-north-tech",
		prod_spy = "spy-north-prod"
	},
	["south"] = {
		force = "south",
		biter_force = "south_biters",
		c1 = bb_config.south_side_team_name,
		c2 = "JOIN SOUTH",
		n1 = "join_south_button",
		t1 = "Evolution of south side biters.",
		t2 = "Threat causes biters to attack. Reduces when biters are slain.",
		color1 = {r = 0.99, g = 0.33, b = 0.33},
		color1_s = "0.99,0.33,0.33",
		color2 = {r = 0.99, g = 0.44, b = 0.44},
		color2_s = "0.99,0.44,0.44",
		tech_spy = "spy-south-tech",
		prod_spy = "spy-south-prod"
	}
}

local gui_data = {
	players_str = {north = "", south = ""},
	threat = {north = "0", south = "0"},
	evo = {north = "0%", south = "0%"},
	reanim_chance = {north = 0, south = 0},
}

Global.register(
	gui_data,
	function(t)
		gui_data = t
	end
)

function Public.clear_copy_history(player)
	if player and player.valid then
		for i=1,21 do
			-- Imports blueprint of single burner miner into the cursor stack
			stack = player.cursor_stack.import_stack("0eNp9jkEKgzAURO8y67jQhsbmKqUUrR/5kHwliVKR3L3GbrrqcoaZN7OjdwvNgSXB7uDXJBH2viPyKJ0rXtpmggUn8lCQzhfVL0EoVJ6FZayGwM4hK7AM9Iat80OBJHFi+uJOsT1l8T2FI/AXpDBP8ehOUvYPnjYKG2x1bXMhn1fsz3OFlUI8801ba3NrzEVroxud8wdvA0sn")
			player.add_to_clipboard(player.cursor_stack)
			player.clear_cursor() 
		end
	end
end

local function create_sprite_button(player)
	if player.gui.top["bb_toggle_button"] then return end
	local button = player.gui.top.add({type = "sprite-button", name = "bb_toggle_button", sprite = "entity/big-biter"})
	gui_style(button, {width = 38, height = 38, padding = -2, font = "default-bold"})
end

local function get_clock_str()
	local total_minutes = math.floor(game.ticks_played / (60 * 60))
	local total_hours = math.floor(total_minutes / 60)
	local minutes = total_minutes - (total_hours * 60)
	return string.format("Game time: %02d:%02d", total_hours, total_minutes)
	--[[
	local clock = frame.add {type = "label", caption = clock_str}
	clock.style.font = "default-bold"
	clock.style.font_color = {r = 0.98, g = 0.66, b = 0.22}
	frame.add {type = "line"}
	]]
end

local function add_tech_button(elem, gui_value)
	local tech_button = elem.add {
		type = "sprite-button",
		name = gui_value.tech_spy,
		sprite = "item/space-science-pack"
	}
	tech_button.style.height = 25
	tech_button.style.width = 25
	tech_button.style.left_margin = 3
end

local function add_prod_button(elem, gui_value)
	local prod_button = elem.add {
		type = "sprite-button",
		name = gui_value.prod_spy,
		sprite = "item/assembling-machine-3"
	}
	prod_button.style.height = 25
	prod_button.style.width = 25
end

function Public.create_first_join_gui_2(player, frame)
	local is_spec = player.force.name == "spectator"
	local frame
	if player.gui.left.bb_main_gui then
		frame = player.gui.left.bb_main_gui
		frame.clear()
	else
		frame = player.gui.left.add{ type = "frame", name = "bb_main_gui", direction = "vertical" }
	end

	--Introduction
	local b = frame.add{ type = "label", name = "label_1", caption = "Defend your Rocket Silo!" }
	gui_style(b, {font = "heading-1", font_color = {r=0.98, g=0.66, b=0.22}})
	b = frame.add  { type = "label", name = "label_2", caption = "Feed the enemy team's biters to gain advantage!" }
	gui_style(b, {font = "heading-2", font_color = {r=0.98, g=0.66, b=0.22}})

	local clock = frame.add{ type = "label", caption = get_clock_str()}
	gui_style(clock, {font = "default-bold", font_color = {r = 0.98, g = 0.66, b = 0.22}})
	frame.add {type = "line"}

	--Auto Join & Playerlist buttons
	local t = frame.add{type = "table", name = "top_buttons", column_count = 2}
	local button = t.add{type = "sprite-button", name = "join_random_button", caption = "AUTO JOIN"}
	gui_style(button, {font = "default-large-bold", font_color = {r=1, g=0, b=1}, width = 175})
	button = t.add{type = "sprite-button", name = "toggle_playerlist", caption = "Playerlist"}
	gui_style(button, {font = "default-large-bold", font_color = {r=1, g=0, b=1}, width = 175})
	frame.add{type = "line"}

	for side, gui_value in pairs(gui_values) do
		local team_name = gui_value.c1
		if global.tm_custom_name[gui_value.force] then team_name = global.tm_custom_name[gui_value.force] end

		--Team name and player count
		local flow = frame.add{type = "flow", name = "team_name_flow_" .. side}
		local caption = string.format("[color=%s]%s[/color] -  ", gui_value.color1_s, team_name)
		local l = flow.add{type = "label", caption = caption}
		gui_style(l, {font = "heading-2", single_line = true, maximal_width = 290, font_color = gui_value.color1})
		l = flow.add{type = "label", name = "player_count_" .. side, caption = #game.forces[side].connected_players}
		gui_style(l, {font_color = {r=0.22, g=0.88, b=0.22}, font = "heading-2"})

		--Evo and threat
		local evo = gui_data.evo[side]
		local threat = gui_data.threat[side]
		local stats = frame.add{type = "flow", name = "stats_" .. side, direction = "horizontal"}
		stats.add{type = "label", caption = "Evo: "}
		stats.add{type = "label", name = "evo", caption = evo}.style.font_color = gui_value.color2
		stats.add{type = "label", caption = "\tThreat: "}
		stats.add{type = "label", name = "threat", caption = threat}.style.font_color = gui_value.color2
		--caption = string.format("Evo: [color=%s]%s[/color]\tThreat: [color=%s]%s[/color]", gui_value.color2_s, evo, gui_value.color2_s, threat)
		--l = frame.add{type = "label", name = "stats_" .. side, caption = caption}

		--Playerlist
		l = frame.add({type = "label", name = "playerlist_" .. side, caption = gui_data.players_str[side], visible = false})
		gui_style(l, {font = "heading-2", single_line = false})
		
		--Join button
		caption = gui_value.c2
		local font_color =  gui_value.color1
		if global.game_lobby_active then
			font_color = {r=0.7, g=0.7, b=0.7}
			caption = string.format("%s (waiting for players...  %d)", caption, math.ceil((global.game_lobby_timeout - game.tick)/60))
		end
		local b = frame.add  { type = "sprite-button", name = gui_value.n1, caption = caption}
		gui_style(b, {font = "default-large-bold", font_color = font_color, width = 350})

		frame.add{ type = "line"}
	end
	--if is_spec then t.visible = false end
	t = frame.add{type = "table", name = "sci_table", column_count = 3, visible = (not true)}
	for food_name, tooltip in pairs(food_names) do
		local s = t.add{type = "sprite-button", name = food_name, sprite = "item/" .. food_name, tooltip = tooltip}
		gui_style(s, {minimal_height = 41, minimal_width = 41, padding = 0})
	end
	local s = t.add{type = "sprite-button", name = "send_all", caption = "All"}
	gui_style(s, {minimal_height = 41, minimal_width = 41, padding = 0})
	
end

function Public.refresh()
	for _, player in pairs(game.connected_players) do
		if player.gui.left["bb_main_gui"] then
			--Public.create_main_gui(player)
		end
	end
	global.gui_refresh_delay = game.tick + 5
end

function Public.refresh_evo_and_threat()
	if global.gui_refresh_delay > game.tick then return end
	for _, player in pairs(game.connected_players) do
		player.gui.left.bb_main_gui.stats_north.evo.caption = gui_data.evo.north
		player.gui.left.bb_main_gui.stats_south.evo.caption = gui_data.evo.south

		player.gui.left.bb_main_gui.stats_north.threat.caption = gui_data.threat.north
		player.gui.left.bb_main_gui.stats_south.threat.caption = gui_data.threat.south
	end
	global.gui_refresh_delay = game.tick + 5
end

function Public.update_evo_and_threat()
	for _, force in pairs({"north", "south"}) do
		gui_data.evo[force] = math.floor(1000 * global.bb_evolution[force .. "_biters"]) * 0.1 .. "%"
		gui_data.threat[force] = utils.metric_notation(math.floor(global.bb_threat[force .. "_biters"]))
		
		--gui_data.evo_and_threat_str[force] = string.format("Evo: [color=%s]%s%%[/color]\tThreat: [color=%s]%s[/color]", gui_values[force].color2_s, evo, gui_values[force].color2_s, threat)
	end
end

function Public.refresh_playerlist()
	local count_north = #game.forces.north.connected_players
	local count_south = #game.forces.south.connected_players
	local str_north = gui_data.players_str.north
	local str_south = gui_data.players_str.south
	for _, player in pairs(game.connected_players) do
		player.gui.left.bb_main_gui.playerlist_north.caption = str_north
		player.gui.left.bb_main_gui.playerlist_south.caption = str_south
		player.gui.left.bb_main_gui.team_name_flow_north.player_count_north.caption = count_north
		player.gui.left.bb_main_gui.team_name_flow_south.player_count_south.caption = count_south
	end
end

function Public.update_playerlist(force_name)
	if force_name then
		local temp = {}
		local color, r, g, b
		for _, player in pairs(game.forces[force_name].connected_players) do
			color = player.color
			r = color.r * 0.6 + 0.4
			g = color.g * 0.6 + 0.4
			b = color.b * 0.6 + 0.4
			table.insert(temp, string.format("[color=%f,%f,%f]%s[/color]", r, g, b, player.name))
		end
		gui_data.players_str[force_name] = table.concat(temp, "\t")
	else
		for k, v in pairs({"north", "south"}) do
			local temp = {}
			local color, r, g, b
			for _, player in pairs(game.forces[v].connected_players) do
				color = player.color
				r = color.r * 0.6 + 0.4
				g = color.g * 0.6 + 0.4
				b = color.b * 0.6 + 0.4
				table.insert(temp, string.format("[color=%f,%f,%f]%s[/color]", r, g, b, player.name))
			end
			gui_data.players_str[v] = table.concat(temp, "\t")
		end
	end
end

function join_team(player, force_name, forced_join, auto_join)
	if not player.character then return end
	if not forced_join then
		if global.tournament_mode then player.print("The game is set to tournament mode. Teams can only be changed via team manager.", {r = 0.98, g = 0.66, b = 0.22}) return end
	end
	if not force_name then return end
	local surface = player.surface
	local enemy_team = "south"
	if force_name == "south" then enemy_team = "north" end

	if not global.training_mode and global.bb_settings.team_balancing then
		if not forced_join then
			if #game.forces[force_name].connected_players > #game.forces[enemy_team].connected_players then
				if not global.chosen_team[player.name] then
					player.print("Team " .. force_name .. " has too many players currently.", {r = 0.98, g = 0.66, b = 0.22})
					return
				end
			end
		end
	end

	if global.chosen_team[player.name] then
		if not forced_join then
			if game.tick - global.spectator_rejoin_delay[player.name] < 3600 then
				player.print(
					"Not ready to return to your team yet. Please wait " .. 60-(math.floor((game.tick - global.spectator_rejoin_delay[player.name])/60)) .. " seconds.",
					{r = 0.98, g = 0.66, b = 0.22}
				)
				return
			end
		end
		local p = surface.find_non_colliding_position("character", game.forces[force_name].get_spawn_position(surface), 16, 0.5)
		if not p then
			game.print("No spawn position found for " .. player.name .. "!", {255, 0, 0})
			return 
		end
		player.teleport(p, surface)
		player.force = game.forces[force_name]
		player.character.destructible = true

		game.permissions.get_group("Default").add_player(player)
		local msg = table.concat({"Team ", player.force.name, " player ", player.name, " is no longer spectating."})
		game.print(msg, {r = 0.98, g = 0.66, b = 0.22})
		Server.to_discord_bold(msg)
		global.spectator_rejoin_delay[player.name] = game.tick
		player.spectator = false
		--Public.refresh()
		--gui update
		player.gui.left.bb_main_gui.top_buttons.toggle_spectate.caption = "Spectate"
		player.gui.left.bb_main_gui.sci_table.visible = true
		Public.update_playerlist()
		Public.refresh_playerlist()
		return
	end
	local pos = surface.find_non_colliding_position("character", game.forces[force_name].get_spawn_position(surface), 8, 1)
	if not pos then pos = game.forces[force_name].get_spawn_position(surface) end
	player.teleport(pos)
	player.force = game.forces[force_name]
	player.character.destructible = true
	game.permissions.get_group("Default").add_player(player)
	if not forced_join then
		local c = player.force.name
		if global.tm_custom_name[player.force.name] then c = global.tm_custom_name[player.force.name] end
		local message = table.concat({player.name, " has joined team ", c, "! "})
		Server.to_discord_bold(message)
		if auto_join then message = table.concat({player.name, " was automatically assigned to team ", c, "!"}) end
		game.print(message, {r = 0.98, g = 0.66, b = 0.22})
	end
	local i = player.get_inventory(defines.inventory.character_main)
	i.clear()
	player.insert {name = 'pistol', count = 1}
	player.insert {name = 'raw-fish', count = 3}
	player.insert {name = 'firearm-magazine', count = 32}
	player.insert {name = 'iron-gear-wheel', count = 8}
	player.insert {name = 'iron-plate', count = 16}
	player.insert {name = 'burner-mining-drill', count = 10}
	player.insert {name = 'wood', count = 2}
	global.chosen_team[player.name] = force_name
	global.spectator_rejoin_delay[player.name] = game.tick
	player.spectator = false
	Public.clear_copy_history(player)
	--Public.refresh()
	--gui update
	local bb_main_gui = player.gui.left.bb_main_gui
	bb_main_gui.label_1.visible = false
	bb_main_gui.label_2.visible = false
	if bb_main_gui.top_buttons.join_random_button then
		bb_main_gui.top_buttons.join_random_button.name = "toggle_spectate"
	end
	bb_main_gui.top_buttons.toggle_spectate.caption = "Spectate"
	bb_main_gui.top_buttons.toggle_spectate.style.width = 90
	bb_main_gui.top_buttons.toggle_playerlist.style.width = 90
	bb_main_gui.sci_table.visible = true
	if bb_main_gui.join_north_button then
		bb_main_gui.join_north_button.destroy()
		bb_main_gui.join_south_button.destroy()
	end
	Public.update_playerlist()
	Public.refresh_playerlist()
end

function spectate(player, forced_join)
	if not player.character then return end
	if not forced_join then
		if global.tournament_mode then player.print("The game is set to tournament mode. Teams can only be changed via team manager.", {r = 0.98, g = 0.66, b = 0.22}) return end
	end
	player.teleport(player.surface.find_non_colliding_position("character", {0,0}, 4, 1))
	local old_force_name = player.force.name
	player.force = game.forces.spectator
	player.character.destructible = false
	if not forced_join then
		local msg = player.name .. " is spectating."
		game.print(msg, {r = 0.98, g = 0.66, b = 0.22})
		Server.to_discord_bold(msg)
	end
	game.permissions.get_group("spectator").add_player(player)
	global.spectator_rejoin_delay[player.name] = game.tick
	-- gui update
	player.gui.left.bb_main_gui.top_buttons.toggle_spectate.caption = "Rejoin"
	player.gui.left.bb_main_gui.sci_table.visible = false
	Public.update_playerlist()
	Public.refresh_playerlist()
	--Public.create_main_gui(player)
	player.spectator = true
end

local function join_gui_click(name, player, auto_join)
	if not name then return end

	if global.game_lobby_active then
		if player.admin then
			join_team(player, name, false,  auto_join)
			game.print("Lobby disabled, admin override.", { r=0.98, g=0.66, b=0.22})
			global.game_lobby_active = false
			return
		end
		player.print("Waiting for more players, " .. wait_messages[math_random(1, #wait_messages)], { r=0.98, g=0.66, b=0.22})
		return
	end
	join_team(player, name, false, auto_join)
end

local spy_forces = {{"north", "south"},{"south", "north"}}
function Public.spy_fish()
	for _, f in pairs(spy_forces) do
		if global.spy_fish_timeout[f[1]] - game.tick > 0 then
			local r = 96
			local surface = game.surfaces[global.bb_surface_name]
			for _, player in pairs(game.forces[f[2]].connected_players) do
				game.forces[f[1]].chart(surface, {{player.position.x - r, player.position.y - r}, {player.position.x + r, player.position.y + r}})
			end
		else
			global.spy_fish_timeout[f[1]] = 0
		end
	end
end

local function on_gui_click(event)
	if not event.element then return end
	if not event.element.valid then return end
	local player = game.get_player(event.player_index)
	local name = event.element.name
	if name == "bb_toggle_button" then
		if player.gui.left["bb_main_gui"].visible then
			player.gui.left["bb_main_gui"].visible = false
		else
			player.gui.left["bb_main_gui"].visible = true
			--Public.create_main_gui(player)
		end
		return
	end
	for _, gui_values in pairs(gui_values) do
		if name == gui_values.n1 then join_gui_click(gui_values.force, player) return end
	end
		
	if name == "join_random_button" then
		local teams_equal = true
		local a = #game.forces["north"].connected_players -- Idk how to choose the 1st force without calling 'north'
	
		-- checking if teams are equal	
		for _, gui_values in pairs(gui_values) do
			if a ~= #game.forces[gui_values.force].connected_players then
				teams_equal = false
				break
			end
		end
	
		-- choosing a team at random if teams are equal
		if teams_equal then
			local teams = {}
			for _, gui_values in pairs(gui_values) do table.insert(teams, gui_values.force) end
			join_gui_click(teams[math.random(#teams)], player, true)
	
		else -- checking which team is smaller and joining it
			local smallest_team = gui_values["north"].force -- Idk how to choose the 1st force without calling 'north'
			for _, gui_values in pairs(gui_values) do
				if a > #game.forces[gui_values.force].connected_players then
					smallest_team = gui_values.force
					a = #game.forces[gui_values.force].connected_players
				end
			end
			join_gui_click(smallest_team, player, true)
		end
		return
	end

	if name == "raw-fish" then Functions.spy_fish(player, event) return end

	if food_names[name] then feed_the_biters(player, name) return end

	if name == "toggle_spectate" then
		if player.force.name == "spectator" then
			join_team(player, global.chosen_team[player.name])
			--player.gui.left.bb_main_gui.top_buttons.toggle_spectate.caption = "Spectate"
		else
			if player.position.y ^ 2 + player.position.x ^ 2 < 12000 then
				spectate(player)
				
			else
				player.print("You are too far away from spawn to spectate.",{ r=0.98, g=0.66, b=0.22})
			end
		end 
		return
	end

	if name == "toggle_playerlist" then
		if player.gui.left.bb_main_gui.playerlist_north.visible == true then
			player.gui.left.bb_main_gui.playerlist_north.visible = false
			player.gui.left.bb_main_gui.playerlist_south.visible = false
		else
			player.gui.left.bb_main_gui.playerlist_north.visible = true
			player.gui.left.bb_main_gui.playerlist_south.visible = true
		end
		return
	end
	
end

function Public.on_player_joined_game(event)
	local player = game.players[event.player_index]

	if not global.bb_view_players then global.bb_view_players = {} end
	if not global.chosen_team then global.chosen_team = {} end

	global.bb_view_players[player.name] = false

	if #game.connected_players > 1 then
		global.game_lobby_timeout = math.ceil(36000 / #game.connected_players)
	else
		global.game_lobby_timeout = 599940
	end

	--if not global.chosen_team[player.name] then
	--	if global.tournament_mode then
	--		player.force = game.forces.spectator
	--	else
	--		player.force = game.forces.player
	--	end
	--end

	create_sprite_button(player)
	if global.chosen_team[player.name] then
		create_in_team_gui(player)
	else
		Public.create_first_join_gui_2(player)
	end
	--Public.create_main_gui(player)
end


event.add(defines.events.on_gui_click, on_gui_click)
--event.add(defines.events.on_player_joined_game, on_player_joined_game)

return Public
