local Public = {}
local Server = require 'utils.server'

local bb_config = require "maps.biter_battles_v2.config"
local bb_diff = require "maps.biter_battles_v2.difficulty_vote"
local event = require 'utils.event'
local Functions = require "maps.biter_battles_v2.functions"
local feed_the_biters = require "maps.biter_battles_v2.feeding"
local Tables = require "maps.biter_battles_v2.tables"

local wait_messages = Tables.wait_messages
local food_names = Tables.gui_foods

local math_random = math.random

require "maps.biter_battles_v2.spec_spy"
require 'utils/gui_styles'
local gui_values = {
		["north"] = {force = "north", biter_force = "north_biters", c1 = bb_config.north_side_team_name, c2 = "JOIN ", n1 = "join_north_button",
		t1 = "Evolution of north side biters.",
		t2 = "Threat causes biters to attack. Reduces when biters are slain.", color1 = {r = 0.55, g = 0.55, b = 0.99}, color2 = {r = 0.66, g = 0.66, b = 0.99},
		tech_spy = "spy-north-tech", prod_spy = "spy-north-prod"},
		["south"] = {force = "south", biter_force = "south_biters", c1 = bb_config.south_side_team_name, c2 = "JOIN ", n1 = "join_south_button",
		t1 = "Evolution of south side biters.",
		t2 = "Threat causes biters to attack. Reduces when biters are slain.", color1 = {r = 0.99, g = 0.33, b = 0.33}, color2 = {r = 0.99, g = 0.44, b = 0.44},
		tech_spy = "spy-south-tech", prod_spy = "spy-south-prod"}
	}

local function clear_copy_history(player) 
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
	button.style.font = "default-bold"
	element_style({element = button, x= 38, y = 38, pad = -2})
end

local function get_current_clock_time_string()
	local total_minutes = math.floor(game.ticks_played / (60 * 60))
	local total_hours = math.floor(total_minutes / 60)
	local minutes = total_minutes - (total_hours * 60)
	return string.format("Game time: %02d:%02d", total_hours, minutes)
end

local function add_clock_element(frame)
	local clock = frame.add{name="clock", type = "label", caption = get_current_clock_time_string()}
	clock.style.font = "default-bold"
	clock.style.font_color = {r = 0.98, g = 0.66, b = 0.22}
	frame.add{type = "line"}
end

local function update_waiting_text(frame, gui_value)
	local font_color = gui_value.color1
	local c = gui_value.c2
	if global.game_lobby_active then
		font_color = {r=0.7, g=0.7, b=0.7}
		c = string.format("%s (waiting for players... %d", c, math.ceil((global.game_lobby_timeout - game.tick)/60))
	end
	frame[gui_value.n1].caption = c
end

local function update_player_count_string(t, force)
	local c = #game.forces[force].connected_players .. " Player"
	if #game.forces[force].connected_players ~= 1 then c = c .. "s" end
	t.player_count_string.caption = c
end

local function update_player_list_table(frame, force, font)
	local connected_players_table = frame.connected_players_table
	local connected_players_table_size = #connected_players_table.children
	local new_connected_players = game.forces[force].connected_players
	local new_connected_players_size = #new_connected_players
	if connected_players_table_size == new_connected_players_size then
		for i=1, new_connected_players_size, 1 do
			local p = new_connected_players[i]
			local entry = connected_players_table.children[i]
			entry.caption = p.name
			entry.style.font_color = {r = p.color.r * 0.6 + 0.4, g = p.color.g * 0.6 + 0.4, b = p.color.b * 0.6 + 0.4, a = 1}
			entry.style.font = font
		end
	elseif connected_players_table_size < new_connected_players_size then -- if more players than currently in table
		for i=1, connected_players_table_size, 1 do
			local p = new_connected_players[i]
			local entry = connected_players_table.children[i]
			entry.caption = p.name
			entry.style.font_color = {r = p.color.r * 0.6 + 0.4, g = p.color.g * 0.6 + 0.4, b = p.color.b * 0.6 + 0.4, a = 1}
			entry.style.font = font
		end
		for i=connected_players_table_size+1, new_connected_players_size, 1 do
			local p = new_connected_players[i]
			local entry = connected_players_table.add{ type = "label", caption = p.name }
			entry.style.font_color = {r = p.color.r * 0.6 + 0.4, g = p.color.g * 0.6 + 0.4, b = p.color.b * 0.6 + 0.4, a = 1}
			entry.style.font = font
		end
	elseif connected_players_table_size > new_connected_players_size then -- if less players than currently in table
		for i=1, new_connected_players_size, 1 do
			local p = new_connected_players[i]
			local entry = connected_players_table.children[i]
			entry.caption = p.name
			entry.style.font_color = {r = p.color.r * 0.6 + 0.4, g = p.color.g * 0.6 + 0.4, b = p.color.b * 0.6 + 0.4, a = 1}
			entry.style.font = font
		end
		for i=connected_players_table_size, new_connected_players_size+1, -1 do
			connected_players_table.children[i].destroy()
		end
	end
end

local function update_evo_text_and_tooltip(table, gui_value, biter_force)
	local tooltip = string.format("%s\nDamage: %d%%\nRevive: %d%%",
		gui_value.t1,
		(biter_force.get_ammo_damage_modifier("melee") + 1) * 100,
		global.reanim_chance[biter_force.index])
	table.evo_text.tooltip = tooltip
	table.evo_value.tooltip = tooltip
	table.evo_value.caption = (math.floor(1000 * global.bb_evolution[gui_value.biter_force]) * 0.1) .. "%"
end

local function update_threat_text(table, gui_value, biter_force)
	table["threat_" .. gui_value.force].caption = tostring(math.floor(global.bb_threat[gui_value.force]))
end

local function create_statistics_table(frame, gui_value)
	local biter_force = game.forces[gui_value.biter_force]
	local t = frame.add{ type = "table", name = "stats_" .. gui_value.force, column_count = 5 }

	local evo_text = t.add{name="evo_text", type = "label", caption = "Evo:", tooltip = ""}
	local evo_value = t.add{ name="evo_value", type = "label", caption = "", tooltip = ""}
	evo_value.style.minimal_width = 40
	evo_value.style.font_color = gui_value.color2
	evo_value.style.font = "default-bold"
	update_evo_text_and_tooltip(t, gui_value, biter_force)

	-- Threat
	local threat_text = t.add{type = "label", caption = "Threat: "}
	threat_text.style.minimal_width = 25
	threat_text.tooltip = gui_value.t2

	local threat_value = t.add{type = "label", name = "threat_" .. gui_value.force, caption = ""}
	threat_value.style.font_color = gui_value.color2
	threat_value.style.font = "default-bold"
	threat_value.style.width = 50
	threat_value.tooltip = gui_value.t2
	update_threat_text(t, gui_value, biter_force)
end



local function create_first_join_gui(player)
	if not global.game_lobby_timeout then global.game_lobby_timeout = 5999940 end
	if global.game_lobby_timeout - game.tick < 0 then global.game_lobby_active = false end
	local bb_main_gui_frame = player.gui.left.add{ type = "frame", name = "bb_main_gui", direction = "vertical" }
	local b = bb_main_gui_frame.add{type = "label", caption = "Defend your Rocket Silo!" }
	b.style.font = "heading-1"
	b.style.font_color = {r=0.98, g=0.66, b=0.22}
	local b = bb_main_gui_frame.add{ type = "label", caption = "Feed the enemy team's biters to gain advantage!" }
	b.style.font = "heading-2"
	b.style.font_color = {r=0.98, g=0.66, b=0.22}
	add_clock_element(bb_main_gui_frame)
	local d = bb_main_gui_frame.add{type = "sprite-button", name = "join_random_button", caption = "AUTO JOIN"}
	d.style.font = "default-large-bold"
	d.style.font_color = { r=1, g=0, b=1}
	d.style.width = 350
	bb_main_gui_frame.add{ type = "line"}
	bb_main_gui_frame.style.bottom_padding = 2
	
	for gui_key, gui_value in pairs(gui_values) do
		local frame = bb_main_gui_frame.add{type="frame", name=gui_key, direction = "vertical", style="borderless_frame"}
		local team_name_and_playercount_table = frame.add{ name="team_name_and_playercount_table", type = "table", column_count = 3 }
		local c = gui_value.c1
		if global.tm_custom_name[gui_value.force] then c = global.tm_custom_name[gui_value.force] end
		local l = team_name_and_playercount_table.add{ name="c1", type = "label", caption = c}
		l.style.font = "heading-2"
		l.style.font_color = gui_value.color1
		l.style.single_line = false
		l.style.maximal_width = 290
		local l = team_name_and_playercount_table.add{ type = "label", caption = "  -  "}
		local l = team_name_and_playercount_table.add{ name="player_count_string", type = "label", caption = ""}
		l.style.font_color = {r=0.22, g=0.88, b=0.22}
		update_player_count_string(team_name_and_playercount_table, gui_value.force)

		local t = frame.add{ name="connected_players_table", type = "table", column_count = 4 }
		if global.bb_view_players[player.name] == true then
			frame.connected_players_table.visible = true
			update_player_list_table(frame, gui_value.force, "heading-2")
		else
			frame.connected_players_table.visible = false
		end

		local b = frame.add{ type = "sprite-button", name = gui_value.n1, caption = ""}
		b.style.font = "default-large-bold"
		b.style.font_color = font_color
		b.style.width = 350
		update_waiting_text(frame, gui_value)
		frame.add{ type = "line"}
	end
end

local function update_first_join_gui(player)
	local bb_main_gui_frame = player.gui.left.bb_main_gui
	for gui_key, gui_value in pairs(gui_values) do
		local frame = bb_main_gui_frame[gui_key]
		local current_table = frame.team_name_and_playercount_table
		if global.tm_custom_name[gui_value.force] then current_table.c1.caption = global.tm_custom_name[gui_value.force] end
		update_player_count_string(current_table, gui_value.force)
		if global.bb_view_players[player.name] == true then
			frame.connected_players_table.visible = true
			update_player_list_table(frame, gui_value.force, "heading-2")
		else
			frame.connected_players_table.visible = false
		end

		update_waiting_text(frame, gui_value)
	end
end

local function create_or_update_first_join_gui(player)
	if not player.gui.left.bb_main_gui then
		create_first_join_gui(player)
	else
		update_first_join_gui(player)
	end
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
	tech_button.visible = false
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

function Public.update_or_create_main_gui(player)

	if global.bb_game_won_by_team then return end
	if not global.chosen_team[player.name] then
		if not global.tournament_mode then
			create_or_update_first_join_gui(player)
			return
		end
	end

	if not player.gui.left.bb_main_gui then
		Public.create_main_gui(player)
	else
		Public.update_main_gui(player)
	end
end


function Public.update_main_gui(player)
	local is_spec = player.force.name == "spectator"
	local bb_main_gui_frame = player.gui.left.bb_main_gui

	if bb_main_gui_frame.visible == false then return end
	bb_main_gui_frame.clock.caption = get_current_clock_time_string()
	if is_spec then
		bb_main_gui_frame.bb_science_frame.visible = false
		bb_main_gui_frame.action_table.bb_spectate.caption = "Join Team"
	else
		bb_main_gui_frame.bb_science_frame.visible = true
		bb_main_gui_frame.action_table.bb_spectate.caption = "Spectate"
	end

	for gui_key, gui_value in pairs(gui_values) do
		local biter_force = game.forces[gui_value.biter_force]
		-- Future improvements - we could only update most of these when value is changed
		local frame = bb_main_gui_frame[gui_key]
		local current_table = frame.team_name_and_playercount_table
		if global.tm_custom_name[gui_value.force] then current_table.c1.caption = global.tm_custom_name[gui_value.force] end
		update_player_count_string(current_table, gui_value.force)


		if is_spec and not global.chosen_team[player.name] then
			current_table[gui_value.tech_spy].visible = true
		end

		if global.bb_view_players[player.name] == true then
			frame.connected_players_table.visible = true
			update_player_list_table(frame, gui_value.force, "default")
		else
			frame.connected_players_table.visible = false
		end

		local stats_table = frame["stats_"..gui_value.force]
		update_evo_text_and_tooltip(stats_table, gui_value, biter_force)
		update_threat_text(stats_table, gui_value, biter_force)
		bb_diff.update_difficulty_gui_for_player(player, math.floor(global.difficulty_vote_value*100))

	end
end

function Public.create_main_gui(player)
	local is_spec = player.force.name == "spectator"
	if player.gui.left.bb_main_gui then player.gui.left.bb_main_gui.destroy() end
	local bb_main_gui_frame = player.gui.left.add{ type = "frame", name = "bb_main_gui", direction = "vertical" }
	
	add_clock_element(bb_main_gui_frame)
	-- Science sending GUI
	local bb_table_frame = bb_main_gui_frame.add{name="bb_science_frame", type="frame", style="borderless_frame"}
	local t = bb_table_frame.add{ type = "table", name = "biter_battle_table", column_count = 4 }
	for food_name, tooltip in pairs(food_names) do
		local s = t.add { type = "sprite-button", name = food_name, sprite = "item/" .. food_name }
		s.tooltip = tooltip
		s.style.minimal_height = 41
		s.style.minimal_width = 41
		s.style.top_padding = 0
		s.style.left_padding = 0
		s.style.right_padding = 0
		s.style.bottom_padding = 0
	end
	if is_spec then
		bb_table_frame.visible = false
	end

	local first_team = true
	for gui_key, gui_value in pairs(gui_values) do
		local frame = bb_main_gui_frame.add{type="frame", name=gui_key, style="borderless_frame", direction="vertical"}
		-- Line separator
		if not first_team then
			frame.add{ type = "line", direction = "horizontal" }
		else
			first_team = false
		end

		-- Team name & Player count
		local t = frame.add{ name="team_name_and_playercount_table", type = "table", column_count = 4 }

		-- Team name
		local c = gui_value.c1
		if global.tm_custom_name[gui_value.force] then c = global.tm_custom_name[gui_value.force] end
		local l = t.add{ name="c1", type = "label", caption = c}
		l.style.font = "default-bold"
		l.style.font_color = gui_value.color1
		l.style.single_line = false
		l.style.maximal_width = 102

		-- Number of players
		local l = t.add{type = "label", caption = " - "}
		local player_count_string = t.add{ name="player_count_string", type = "label", caption = ""}
		player_count_string.style.font = "default"
		player_count_string.style.font_color = { r=0.22, g=0.88, b=0.22}
		update_player_count_string(t, gui_value.force)
		
		-- Tech button
		add_tech_button(t, gui_value)

		-- Player list
		local t = frame.add{ name="connected_players_table", type = "table", column_count = 4 }
		if global.bb_view_players[player.name] == true then
			frame.connected_players_table.visible = true
			update_player_list_table(frame, gui_value.force, "default")
		else
			frame.connected_players_table.visible = false
		end
		-- Statistics
		create_statistics_table(frame, gui_value)
	end

	bb_diff.update_difficulty_gui_for_player(player, math.floor(global.difficulty_vote_value*100))

	-- Action frame
	local action_table = bb_main_gui_frame.add{ name="action_table", type = "table", column_count = 2 }
	-- Spectate / Rejoin team
	local b = action_table.add{ type = "sprite-button", name = "bb_spectate", caption = "Join Team" }
	if not is_spec then
		b.caption = "Spectate"
	end
	local b = action_table.add{ type = "sprite-button", name = "bb_players", caption = "Playerlist" }

	local b_width = is_spec and 97 or 86
	-- 111 when prod_spy button will be there
	for _, b in pairs(action_table.children) do
		b.style.font = "default-bold"
		b.style.font_color = { r=0.98, g=0.66, b=0.22}
		b.style.top_padding = 1
		b.style.left_padding = 1
		b.style.right_padding = 1
		b.style.bottom_padding = 1
		b.style.maximal_height = 30
		b.style.width = b_width
	end
end

function Public.refresh()
	for _, player in pairs(game.connected_players) do
		Public.update_or_create_main_gui(player)
	end
	global.gui_refresh_delay = game.tick + 5
end

function Public.refresh_threat()
	if global.gui_refresh_delay > game.tick then return end
	for _, player in pairs(game.connected_players) do
		if player.gui.left["bb_main_gui"] then
			if player.gui.left["bb_main_gui"].stats_north then
				player.gui.left["bb_main_gui"].stats_north.threat_north.caption = math.floor(global.bb_threat["north_biters"])
				player.gui.left["bb_main_gui"].stats_south.threat_south.caption = math.floor(global.bb_threat["south_biters"])
			end
		end
	end
	global.gui_refresh_delay = game.tick + 5
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
		Public.refresh()
		game.permissions.get_group("Default").add_player(player)
		local msg = table.concat({"Team ", player.force.name, " player ", player.name, " is no longer spectating."})
		game.print(msg, {r = 0.98, g = 0.66, b = 0.22})
		Server.to_discord_bold(msg)
		global.spectator_rejoin_delay[player.name] = game.tick
		player.spectator = false
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
	clear_copy_history(player)
	player.gui.left.bb_main_gui.destroy()
	Public.refresh()
end

function spectate(player, forced_join)
	if not player.character then return end
	if not forced_join then
		if global.tournament_mode then player.print("The game is set to tournament mode. Teams can only be changed via team manager.", {r = 0.98, g = 0.66, b = 0.22}) return end
	end
	player.teleport(player.surface.find_non_colliding_position("character", {0,0}, 4, 1))
	player.force = game.forces.spectator
	player.character.destructible = false
	if not forced_join then
		local msg = player.name .. " is spectating."
		game.print(msg, {r = 0.98, g = 0.66, b = 0.22})
		Server.to_discord_bold(msg)
	end
	game.permissions.get_group("spectator").add_player(player)
	global.spectator_rejoin_delay[player.name] = game.tick
	Public.update_or_create_main_gui(player)
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
	local player = game.players[event.player_index]
	local name = event.element.name
	if name == "bb_toggle_button" then
		if player.gui.left["bb_main_gui"].visible then
			player.gui.left["bb_main_gui"].visible = false
		else
			player.gui.left["bb_main_gui"].visible = true
			Public.update_main_gui(player)
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

	if name == "bb_spectate" then
		if player.spectator then
			join_team(player, global.chosen_team[player.name])
		else
			if player.position.y ^ 2 + player.position.x ^ 2 < 12000 then
				spectate(player)
			else
				player.print("You are too far away from spawn to spectate.",{ r=0.98, g=0.66, b=0.22})
			end
		end
		return
	end

	if name == "bb_players" then
		global.bb_view_players[player.name] = not global.bb_view_players[player.name]
		Public.update_main_gui(player)
	end
end

local function on_player_joined_game(event)
	local player = game.players[event.player_index]

	if not global.bb_view_players then global.bb_view_players = {} end
	if not global.chosen_team then global.chosen_team = {} end

	global.bb_view_players[player.name] = false

	if #game.connected_players > 1 then
		global.game_lobby_timeout = math.ceil(36000 / #game.connected_players)
	else
		global.game_lobby_timeout = 599940
	end

	create_sprite_button(player)
	Public.update_or_create_main_gui(player)
end


event.add(defines.events.on_gui_click, on_gui_click)
event.add(defines.events.on_player_joined_game, on_player_joined_game)

return Public
