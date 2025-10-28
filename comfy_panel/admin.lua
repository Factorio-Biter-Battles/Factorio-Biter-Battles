--antigrief things made by mewmew

local Event = require('utils.event')
local Jailed = require('utils.datastore.jail_data')
local Tabs = require('comfy_panel.main')
local Server = require('utils.server')
local Color = require('utils.color_presets')
local lower = string.lower
local closable_frame = require('utils.ui.closable_frame')

local function admin_only_message(str)
    for _, player in pairs(game.connected_players) do
        if is_admin(player) then
            player.print('Admins-only-message: ' .. str, { color = { r = 0.88, g = 0.88, b = 0.88 } })
        end
    end
end

local function jail(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    Jailed.try_ul_data(player.name, true, source_player.name)
end

local function free(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    Jailed.try_ul_data(player.name, false, source_player.name)
end

local bring_player_messages = {
    'Come here my friend!',
    'Papers, please.',
    'What are you up to?',
}

local function teleport_to_position(character, position, surface)
    if character.driving then
        character.driving = false
    end
    local pos = surface.find_non_colliding_position('character', position, 50, 1)
    if pos then
        character.teleport(pos, surface)
    end
    return pos ~= nil
end

local function bring_player(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end

    if
        not player.character
        or not teleport_to_position(player.character, source_player.physical_position, source_player.physical_surface)
    then
        return source_player.print(
            'Could not teleport player to your position.',
            { color = { r = 1, g = 0.5, b = 0.1 } }
        )
    end
    game.print(
        player.name
            .. ' has been teleported to '
            .. source_player.name
            .. '. '
            .. bring_player_messages[math.random(1, #bring_player_messages)],
        { color = { r = 0.98, g = 0.66, b = 0.22 } }
    )
end

local function bring_player_to_spawn(player, source_player)
    local spawn_position = player.force.get_spawn_position(player.physical_surface)
    if not spawn_position then
        return source_player.print('Spawn position not found.', { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    if not player.character or not teleport_to_position(player.character, spawn_position, player.physical_surface) then
        return source_player.print(
            'Could not teleport player to spawn position.',
            { color = { r = 1, g = 0.5, b = 0.1 } }
        )
    end
    game.print(player.name .. ' has been brought to spawn.', { color = { r = 0.98, g = 0.66, b = 0.22 } })
end

local go_to_player_messages = {
    'Papers, please.',
    'What are you up to?',
}
local function go_to_player(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    if
        source_player.character
        and teleport_to_position(source_player.character, player.physical_position, player.physical_surface)
    then
        game.print(
            source_player.name
                .. ' is visiting '
                .. player.name
                .. '. '
                .. go_to_player_messages[math.random(1, #go_to_player_messages)],
            { color = { r = 0.98, g = 0.66, b = 0.22 } }
        )
    end
end

local function spank(player, source_player)
    if player.character then
        if player.character.health > 1 then
            player.character.damage(1, 'player')
        end
        player.character.health = player.character.health - 5
        player.physical_surface.create_entity({ name = 'water-splash', position = player.physical_position })
        game.print(source_player.name .. ' spanked ' .. player.name, { color = { r = 0.98, g = 0.66, b = 0.22 } })
    end
end

local damage_messages = {
    ' recieved a love letter from ',
    ' recieved a strange package from ',
}
local function damage(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    if player.character then
        if player.character.health > 1 then
            player.character.damage(1, 'player')
        end
        player.character.health = player.character.health - 125
        player.physical_surface.create_entity({ name = 'big-explosion', position = player.physical_position })
        game.print(
            player.name .. damage_messages[math.random(1, #damage_messages)] .. source_player.name,
            { color = { r = 0.98, g = 0.66, b = 0.22 } }
        )
    end
end

local kill_messages = {
    ' did not obey the law.',
    ' should not have triggered the admins.',
    ' did not respect authority.',
    ' had a strange accident.',
    ' was struck by lightning.',
}
local function kill(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    if player.character then
        player.character.die('player')
        game.print(
            player.name .. kill_messages[math.random(1, #kill_messages)],
            { color = { r = 0.98, g = 0.66, b = 0.22 } }
        )
        admin_only_message(source_player.name .. ' killed ' .. player.name)
    end
end

local enemy_messages = {
    'Shoot on sight!',
    'Wanted dead or alive!',
}
local function enemy(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    if not game.forces.enemy_players then
        game.create_force('enemy_players')
    end
    player.force = game.forces.enemy_players
    game.print(
        player.name .. ' is now an enemy! ' .. enemy_messages[math.random(1, #enemy_messages)],
        { color = { r = 0.95, g = 0.15, b = 0.15 } }
    )
    admin_only_message(source_player.name .. ' has turned ' .. player.name .. ' into an enemy')
end

local function ally(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", { color = { r = 1, g = 0.5, b = 0.1 } })
    end
    player.force = game.forces.player
    game.print(player.name .. ' is our ally again!', { color = { r = 0.98, g = 0.66, b = 0.22 } })
    admin_only_message(source_player.name .. ' made ' .. player.name .. ' our ally')
end

local function turn_off_global_speakers(player)
    local counter = 0
    for _, surface in pairs(game.surfaces) do
        if surface.name ~= 'gulag' then
            local speakers = surface.find_entities_filtered({ name = 'programmable-speaker' })
            for i, speaker in pairs(speakers) do
                if speaker.parameters.playback_globally == true then
                    speaker.surface.create_entity({ name = 'massive-explosion', position = speaker.position })
                    speaker.die('player')
                    counter = counter + 1
                end
            end
        end
    end
    if counter == 0 then
        return
    end
    if counter == 1 then
        game.print(
            player.name .. ' has nuked ' .. counter .. ' global speaker.',
            { color = { r = 0.98, g = 0.66, b = 0.22 } }
        )
    else
        game.print(
            player.name .. ' has nuked ' .. counter .. ' global speakers.',
            { color = { r = 0.98, g = 0.66, b = 0.22 } }
        )
    end
end

local function delete_all_blueprints(player)
    local counter = 0
    for _, surface in pairs(game.surfaces) do
        for _, ghost in pairs(surface.find_entities_filtered({ type = { 'entity-ghost', 'tile-ghost' } })) do
            ghost.destroy()
            counter = counter + 1
        end
    end
    if counter == 0 then
        return
    end
    if counter == 1 then
        game.print(counter .. ' blueprint has been cleared!', { color = { r = 0.98, g = 0.66, b = 0.22 } })
    else
        game.print(counter .. ' blueprints have been cleared!', { color = { r = 0.98, g = 0.66, b = 0.22 } })
    end
    admin_only_message(player.name .. ' has cleared all blueprints.')
end

local function create_mini_camera_gui(player, caption, position, surface)
    local frame = closable_frame.create_secondary_closable_frame(player, 'mini_camera', caption)
    surface = tonumber(surface)
    local camera = frame.add({
        type = 'camera',
        name = 'mini_cam_element',
        position = position,
        zoom = 0.6,
        surface_index = game.surfaces[surface].index,
    })
    camera.style.minimal_width = 640
    camera.style.minimal_height = 480
end

local function filter_brackets(str)
    return (string.find(str, '%[') ~= nil)
end

local function match_test(value, pattern)
    return lower(value:gsub('-', ' ')):find(pattern)
end

local function contains_text(key, value, search_text)
    if filter_brackets(search_text) then
        return false
    end
    if value then
        if not match_test(key[value], search_text) then
            return false
        end
    else
        if not match_test(key, search_text) then
            return false
        end
    end
    return true
end

local create_admin_panel = function(player, frame)
    frame.clear()

    local player_names = {}
    for _, p in pairs(game.connected_players) do
        table.insert(player_names, tostring(p.name))
    end
    table.insert(player_names, 'Select Player')

    local selected_index = #player_names
    if storage.admin_panel_selected_player_index then
        if storage.admin_panel_selected_player_index[player.name] then
            if player_names[storage.admin_panel_selected_player_index[player.name]] then
                selected_index = storage.admin_panel_selected_player_index[player.name]
            end
        end
    end

    local drop_down = frame.add({
        type = 'drop-down',
        name = 'admin_player_select',
        items = player_names,
        selected_index = selected_index,
    })
    drop_down.style.minimal_width = 326
    drop_down.style.right_padding = 12
    drop_down.style.left_padding = 12

    local t = frame.add({ type = 'table', column_count = 3 })
    local buttons = {
        t.add({
            type = 'button',
            caption = 'Jail',
            name = 'jail',
            tooltip = 'Jails the player, they will no longer be able to perform any actions except writing in chat.',
        }),
        t.add({ type = 'button', caption = 'Free', name = 'free', tooltip = 'Frees the player from jail.' }),
        t.add({
            type = 'button',
            caption = 'Bring Player',
            name = 'bring_player',
            tooltip = 'Teleports the selected player to your position.',
        }),
        t.add({
            type = 'button',
            caption = 'Make Enemy',
            name = 'enemy',
            tooltip = 'Sets the selected players force to enemy_players.          DO NOT USE IN PVP MAPS!!',
        }),
        t.add({
            type = 'button',
            caption = 'Make Ally',
            name = 'ally',
            tooltip = 'Sets the selected players force back to the default player force.           DO NOT USE IN PVP MAPS!!',
        }),
        t.add({
            type = 'button',
            caption = 'Go to Player',
            name = 'go_to_player',
            tooltip = 'Teleport yourself to the selected player.',
        }),
        t.add({
            type = 'button',
            caption = 'Spank',
            name = 'spank',
            tooltip = 'Hurts the selected player with minor damage. Can not kill the player.',
        }),
        t.add({
            type = 'button',
            caption = 'Damage',
            name = 'damage',
            tooltip = 'Damages the selected player with greater damage. Can not kill the player.',
        }),
        t.add({ type = 'button', caption = 'Kill', name = 'kill', tooltip = 'Kills the selected player instantly.' }),
        t.add({
            type = 'button',
            caption = 'MoveToSpawn',
            name = 'bring_player_to_spawn',
            tooltip = 'Teleports the selected player to spawn.',
        }),
    }
    for _, button in pairs(buttons) do
        button.style.font = 'default-bold'
        --button.style.font_color = { r=0.99, g=0.11, b=0.11}
        button.style.font_color = { r = 0.99, g = 0.99, b = 0.99 }
        button.style.minimal_width = 106
    end

    local line = frame.add({ type = 'line' })
    line.style.top_margin = 8
    line.style.bottom_margin = 8

    local l = frame.add({ type = 'label', caption = 'Global Actions:' })
    local t = frame.add({ type = 'table', column_count = 2 })
    local buttons = {
        t.add({
            type = 'button',
            caption = 'Destroy global speakers',
            name = 'turn_off_global_speakers',
            tooltip = 'Destroys all speakers that are set to play sounds globally.',
        }),
        t.add({
            type = 'button',
            caption = 'Delete blueprints',
            name = 'delete_all_blueprints',
            tooltip = 'Deletes all placed blueprints on the map.',
        }),
        ---	t.add({type = "button", caption = "Cancel all deconstruction orders", name = "remove_all_deconstruction_orders"})
    }
    for _, button in pairs(buttons) do
        button.style.font = 'default-bold'
        button.style.font_color = { r = 0.98, g = 0.66, b = 0.22 }
        button.style.minimal_width = 80
    end

    local line = frame.add({ type = 'line' })
    line.style.top_margin = 8
    line.style.bottom_margin = 8
end

local admin_functions = {
    ['jail'] = jail,
    ['free'] = free,
    ['bring_player'] = bring_player,
    ['bring_player_to_spawn'] = bring_player_to_spawn,
    ['spank'] = spank,
    ['damage'] = damage,
    ['kill'] = kill,
    ['enemy'] = enemy,
    ['ally'] = ally,
    ['go_to_player'] = go_to_player,
}

local admin_global_functions = {
    ['turn_off_global_speakers'] = turn_off_global_speakers,
    ['delete_all_blueprints'] = delete_all_blueprints,
}

local function get_surface_from_string(str)
    if not str then
        return
    end
    if str == '' then
        return
    end
    str = string.lower(str)
    local start = string.find(str, 'surface:')
    local sname = string.len(str)
    local surface = string.sub(str, start + 8, sname)
    if not surface then
        return false
    end

    return surface
end

---@param str string?
---@return MapPosition?
local function get_position_from_string(str)
    if not str then
        return
    end
    if str == '' then
        return
    end
    str = string.lower(str)
    local x_pos = string.find(str, 'x:')
    local y_pos = string.find(str, 'y:')
    if not x_pos then
        return
    end
    if not y_pos then
        return
    end
    x_pos = x_pos + 2
    y_pos = y_pos + 2

    local a = 1
    for i = 1, string.len(str), 1 do
        local s = string.sub(str, x_pos + i, x_pos + i)
        if not s then
            break
        end
        if string.byte(s) == 32 then
            break
        end
        a = a + 1
    end
    local x = string.sub(str, x_pos, x_pos + a)

    a = 1
    for i = 1, string.len(str), 1 do
        local s = string.sub(str, y_pos + i, y_pos + i)
        if not s then
            break
        end
        if string.byte(s) == 32 then
            break
        end
        a = a + 1
    end

    local y = string.sub(str, y_pos, y_pos + a)
    return { x = tonumber(x), y = tonumber(y) }
end

local function on_gui_click(event)
    local player = game.get_player(event.player_index)
    local frame = Tabs.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end

    if not event.element.valid then
        return
    end

    local name = event.element.name

    if name == 'mini_camera' or name == 'mini_cam_element' then
        player.gui.screen['mini_camera'].destroy()
        return
    end

    if frame.name ~= 'Admin' then
        return
    end

    if admin_functions[name] then
        local target_player_name = frame['admin_player_select'].items[frame['admin_player_select'].selected_index]
        if not target_player_name then
            return
        end
        if target_player_name == 'Select Player' then
            player.print('No target player selected.', { color = { r = 0.88, g = 0.88, b = 0.88 } })
            return
        end
        local target_player = game.get_player(target_player_name)
        if target_player.connected == true then
            admin_functions[name](target_player, player)
        end
        return
    end

    if admin_global_functions[name] then
        admin_global_functions[name](player)
        return
    end

    if not frame then
        return
    end
    if not event.element.caption then
        return
    end
    local position = get_position_from_string(event.element.caption)
    if not position then
        return
    end

    local surface = get_surface_from_string(event.element.caption)
    if not surface then
        return
    end

    if player.gui.screen['mini_camera'] then
        if player.gui.screen['mini_camera'].caption == event.element.caption then
            player.gui.screen['mini_camera'].destroy()
            return
        end
    end

    create_mini_camera_gui(player, event.element.caption, position, surface)
end

local function on_gui_selection_state_changed(event)
    local player = game.get_player(event.player_index)
    local name = event.element.name
    if name == 'admin_player_select' then
        if not storage.admin_panel_selected_player_index then
            storage.admin_panel_selected_player_index = {}
        end
        storage.admin_panel_selected_player_index[player.name] = event.element.selected_index

        local frame = Tabs.comfy_panel_get_active_frame(player)
        if not frame then
            return
        end
        if frame.name ~= 'Admin' then
            return
        end

        create_admin_panel(player, frame)
    end
end

comfy_panel_tabs['Admin'] = { gui = create_admin_panel, admin = true }

commands.add_command('kill', 'Kill a player. Usage: /kill <name>', function(cmd)
    if not cmd.player_index then
        return
    end
    local killer = game.get_player(cmd.player_index)
    if not killer then
        return
    end
    if cmd.parameter then
        local victim = game.get_player(cmd.parameter)
        if is_admin(killer) and victim and victim.valid then
            kill(victim, killer)
        elseif not victim or not victim.valid then
            killer.print('Invalid name', { color = Color.warning })
        else
            killer.print('Only admins have licence for killing!', { color = Color.warning })
        end
    else
        killer.print('Usage: /kill <name>', { color = Color.warning })
    end
end)

commands.add_command('punish', 'Kill and ban a player. Usage: /punish <name> <reason>', function(cmd)
    if not cmd.player_index then
        return
    end
    local punisher = game.get_player(cmd.player_index)
    if not punisher then
        return
    end
    local t = {}
    local message
    if is_admin(punisher) and cmd.parameter then
        for i in string.gmatch(cmd.parameter, '%S+') do
            t[#t + 1] = i
        end
        local offender = game.get_player(t[1])
        table.remove(t, 1)
        message = table.concat(t, ' ')
        if offender.valid and string.len(message) > 5 then
            Server.to_discord_embed(
                offender.name .. ' was banned by ' .. punisher.name .. '. ' .. 'Reason: ' .. message
            )
            message = message .. ' Appeal on discord. Link on biterbattles.org', Color.warning
            if offender.force.name == 'spectator' then
                join_team(offender, storage.chosen_team[offender.name], true)
            end -- switches offender to their team if he's spectating
            kill(offender, punisher)
            game.ban_player(offender, message)
        elseif not offender.valid then
            punisher.print('Invalid name', { color = Color.warning })
        else
            punisher.print('No valid reason given, or reason is too short', { color = Color.warning })
        end
    elseif not is_admin(punisher) then
        punisher.print('This is admin only command', { color = Color.warning })
    else
        punisher.print('Usage: /punish <name> <reason>', { color = Color.warning })
    end
end)

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
