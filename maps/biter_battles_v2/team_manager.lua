local Public = {}
local Functions = require "maps.biter_battles_v2.functions"
local Server = require 'utils.server'
local Gui = require 'utils.gui'
local gui_style = require 'utils.utils'.gui_style
local closable_frame = require "utils.ui.closable_frame"
local forces = {
	{name = "north", color = {r = 0, g = 0, b = 200}},
	{name = "spectator", color = {r = 111, g = 111, b = 111}},
	{name = "south",	color = {r = 200, g = 0, b = 0}},
}

local function get_player_array(force_name)
	local a = {}	
	for _, p in pairs(game.forces[force_name].connected_players) do a[#a + 1] = p.name end
	return a
end

function Public.freeze_players()
	if not global.freeze_players then return end
	global.team_manager_default_permissions = {}
	local p = game.permissions.get_group("Default")	
	for action_name, _ in pairs(defines.input_action) do
		global.team_manager_default_permissions[action_name] = p.allows_action(defines.input_action[action_name])
		p.set_allows_action(defines.input_action[action_name], false)
	end	
	local defs = {
		defines.input_action.write_to_console,
		defines.input_action.gui_checked_state_changed,
		defines.input_action.gui_click,
		defines.input_action.gui_confirmed,
		defines.input_action.gui_elem_changed,
		defines.input_action.gui_location_changed,
		defines.input_action.gui_selected_tab_changed,
		defines.input_action.gui_selection_state_changed,
		defines.input_action.gui_switch_state_changed,
		defines.input_action.gui_text_changed,
		defines.input_action.gui_value_changed,
		defines.input_action.edit_permission_group,
		defines.input_action.delete_custom_tag,
		defines.input_action.edit_custom_tag
	}
	for _, d in pairs(defs) do p.set_allows_action(d, true) end
end

function Public.unfreeze_players()
	local p = game.permissions.get_group("Default") 
	for action_name, _ in pairs(defines.input_action) do
		if global.team_manager_default_permissions[action_name] then
			p.set_allows_action(defines.input_action[action_name], true)
		end
	end
end

local function leave_corpse(player)
	if not player.character then return end
	
	local inventories = {
		player.get_inventory(defines.inventory.character_main),
		player.get_inventory(defines.inventory.character_guns),
		player.get_inventory(defines.inventory.character_ammo),
		player.get_inventory(defines.inventory.character_armor),
		player.get_inventory(defines.inventory.character_vehicle),
		player.get_inventory(defines.inventory.character_trash),
	}
	
	local corpse = false
	for _, i in pairs(inventories) do
		for index = 1, #i, 1 do
			if not i[index].valid then break end
			corpse = true
			break
		end
		if corpse then
			player.character.die()
			break
		end
	end
	
	if player.character then player.character.destroy() end	
	player.character = nil
	player.set_controller({type=defines.controllers.god})
	player.create_character()	
end

function Public.switch_force(player_name, force_name)
	if not game.get_player(player_name) then game.print("Team Manager >> Player " .. player_name .. " does not exist.", {r=0.98, g=0.66, b=0.22}) return end
	if not game.forces[force_name] then game.print("Team Manager >> Force " .. force_name .. " does not exist.", {r=0.98, g=0.66, b=0.22}) return end
	
	local player = game.get_player(player_name)
	player.force = game.forces[force_name]
				
	game.print(player_name .. " has been switched into " .. Functions.team_name_with_color(force_name) .. ".", {r=0.98, g=0.66, b=0.22})
    Server.to_discord_bold(player_name .. " has joined team " .. force_name .. "!")
	
	leave_corpse(player)
	
	global.chosen_team[player_name] = nil	
	if force_name == "spectator" then	
		spectate(player, true)		
	else
		join_team(player, force_name, true)
	end
end

function Public.draw_top_toggle_button(player)
	if player.gui.top["team_manager_toggle_button"] then player.gui.top["team_manager_toggle_button"].destroy() end	
	local button = Gui.add_mod_button(player, {type = "sprite-button", name = "team_manager_toggle_button", sprite = "utility/force_editor_icon", tooltip = "Team Manager", index = 7})
end

local function draw_manager_gui(player)
	if player.gui.screen["team_manager_gui"] then player.gui.screen["team_manager_gui"].destroy() end

	local frame = closable_frame.create_main_closable_frame(player, "team_manager_gui", "Manage Teams")

	local t = frame.add({type = "table", name = "team_manager_root_table", column_count = 5})

	local i2 = 1
	for i = 1, #forces * 2 - 1, 1 do
		if i % 2 == 1 then
			local l = t.add({type = "sprite-button", caption = string.upper(forces[i2].name), name = forces[i2].name})
			l.style.minimal_width = 160
			l.style.maximal_width = 160
			l.style.font_color = forces[i2].color
			l.style.font = "heading-1"
			i2 = i2 + 1
		else
			local tt = t.add({type = "label", caption = " "})
		end
	end

	local i2 = 1
	for i = 1, #forces * 2 - 1, 1 do
		if i % 2 == 1 then
			local list_box = t.add({type = "list-box", name = "team_manager_list_box_" .. i2, items = get_player_array(forces[i2].name)})
			list_box.style.minimal_height = 360
			list_box.style.minimal_width = 160
			list_box.style.maximal_height = 480
			i2 = i2 + 1
		else
			local tt = t.add({type = "table", column_count = 1})
			local b = tt.add({type = "sprite-button", name = i2 - 1, caption = "→"})
			b.style.font = "heading-1"
			b.style.maximal_height = 38
			b.style.maximal_width = 38
			local b = tt.add({type = "sprite-button", name = i2, caption = "←"})
			b.style.font = "heading-1"
			b.style.maximal_height = 38
			b.style.maximal_width = 38
		end
	end

	local flow = frame.add({type = "flow"})
	flow.style.horizontal_align = "center"
	flow.style.horizontally_stretchable = true
	flow.style.top_margin = 8
	local t = flow.add({type = "table", name = "team_manager_bottom_buttons", column_count = 3})

	if global.tournament_mode then
		button = t.add({
			type = "button",
			name = "team_manager_activate_tournament",
			caption = "Tournament Mode Enabled",
			tooltip = "Only admins can move players and vote for difficulty.\nActive players can no longer go spectate.\nNew joining players are spectators."
		})
		button.style.font_color = {r = 222, g = 22, b = 22}
	else
		button = t.add({
			type = "button",
			name = "team_manager_activate_tournament",
			caption = "Tournament Mode Disabled",
			tooltip = "Only admins can move players. Active players can no longer go spectate. New joining players are spectators."
		})
		button.style.font_color = {r = 55, g = 55, b = 55}
	end
	button.style.font = "heading-2"

	if global.freeze_players then
		button = t.add({
			type = "button",
			name = "team_manager_freeze_players",
			caption = "Unfreeze Players",
			tooltip = "Releases all players."
		})
		button.style.font_color = {r = 222, g = 22, b = 22}
	else
		button = t.add({
			type = "button",
			name = "team_manager_freeze_players",
			caption = "Freeze Players",
			tooltip = "Freezes all players, unable to perform actions, until released."
		})
		button.style.font_color = {r = 55, g = 55, b = 222}
	end
	button.style.font = "heading-2"

	if global.training_mode then
		button = t.add({
			type = "button",
			name = "team_manager_activate_training",
			caption = "Training Mode Activated",
			tooltip = "Feed your own team's biters and only teams with players gain threat & evo."
		})
		button.style.font_color = {r = 222, g = 22, b = 22}
	else
		button = t.add({
			type = "button",
			name = "team_manager_activate_training",
			caption = "Training Mode Disabled",
			tooltip = "Feed your own team's biters and only teams with players gain threat & evo."
		})
		button.style.font_color = {r = 55, g = 55, b = 55}
	end
	button.style.font = "heading-2"
end

local function set_custom_team_name(force_name, team_name)
	if team_name == "" then global.tm_custom_name[force_name] = nil return end
	if not team_name then global.tm_custom_name[force_name] = nil return end
	global.tm_custom_name[force_name] = tostring(team_name)
end

function Public.custom_team_name_gui(player, force_name)
	local frame = closable_frame.create_secondary_closable_frame(player, "custom_team_name_gui", "Set custom team name:")
	if not frame then return end
	local text = Functions.team_name(force_name)
	
	local textfield = frame.add({ type = "textfield", name = "textfield" .. force_name, text = text })
	local button = frame.add({
			type = "button",
			name = "custom_team_name_gui_set",
			caption = "Set",
			tooltip = "Set custom team name."
	})
	button.style.font = "heading-2"
end

local function isReferee(player)
	if global.active_special_games["captain_mode"] and global.special_games_variables["captain_mode"]["refereeName"] == player.name then
		return true
	else
		return false
	end
end

local function team_manager_gui_click(event)
	local player = game.get_player(event.player_index)
	local name = event.element.name
	
	if game.forces[name] then
		if not player.admin then player.print("Only admins can change team names.", {r = 175, g = 0, b = 0}) return end
		Public.custom_team_name_gui(player, name)
		return
	end
	
	if name == "team_manager_activate_tournament" then
		if not player.admin then player.print("Only admins can switch tournament mode.", {r = 175, g = 0, b = 0}) return end
		if global.active_special_games["captain_mode"] == true and global.special_games_variables["captain_mode"]["prepaPhase"] == true then player.print("You cant disable tournament mode during prepa phase of captain event !", {r = 175, g = 0, b = 0}) return end
		if global.tournament_mode then
			global.tournament_mode = false
			draw_manager_gui(player)
			game.print(">>> Tournament Mode has been disabled.", {r = 111, g = 111, b = 111})
			return
		end
		global.tournament_mode = true
		draw_manager_gui(player)
		game.print(">>> Tournament Mode has been enabled!", {r = 225, g = 0, b = 0})
		return
	end
	
	if name == "team_manager_freeze_players" then
		if global.freeze_players then
			if not player.admin then player.print("Only admins can unfreeze players.", {r = 175, g = 0, b = 0}) return end
			if global.active_special_games["captain_mode"] == true and global.special_games_variables["captain_mode"]["prepaPhase"] == true then player.print("You cant unfreeze during prepa phase of captain event !", {r = 175, g = 0, b = 0}) return end
			global.freeze_players = false
			draw_manager_gui(player)
			game.print(">>> Players have been unfrozen!", {r = 255, g = 77, b = 77})
			Public.unfreeze_players()
			return
		end
		if not player.admin then player.print("Only admins can freeze players.", {r = 175, g = 0, b = 0}) return end
		global.freeze_players = true
		draw_manager_gui(player)
		game.print(">>> Players have been frozen!", {r = 111, g = 111, b = 255})
		Public.freeze_players()
		return
	end
	
	if name == "team_manager_activate_training" then
		if not player.admin then player.print("Only admins can switch training mode.", {r = 175, g = 0, b = 0}) return end
		if global.training_mode then
			global.training_mode = false
			draw_manager_gui(player)
			game.print(">>> Training Mode has been disabled.", {r = 111, g = 111, b = 111})
			return
		end
		global.training_mode = true
		draw_manager_gui(player)
		game.print(">>> Training Mode has been enabled!", {r = 225, g = 0, b = 0})
		return
	end
	
	if not event.element.parent then return end
	local element = event.element.parent
	if not element.parent then return end
	local element = element.parent
	if element.name ~= "team_manager_root_table" then return end		
	if not player.admin and not isReferee(player) then player.print("Only admins can manage teams.", {r = 175, g = 0, b = 0}) return end
	
	local listbox = player.gui.screen["team_manager_gui"]["team_manager_root_table"]["team_manager_list_box_" .. tonumber(name)]
	local selected_index = listbox.selected_index
	if selected_index == 0 then player.print("No player selected.", {r = 175, g = 0, b = 0}) return end
	local player_name = listbox.items[selected_index]
	
	local m = -1
	if event.element.caption == "→" then m = 1 end
	local force_name = forces[tonumber(name) + m].name
	
	Public.switch_force(player_name, force_name)
	
	draw_manager_gui(player)
end

function Public.gui_click(event)	
	if not event.element then return end
	if not event.element.valid then return end
	local player = game.get_player(event.player_index)
	local name = event.element.name
	
	if name == "team_manager_toggle_button" then
		if player.gui.screen["team_manager_gui"] then player.gui.screen["team_manager_gui"].destroy() return end
		draw_manager_gui(player)
		return
	end
	
	if player.gui.screen["team_manager_gui"] then team_manager_gui_click(event) end
	
	if player.gui.screen["custom_team_name_gui"] then
		if name == "custom_team_name_gui_set" then
			local custom_name = player.gui.screen["custom_team_name_gui"].children[2].text
			local force_name = string.sub(player.gui.screen["custom_team_name_gui"].children[2].name, 10)
			set_custom_team_name(force_name, custom_name)
			player.gui.screen["custom_team_name_gui"].destroy()
			return
		end
	end	
end

return Public
