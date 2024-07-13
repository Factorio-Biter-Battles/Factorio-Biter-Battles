local CaptainTaskGroup = {}
local gui_style = require 'utils.utils'.gui_style
local closable_frame = require "utils.ui.closable_frame"
local player_utils = require "utils.player"
local max_num_organization_groups = 11

function CaptainTaskGroup.get_max_num_organization_groups()
	return max_num_organization_groups
end

---@param names string[]
---@return string
local function pretty_print_player_list(names)
	return table.concat(player_utils.get_sorted_colored_player_list(player_utils.get_lua_players_from_player_names(names)), ", ")
end

local function isStringInTable(tab, str)
	for _, entry in ipairs(tab) do
		if entry == str then
			return true
		end
	end
	return false
end

function CaptainTaskGroup.destroy_team_organization_gui(player)
	if player.gui.top["captain_team_organization_toggle_button"] then player.gui.top["captain_team_organization_toggle_button"].destroy() end
	if player.gui.screen["group_selection"] then player.gui.screen["group_selection"].destroy() end
end

function CaptainTaskGroup.team_organization_can_edit_all(player)
	return isStringInTable(global.special_games_variables["captain_mode"]["captainList"], player.name)
end

function CaptainTaskGroup.team_organization_can_edit_group_name(player, group)
	return group and group.player_order[1] == player.name
end

function CaptainTaskGroup.update_list_of_players_without_task(force)
    local special = global.special_games_variables["captain_mode"]
    local groupsOrganization = special["groupsOrganization"][force.name]
    if groupsOrganization == nil then return end
    local playersWithoutTask = {}
    local playersWithTask = {}
    for i = 1, max_num_organization_groups do
        local players_list = groupsOrganization[i].player_order
        for _, player in ipairs(players_list) do
            playersWithTask[player] = true
        end
    end
    for _, player in pairs(force.players) do
        if not playersWithTask[player.name] then
            table.insert(playersWithoutTask, player.name)
        end
    end
    return playersWithoutTask
end

function CaptainTaskGroup.update_team_organization_gui_player(player)
    local force = player.force
    local special = global.special_games_variables["captain_mode"]
    local groupsOrganization = special["groupsOrganization"][force.name] or {}
    local frame = player.gui.screen["group_selection"]
    if not frame then return end
    local gui_table = frame.group_scroll.group_table
    
    for i = 1, max_num_organization_groups do
        local group = groupsOrganization[i] or {name = "Group " .. i, players = {}, player_order = {}}
        local player_group = nil
        
        -- Update group name
        local name_label = gui_table["group_name_" .. i]
        if name_label then
            name_label.caption = "[color=acid]" .. group.name .. "[/color]"
        end
        
        -- Update player list
        local player_list = gui_table["player_list_" .. i]
        if player_list then
            player_list.caption = pretty_print_player_list(group.player_order)
        end
        
        -- Show/hide captain controls and placeholders
        local set_button = gui_table["set_name_" .. i]
        local name_field = gui_table["task_name_field_" .. i]
        local placeholder1 = gui_table["placeholder1_" .. i]
        local placeholder2 = gui_table["placeholder2_" .. i]
        if set_button and name_field and placeholder1 and placeholder2 then
            if group.players[player.name] then player_group = group	end
            if CaptainTaskGroup.team_organization_can_edit_all(player) or CaptainTaskGroup.team_organization_can_edit_group_name(player, player_group) then
                set_button.visible = true
                name_field.visible = true
                placeholder1.visible = false
                placeholder2.visible = false
                name_field.text = group.name
                set_button.style.minimal_width = 50
                name_field.style.minimal_width = 100
            else
                set_button.visible = false
                name_field.visible = false
                placeholder1.visible = true
                placeholder2.visible = true
            end
        end
    end
    
    -- Update the list of players without task
    local list_players_without_task = frame.list_players_without_task
    if list_players_without_task then
        local listPlayersWithoutTask = table.concat((CaptainTaskGroup.update_list_of_players_without_task(force) or {}), ", ")
        list_players_without_task.caption = "Players without task : [color=red]" .. listPlayersWithoutTask .. "[/color]"
    end
end

function CaptainTaskGroup.create_team_organization_gui(player)
    local force = player.force
    
    if player.gui.screen["group_selection"] then
        player.gui.screen["group_selection"].destroy()
    end
    
    local frame = closable_frame.create_main_closable_frame(player, "group_selection", "Team organization of " .. force.name)
    local scroll = frame.add{type="scroll-pane", name="group_scroll"}
    local gui_table = scroll.add{type="table", name="group_table", column_count=5}
    
    gui_table.add{type="label", caption="[color=yellow]Set name[/color]"}
    gui_table.add{type="label", caption="[color=yellow]Edit name[/color]"}
    gui_table.add{type="label", caption="[color=blue]Join task group[/color]"}
    gui_table.add{type="label", caption="[color=acid]Task name[/color]"}
    gui_table.add{type="label", caption="[color=blue]Player list[/color]"}
    for i = 1, max_num_organization_groups do
        gui_table.add{type="button", name="set_name_" .. i, caption="Set"}
        gui_table.add{type="textfield", name="task_name_field_" .. i}
        gui_table.add{type="empty-widget", name="placeholder1_" .. i}
        gui_table.add{type="empty-widget", name="placeholder2_" .. i}
        gui_table.add{type="button", name="join_group_" .. i, caption="Join"}
        gui_table.add{type="label", name="group_name_" .. i}
        gui_table.add{type="label", name="player_list_" .. i}
    end
    
    local bottom_flow = frame.add{type="flow", name="bottom_flow", direction="horizontal"}
    bottom_flow.style.horizontal_align = "center"
    bottom_flow.add{type="button", name="leave_task_group", caption="Leave task group"}

    frame.add{type="label", name="list_players_without_task"}

    -- Call update function to populate dynamic content
    CaptainTaskGroup.update_team_organization_gui_player(player)
end

function CaptainTaskGroup.draw_captain_team_organization_button(player)
	if player.gui.top["captain_team_organization_toggle_button"] then player.gui.top["captain_team_organization_toggle_button"].destroy() end
	local button = player.gui.top.add({type = "sprite-button", name = "captain_team_organization_toggle_button", caption = "Team organization"})
	button.style.font = "heading-2"
	button.style.font_color = {r = 0.88, g = 0.55, b = 0.11}
	gui_style(button, {width = 160, height = 38, padding = -2})
end

function CaptainTaskGroup.update_team_organization_gui()
    for _, player in pairs(game.connected_players) do
        if player.gui.screen["group_selection"] then
            CaptainTaskGroup.update_team_organization_gui_player(player)
        end
    end
end

return CaptainTaskGroup