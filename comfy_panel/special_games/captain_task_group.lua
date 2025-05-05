local CaptainUtils = require('comfy_panel.special_games.captain_utils')
local ClosableFrame = require('utils.ui.closable_frame')
local Color = require('utils.color_presets')
local Event = require('utils.event')
local Gui = require('utils.gui')
local gui_style = require('utils.utils').gui_style
local frame_style = require('utils.utils').left_frame_style
local concat, insert, remove = table.concat, table.insert, table.remove
local table_contains = CaptainUtils.table_contains
local string_sub = string.sub

local CaptainTaskGroup = {}

local max_num_organization_groups = 11

local function get_active_tournament_frame(player, frame_name)
    local gui = player.gui.screen
    if gui.captain_tournament_frame and gui.captain_tournament_frame.frame.sp[frame_name] then
        return gui.captain_tournament_frame.frame.sp[frame_name].flow.frame
    end
    return gui[frame_name]
end

function CaptainTaskGroup.get_max_num_organization_groups()
    return max_num_organization_groups
end

function CaptainTaskGroup.team_organization_can_edit_all(player)
    return table_contains(storage.special_games_variables.captain_mode.captainList, player.name)
end

function CaptainTaskGroup.team_organization_can_edit_group_name(player, group)
    return group and group.player_order[1] == player.name
end

function CaptainTaskGroup.remove_task_group(player, groupsOrganization)
    for i = 1, CaptainTaskGroup.get_max_num_organization_groups() do
        local group = groupsOrganization[i]
        if group and group.players then
            if group.players[player.name] then
                group.players[player.name] = nil
                for j, name in pairs(group.player_order) do
                    if name == player.name then
                        remove(group.player_order, j)
                        break
                    end
                end
            end
        end
    end
end

function CaptainTaskGroup.update_list_of_players_without_task(force)
    local special = storage.special_games_variables.captain_mode
    local groupsOrganization = special.groupsOrganization[force.name]
    if groupsOrganization == nil then
        return
    end
    local playersWithoutTask = {}
    local playersWithTask = {}
    for i = 1, max_num_organization_groups do
        local players_list = groupsOrganization[i].player_order
        for _, player in pairs(players_list) do
            playersWithTask[player] = true
        end
    end
    for _, player in pairs(force.players) do
        if not playersWithTask[player.name] then
            insert(playersWithoutTask, player.name)
        end
    end
    return playersWithoutTask
end

function CaptainTaskGroup.toggle_captain_organization_gui(player)
    if player.gui.screen.captain_organization_gui then
        storage.captain_ui[player.name].captain_organization_gui = false
        player.gui.screen.captain_organization_gui.destroy()
    else
        storage.captain_ui[player.name].captain_organization_gui = true
        CaptainTaskGroup.draw_captain_organization_gui(player)
    end
end

function CaptainTaskGroup.draw_captain_organization_gui(player, main_frame)
    if not main_frame then
        if player.gui.screen.captain_organization_gui then
            player.gui.screen.captain_organization_gui.destroy()
        end
        main_frame = ClosableFrame.create_draggable_frame(player, 'captain_organization_gui', 'Team Organization')
    end

    local scroll = main_frame.add({ type = 'scroll-pane', name = 'group_scroll' })
    local gui_table = scroll.add({ type = 'table', name = 'group_table', column_count = 5 })
    gui_style(scroll, { horizontally_squashable = false, maximal_height = 500 })

    gui_table.add({ type = 'label', caption = '[color=yellow]Set name[/color]' })
    gui_table.add({ type = 'label', caption = '[color=yellow]Edit name[/color]' })
    gui_table.add({ type = 'label', caption = '[color=blue]Join task group[/color]' })
    gui_table.add({ type = 'label', caption = '[color=acid]Task name[/color]' })
    gui_table.add({ type = 'label', caption = '[color=blue]Player list[/color]' })

    for i = 1, max_num_organization_groups do
        gui_table.add({ type = 'button', name = 'cpt_task_set_name_' .. i, caption = 'Set' })
        gui_table.add({ type = 'textfield', name = 'task_name_field_' .. i })
        gui_table.add({ type = 'empty-widget', name = 'placeholder1_' .. i })
        gui_table.add({ type = 'empty-widget', name = 'placeholder2_' .. i })
        gui_table.add({ type = 'button', name = 'cpt_task_join_group_' .. i, caption = 'Join' })
        gui_table.add({ type = 'label', name = 'group_name_' .. i })
        gui_table.add({ type = 'label', name = 'player_list_' .. i })
    end

    local bottom_flow = main_frame.add({ type = 'flow', name = 'bottom_flow', direction = 'horizontal' })
    bottom_flow.style.horizontal_align = 'center'
    bottom_flow.add({ type = 'button', name = 'cpt_task_leave_group', caption = 'Leave task group' })

    main_frame.add({ type = 'label', name = 'list_players_without_task' })

    -- Call update function to populate dynamic content
    CaptainTaskGroup.update_captain_organization_gui(player, main_frame)
end

function CaptainTaskGroup.update_captain_organization_gui(player, frame)
    if not frame then
        frame = get_active_tournament_frame(player, 'captain_organization_gui')
    end
    if not (frame and frame.visible) then
        return
    end

    local force = player.force
    local force_name = force.name
    if force_name == 'spectator' then
        force_name = storage.chosen_team[player.name]
    end
    local special = storage.special_games_variables.captain_mode
    local groupsOrganization = special.groupsOrganization[force_name] or {}
    if not groupsOrganization then
        frame.destroy()
        return
    end
    local gui_table = frame.group_scroll.group_table

    for i = 1, max_num_organization_groups do
        local group = groupsOrganization[i] or { name = 'Group ' .. i, players = {}, player_order = {} }
        local player_group = nil

        -- Update group name
        local name_label = gui_table['group_name_' .. i]
        if name_label then
            name_label.caption = '[color=acid]' .. group.name .. '[/color]'
        end

        -- Update player list
        local player_list = gui_table['player_list_' .. i]
        if player_list then
            player_list.caption = CaptainUtils.pretty_print_player_list(group.player_order)
        end

        -- Show/hide captain controls and placeholders
        local set_button = gui_table['cpt_task_set_name_' .. i]
        local name_field = gui_table['task_name_field_' .. i]
        local placeholder1 = gui_table['placeholder1_' .. i]
        local placeholder2 = gui_table['placeholder2_' .. i]
        if set_button and name_field and placeholder1 and placeholder2 then
            if group.players[player.name] then
                player_group = group
            end
            if
                CaptainTaskGroup.team_organization_can_edit_all(player)
                or CaptainTaskGroup.team_organization_can_edit_group_name(player, player_group)
            then
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
        local listPlayersWithoutTask = concat((CaptainTaskGroup.update_list_of_players_without_task(force) or {}), ', ')
        list_players_without_task.caption = 'Players without task : [color=red]' .. listPlayersWithoutTask .. '[/color]'
    end
end

function CaptainTaskGroup.update_all_captain_organization_gui()
    for _, player in pairs(game.connected_players) do
        CaptainTaskGroup.update_captain_organization_gui(player)
    end
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end
    local special = storage.special_games_variables.captain_mode
    if not special then
        return
    end
    local player = CaptainUtils.cpt_get_player(event.player_index)
    if not player then
        return
    end

    local force = player.force
    local groupsOrganization = special.groupsOrganization[force.name]
    if not groupsOrganization then
        return
    end

    local name = element.name
    if name:sub(1, 20) == 'cpt_task_join_group_' then
        local group_index = tonumber(name:sub(21))
        CaptainTaskGroup.remove_task_group(player, groupsOrganization)
        -- Add player to new group
        if not groupsOrganization[group_index] then
            groupsOrganization[group_index] = { name = 'Group ' .. group_index, players = {}, player_order = {} }
        end
        groupsOrganization[group_index].players[player.name] = true
        insert(groupsOrganization[group_index].player_order, player.name)
        CaptainTaskGroup.update_all_captain_organization_gui()
    elseif name == 'cpt_task_leave_group' then
        CaptainTaskGroup.remove_task_group(player, groupsOrganization)
        CaptainTaskGroup.update_all_captain_organization_gui()
    elseif name:sub(1, 18) == 'cpt_task_set_name_' then
        -- For captains who can edit all
        local group_index = tonumber(name:sub(19))
        if group_index ~= nil then
            local frame = get_active_tournament_frame(player, 'captain_organization_gui')
            local name_field = frame.group_scroll.group_table['task_name_field_' .. group_index]
            local new_name = name_field.text
            if groupsOrganization[group_index].name ~= new_name then
                groupsOrganization[group_index].name = new_name
                player.force.print(player.name .. ' has set task name to ' .. new_name)
                CaptainTaskGroup.update_all_captain_organization_gui()
            else
                player.print('You cant set the task name with same one as before !!', { color = Color.warning })
            end
        end
    elseif name:find('^task_name_field') then
        if #element.text > 40 then
            player.print('Task name must be 40 characters or less', { color = Color.warning })
            element.text = string_sub(element.text, 1, 40)
        end
    end
end

Event.add(defines.events.on_gui_click, on_gui_click)

return CaptainTaskGroup
