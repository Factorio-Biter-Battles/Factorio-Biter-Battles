--antigrief things made by mewmew

local Event = require 'utils.event'
local Jailed = require 'utils.datastore.jail_data'
local Tabs = require 'comfy_panel.main'
local AntiGrief = require 'antigrief'
local Server = require 'utils.server'
local Color = require 'utils.color_presets'
local lower = string.lower
local Session = require 'utils.datastore.session_data'
local show_inventory = require 'modules.show_inventory'

local this = {
    sorting_method = {},
    player_search_text = {},
    history_search_text = {},
    waiting_for_gps = {},
    filter_by_gps = {}
}
global.custom_permissions = {
    disable_sci = {},
    disable_join = {}
}

local function admin_only_message(str)
    for _, player in pairs(game.connected_players) do
        if player.admin == true then
            player.print('Admins-only-message: ' .. str, {r = 0.88, g = 0.88, b = 0.88})
        end
    end
end

local function jail(player, source_player, button)
    if player.name == source_player.name then
        --return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    Jailed.jail(source_player.name, player.name, "Jailed with admin panel")
    button.name = "jail"
    button.caption = "Jail"
end

local function free(player, source_player, button)
    if player.name == source_player.name then
        --return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    Jailed.free(source_player.name, player.name)
    button.name = "free"
    button.caption = "Free"
end

local bring_player_messages = {
    'Come here my friend!',
    'Papers, please.',
    'What are you up to?'
}

local function bring_player(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if player.driving == true then
        player.driving = false
        return
    end
    local pos = source_player.surface.find_non_colliding_position('character', source_player.position, 50, 1)
    if pos then
        player.teleport(pos, source_player.surface)
        game.print(
            player.name ..
                ' has been teleported to ' ..
                    source_player.name .. '. ' .. bring_player_messages[math.random(1, #bring_player_messages)],
            {r = 0.98, g = 0.66, b = 0.22}
        )
    end
end

local go_to_player_messages = {
    'Papers, please.',
    'What are you up to?'
}
local function go_to_player(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    local pos = player.surface.find_non_colliding_position('character', player.position, 50, 1)
    if pos then
        source_player.teleport(pos, player.surface)
        game.print(
            source_player.name ..
                ' is visiting ' .. player.name .. '. ' .. go_to_player_messages[math.random(1, #go_to_player_messages)],
            {r = 0.98, g = 0.66, b = 0.22}
        )
    end
end

local function spank(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if player.character then
        if player.character.health > 1 then
            player.character.damage(1, 'player')
        end
        player.character.health = player.character.health - 5
        player.surface.create_entity({name = 'water-splash', position = player.position})
        game.print(source_player.name .. ' spanked ' .. player.name, {r = 0.98, g = 0.66, b = 0.22})
    end
end

local damage_messages = {
    ' recieved a love letter from ',
    ' recieved a strange package from '
}
local function damage(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if player.character then
        if player.character.health > 1 then
            player.character.damage(1, 'player')
        end
        player.character.health = player.character.health - 125
        player.surface.create_entity({name = 'big-explosion', position = player.position})
        game.print(
            player.name .. damage_messages[math.random(1, #damage_messages)] .. source_player.name,
            {r = 0.98, g = 0.66, b = 0.22}
        )
    end
end

local kill_messages = {
    ' did not obey the law.',
    ' should not have triggered the admins.',
    ' did not respect authority.',
    ' had a strange accident.',
    ' was struck by lightning.'
}
local function kill(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if player.character then
        player.character.die('player')
        game.print(player.name .. kill_messages[math.random(1, #kill_messages)], {r = 0.98, g = 0.66, b = 0.22})
        admin_only_message(source_player.name .. ' killed ' .. player.name)
    end
end

local enemy_messages = {
    'Shoot on sight!',
    'Wanted dead or alive!'
}
local function enemy(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if not game.forces.enemy_players then
        game.create_force('enemy_players')
    end
    player.force = game.forces.enemy_players
    game.print(
        player.name .. ' is now an enemy! ' .. enemy_messages[math.random(1, #enemy_messages)],
        {r = 0.95, g = 0.15, b = 0.15}
    )
    admin_only_message(source_player.name .. ' has turned ' .. player.name .. ' into an enemy')
end

local function ally(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    player.force = game.forces.player
    game.print(player.name .. ' is our ally again!', {r = 0.98, g = 0.66, b = 0.22})
    admin_only_message(source_player.name .. ' made ' .. player.name .. ' our ally')
end

local function freeze(player, source_player)
    if player.name == source_player.name then
       return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    game.permissions.get_group("frozen").add_player(player)
    game.print(source_player.name .. " has frozen " .. player.name .. "!")
end

local function unfreeze(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    local f = player.force.name
    if Jailed.exists(player.name) then game.permissions.get_group("gulag").add_player(player)
    elseif f == "north" or f == "south" then game.permissions.get_group("Default").add_player(player)
    else game.permissions.get_group("spectator").add_player(player) end
    game.print(source_player.name .. " has unfrozen " .. player.name .. "!")
end

local function open_inventory(player, source_player)
    if player.name == source_player.name then
        --return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    show_inventory.open_inventory(source_player, player)
end

local function show_on_map(player, source_player)
    if player.name == source_player.name then
       -- return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    source_player.zoom_to_world(player.position)
end

local function trust(player, source_player, button)
    Session.trust(source_player, player)
    button.name = "untrust"
    button.caption = "Untrust"
end

local function untrust(player, source_player, button)
    Session.untrust(source_player, player)
    button.name = "trust"
    button.caption = "Trust"
end

local function disable_sci(player, source_player, button)
    if player.name == source_player.name then
        --return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if global.custom_permissions.disable_sci[player.name] then return end
    global.custom_permissions.disable_sci[player.name] = true
    game.print(source_player.name .. " took away the privilege of sending sci form ".. player.name)
    button.name = "enable_sci"
    button.caption = "Enable sci buttons"
end

local function enable_sci(player, source_player)
    if player.name == source_player.name then
        --return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if not global.custom_permissions.disable_sci[player.name] then return end
    global.custom_permissions.disable_sci[player.name] = nil
    game.print(player.name .. " is able to send sci again")
    button.name = "disable_sci"
    button.caption = "Disable sci buttons"
end

local function move_to_spec(player, source_player)
    if player.name == source_player.name then
        return player.print("You can't select yourself!", {r = 1, g = 0.5, b = 0.1})
    end
    if player.force.name == "spectator" then
        return player.print(player.name .. " is already spectating!")
    end
    spectate(player, true)
    game.print(player.name .. " was sent to spectator island by" .. source_player.name)
end

local function turn_off_global_speakers(player)
    local counter = 0
    for _, surface in pairs(game.surfaces) do
        local speakers = surface.find_entities_filtered({name = 'programmable-speaker'})
        for i, speaker in pairs(speakers) do
            if speaker.parameters.playback_globally == true then
                speaker.surface.create_entity({name = 'massive-explosion', position = speaker.position})
                speaker.die('player')
                counter = counter + 1
            end
        end
    end
    if counter == 0 then
        return
    end
    if counter == 1 then
        game.print(player.name .. ' has nuked ' .. counter .. ' global speaker.', {r = 0.98, g = 0.66, b = 0.22})
    else
        game.print(player.name .. ' has nuked ' .. counter .. ' global speakers.', {r = 0.98, g = 0.66, b = 0.22})
    end
end

local function delete_all_blueprints(player)
    local counter = 0
    for _, surface in pairs(game.surfaces) do
        for _, ghost in pairs(surface.find_entities_filtered({type = {'entity-ghost', 'tile-ghost'}})) do
            ghost.destroy()
            counter = counter + 1
        end
    end
    if counter == 0 then
        return
    end
    if counter == 1 then
        game.print(counter .. ' blueprint has been cleared!', {r = 0.98, g = 0.66, b = 0.22})
    else
        game.print(counter .. ' blueprints have been cleared!', {r = 0.98, g = 0.66, b = 0.22})
    end
    admin_only_message(player.name .. ' has cleared all blueprints.')
end

local function create_mini_camera_gui(player, caption, position, surface)
    if player.gui.center['mini_camera'] then
        player.gui.center['mini_camera'].destroy()
    end
    local frame = player.gui.center.add({type = 'frame', name = 'mini_camera', caption = caption})
    surface = tonumber(surface)
    local camera =
        frame.add(
        {
            type = 'camera',
            name = 'mini_cam_element',
            position = position,
            zoom = 0.6,
            surface_index = game.surfaces[surface].index
        }
    )
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

local comparators = {
    ['afk_time_asc'] = function(a, b)
        return a.afk_time < b.afk_time
    end,
    ['afk_time_desc'] = function(a, b)
        return a.afk_time > b.afk_time
    end,
    ['space_sci_asc'] = function(a, b)
        return a.space_sci < b.space_sci
    end,
    ['space_sci_desc'] = function(a, b)
        return a.space_sci > b.space_sci
    end,
    ['trusted_asc'] = function(a, b)
        return a.trusted > b.trusted
    end,
    ['trusted_desc'] = function(a, b)
        return a.trusted < b.trusted
    end,
    ['name_asc'] = function(a, b)
        return a.name:lower() < b.name:lower()
    end,
    ['name_desc'] = function(a, b)
        return a.name:lower() > b.name:lower()
    end,
    ['force_asc'] = function(a, b)
        return a.force:lower() < b.force:lower()
    end,
    ['force_desc'] = function(a, b)
        return a.force:lower() > b.force:lower()
    end
}

local function get_comparator(sort_by)
    return comparators[sort_by]
end

local function get_sorted_playerlist(sort_by)
    local playerlist = {}
    local trustlist = Session.get_trusted_table()
    for i, player in pairs(game.connected_players) do
        playerlist[i] = {}
        playerlist[i].name = player.name
        playerlist[i].afk_time = player.afk_time    --in ticks
        if trustlist[player.name] then playerlist[i].trusted = "Trusted"
        else playerlist[i].trusted = "Untrusted" end
        local eq = player.get_inventory(defines.inventory.character_main)
        if eq ~= nil then
            playerlist[i].space_sci = eq.get_item_count("space-science-pack")
        else
            playerlist[i].space_sci = 0
        end
        playerlist[i].force = player.force.name
        if player.force.name == "spectator" and global.chosen_team[player.name] ~= nil then
            playerlist[i].force = playerlist[i].force .. "(" .. global.chosen_team[player.name] .. ")"
        end
    end
    local comparator = get_comparator(sort_by)
    table.sort(playerlist, comparator)

    return playerlist
end

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
        return false
    end
    if not y_pos then
        return false
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

    local a = 1
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
    x = tonumber(x)
    y = tonumber(y)
    local position = {x = x, y = y}
    return position
end

local function draw_playerlist(data)
    local frame = data.frame
    local player = data.player
    local player_search = this.player_search_text[player.name]
    local sort_by = this.sorting_method[player.name]
    local playerlist = get_sorted_playerlist(sort_by)
    if frame.players_panel then
        frame.players_panel.clear()
    end
    if frame.players_headers then
        frame.players_headers.clear()
    end
    if player_search then
        for i, player in pairs(playerlist) do
            if not contains_text(player.name, nil, player_search) then
                table.remove(playerlist, i)
            end
        end
    end
    local column_widths = {200, 100, 100, 100, 100, 100}
    local headers = {
        [1] = "Player name",
        [2] = "Force",
        [3] = "Trusted",
        [4] = "Afk time",
        [5] = "Hoarding [img=item/space-science-pack]",
        [6] = "Actions"
    }
    local symbol_asc = '▲'
    local symbol_desc = '▼'
    local header_modifier = {
        ['name_asc'] = function(h)
            h[1] = symbol_asc .. h[1]
        end,
        ['name_desc'] = function(h)
            h[1] = symbol_desc .. h[1]
        end,
        ['force_asc'] = function(h)
            h[2] = symbol_asc .. h[2]
        end,
        ['force_desc'] = function(h)
            h[2] = symbol_desc .. h[2]
        end,
        ['trust_asc'] = function(h)
            h[3] = symbol_asc .. h[3]
        end,
        ['trust_desc'] = function(h)
            h[3] = symbol_desc .. h[3]
        end,
        ['afk_time_asc'] = function(h)
            h[4] = symbol_asc .. h[4]
        end,
        ['afk_time_desc'] = function(h)
            h[4] = symbol_desc .. h[4]
        end,
        ['hoarding_asc'] = function(h)
            h[5] = symbol_asc .. h[5]
        end,
        ['hoarding_desc'] = function(h)
            h[5] = symbol_desc .. h[5]
        end,
        
    }

    header_modifier[sort_by](headers)
    for k,v in pairs(headers) do
        local h = frame.players_headers.add{type="label", caption = v, name = v}
        h.style.width = column_widths[k]
        h.style.font = 'default-bold'
        h.style.font_color = {r = 0.98, g = 0.66, b = 0.22}
    end
    local panel = frame.players_panel
    for i, p in pairs(playerlist) do
        local flow = panel.add{type = "flow", name = p.name, direction = "vertical"}
        local t = flow.add{type="table", column_count = 6}
        local name_label = t.add{type = "label", caption = p.name  }
        name_label.style.width = column_widths[1]
        player_color = game.get_player(p.name).color
        name_label.style.font_color = {
            r = .4 + player_color.r * 0.6,
            g = .4 + player_color.g * 0.6,
            b = .4 + player_color.b * 0.6
        }
        t.add{type = "label", caption = p.force}.style.width = column_widths[2]
        t.add{type = "label", caption = p.trusted}.style.width = column_widths[3]

        local afk_time_label = t.add{type = "label", caption = math.floor(p.afk_time/3600)}
        afk_time_label.style.width = column_widths[4]
        if p.afk_time > 54000 and game.get_player(p.name).force.name == ("north" or "south") then
            afk_time_label.style.color = {r=0.99, g = 0.11, b = 0.11}
        end

        t.add{type = "label", caption = p.space_sci}.style.width=column_widths[5]

        t.add{type = "button", name = "actions",  caption = "Actions"}.style.width = column_widths[6]

    end
end

local function text_changed(event)
    local element = event.element
    if not element then
        return
    end
    if not element.valid then
        return
    end

    local antigrief = AntiGrief.get()
    local player = game.players[event.player_index]

    local frame = Tabs.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end
    if frame.name ~= 'Admin' then
        return
    end
        
    local data = {
        player = player,
        frame = frame,
        antigrief = antigrief,
        search_text = element.text
    }

    if element.name == "player_search_text" then
        this.player_search_text[player.name] = element.text
    end
    draw_playerlist(data)
end

local create_admin_panel = (function(player, frame)
    local antigrief = AntiGrief.get()
    this.player_search_text[player.name] = nil
    frame.clear()
    local search_table = frame.add({type = 'table', column_count = 2, name = "player_search"})
    search_table.add({type = 'label', caption = 'Search players: '})
    local search_text = search_table.add({type = 'textfield', name = "player_search_text"})
    search_text.style.width = 140

    local player_list_headers = frame.add{type = "table", name = "players_headers", column_count = 6}
    local player_list_panel = frame.add {type = 'scroll-pane', name = 'players_panel', direction = 'vertical', horizontal_scroll_policy = 'never', vertical_scroll_policy = 'auto' }
    player_list_panel.style.height = 330
    local data = {player = player, sort_by = "name_desc", frame = frame, player_search = nil }
    this.sorting_method[player.name] = "name_desc"
    this.player_search_text[player.name] = nil
    draw_playerlist(data)
   
    --global actions buttons
    frame.add{type = "line", direction = "horizontal"}
    frame.add{type = "label", caption = "Global actions"}
    local f = frame.add{type = "flow", direction = "horizontal"}
    f.add({type = 'button', caption = 'Destroy global speakers', name = 'turn_off_global_speakers', tooltip = 'Destroys all speakers that are set to play sounds globally.'})
    f.add({type = 'button', caption = 'Delete blueprints', name = 'delete_all_blueprints', tooltip = 'Deletes all placed blueprints on the map.'})
end)

local sorting_methods = {
    ["Player name"] = "name_desc",
    ["▲Player name"] = "name_desc",
    ["▼Player name"] = "name_asc",
    ["Force"] = "force_desc",
    ["▲Force"] = "force_desc",
    ["▼Force"] = "force_asc",
    ["Trusted"] = "trust_desc",
    ["▲Trusted"] = "trust_desc",
    ["▼Trusted"] = "trust_asc",
    ["Afk time"] = "afk_time_desc",
    ["▲Afk time"] = "afk_time_desc",
    ["▼Afk time"] = "afk_time_asc",
    ["Hoarding [img=item/space-science-pack]"] = "hoarding_desc",
    ["▲Hoarding [img=item/space-science-pack]"] = "hoarding_desc",
    ["▼Hoarding [img=item/space-science-pack]"] = "hoarding_asc",
}

local admin_functions = {
    ['jail'] = jail,
    ['free'] = free,
    ['bring_player'] = bring_player,
    ['spank'] = spank,
    ['damage'] = damage,
    ['kill'] = kill,
    --['enemy'] = enemy,
    --['ally'] = ally,
    ['go_to_player'] = go_to_player,
    ["show_on_map"] = show_on_map,
    ["freeze"] = freeze,
    ["unfreeze"] = unfreeze,
    ["trust"] = trust,
    ["untrust"] = untrust,
    ["disable_sci"] = disable_sci,
    ["enable_sci"] = enable_sci,
    ["move_to_spec"] = move_to_spec,
    ["open_inventory"] = open_inventory
}

local admin_global_functions = {
    ['turn_off_global_speakers'] = turn_off_global_speakers,
    ['delete_all_blueprints'] = delete_all_blueprints
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

local function on_gui_click(event)
    local player = game.players[event.player_index]
    local frame = Tabs.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end

    if not event.element.valid then
        return
    end

    local name = event.element.name
    if name == 'mini_camera' or name == 'mini_cam_element' then
        player.gui.center['mini_camera'].destroy()
        return
    end

    if frame.name ~= 'Admin' then
        return
    end

    if name == "actions" then
        local target_player = game.get_player(event.element.parent.parent.name)
        for k, v in pairs(frame.players_panel.children) do
            if v.children[2] then
                if v.children[2].name == target_player.name .. "_actions" then
                    v.children[2].destroy()
                    return
                end
                v.children[2].destroy()            
            end
        end

        local t = event.element.parent.parent.add{type = "table", name = target_player.name .. "_actions", column_count = 6}
        if Jailed.exists(target_player.name) then                
            t.add({type = 'button', caption = 'Free', name = 'free', tooltip = 'Frees the player from jail.'})
        else
            t.add({type = 'button',caption = 'Jail',name = 'jail',tooltip = 'Jails the player, they will no longer be able to perform any actions except writing in chat.'})
        end
        if Session.is_trusted(target_player.name) then 
            t.add({type = "button", caption = "Untrust", name = "untrust", tooptip = "Removes trust privleges from the player"})
        else
            t.add({type = "button", caption = "Trust", name = "trust", tooptip = "Grants trust privleges to the player"})
        end
        t.add({type = 'button',caption = 'Bring',name = 'bring_player',tooltip = 'Teleports the selected player to your position.'})
        t.add({type = 'button',caption = 'Go to',name = 'go_to_player',tooltip = 'Teleport yourself to the selected player.'})
        t.add({type = "button", caption = "Send to spec", name = "move_to_spec", tooltip = "Send player to spectator. Doesn't kill, the player can join only his team later."})
        
        if target_player.permission_group.name == "frozen" then
            t.add({type = "button", caption = "Unfreeze", name = "unfreeze", tooltip = "Unfreezes the player."})
        else
            t.add({type = "button", caption = "Freeze", name = "freeze", tooltip = "Freezes the player. Allows for using the chat"})
        end
        t.add({type = 'button',caption = 'Spank',name = 'spank',tooltip = 'Hurts the selected player with minor damage. Can not kill the player.'})
        t.add({type = 'button',caption = 'Damage',name = 'damage',tooltip = 'Damages the selected player with greater damage. Can not kill the player.'})
        t.add({type = 'button', caption = 'Kill', name = 'kill', tooltip = 'Kills the selected player instantly.'})
        t.add({type = "button", caption = "Show", name = "show_on_map", tooltip = "Shows the player on the map."})
        t.add({type = "button", caption = "Inventory", name = "open_inventory", tooltip = "Opens player's inventory"})
        if global.custom_permissions.disable_sci[target_player.name] then
            t.add({type = "button", caption = "Enable sci buttons", name = "enable_sci", tooltip = "Enables players sci sending buttons"})
        else
            t.add({type = "button", caption = "Disable sci buttons", name = "disable_sci", tooltip = "Disables players sci sending buttons"})
        end
        for _, button in pairs(t.children) do
            button.style.font = 'default-bold'
            --button.style.font_color = { r=0.99, g=0.11, b=0.11}
            --button.style.font_color = {r = 0.99, g = 0.99, b = 0.99}
            button.style.minimal_width = 100
        end
        return
    end
    if admin_functions[name] then
        local target_player_name = event.element.parent.parent.name
        if not target_player_name then
            return
        end
        local target_player = game.players[target_player_name]
        if target_player.connected == true then
            admin_functions[name](target_player, player, event.element)
        end
        return
    end

    if admin_global_functions[name] then
        admin_global_functions[name](player)
        return
    end
    if name == "filter_by_gps" then
        event.element.caption = "Waiting for ping..."
        this.waiting_for_gps[player.name] = true
        return
    end
    local caption = event.element.caption
    if sorting_methods[caption] then
        this.sorting_method[player.name] = sorting_methods[caption]
        draw_playerlist({frame = frame, player = player})
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

    if player.gui.center['mini_camera'] then
        if player.gui.center['mini_camera'].caption == event.element.caption then
            player.gui.center['mini_camera'].destroy()
            return
        end
    end

    create_mini_camera_gui(player, event.element.caption, position, surface)
end

local function on_gui_selection_state_changed(event)
    local player = game.players[event.player_index]
    local name = event.element.name

    if name == 'admin_history_select' then
        if not global.admin_panel_selected_history_index then
            global.admin_panel_selected_history_index = {}
        end
        global.admin_panel_selected_history_index[player.name] = event.element.selected_index

        local frame = Tabs.comfy_panel_get_active_frame(player)
        if not frame then
            return
        end
        if frame.name ~= 'Admin' then
            return
        end

        create_admin_panel(player, frame)
    end
    if name == 'admin_player_select' then
        if not global.admin_panel_selected_player_index then
            global.admin_panel_selected_player_index = {}
        end
        global.admin_panel_selected_player_index[player.name] = event.element.selected_index

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

comfy_panel_tabs['Admin'] = {gui = create_admin_panel, admin = true}

commands.add_command("kill", "Kill a player. Usage: /kill <name>", function(cmd)
	local killer = game.get_player(cmd.player_index)
	if cmd.parameter then
		local victim = game.get_player(cmd.parameter)
		if killer.admin and victim and victim.valid then
			kill(victim, killer)
		elseif not victim or not victim.valid then
			killer.print("Invalid name", Color.warning)
		else
			killer.print("Only admins have licence for killing!", Color.warning)
		end
	else
		killer.print("Usage: /kill <name>", Color.warning)
	end
end)

commands.add_command("punish", "Kill and ban a player. Usage: /punish <name> <reason>", function(cmd)
	local punisher = game.get_player(cmd.player_index)
	local t = {}
	local message
	if punisher.admin and cmd.parameter then
		for i in string.gmatch(cmd.parameter, '%S+') do t[#t + 1] = i end
		local offender = game.get_player(t[1])
		table.remove(t, 1)
		message = table.concat(t, ' ')
		if offender.valid and string.len(message) > 5 then
			Server.to_discord_embed(offender.name .. " was banned by " .. punisher.name .. ". " .. "Reason: " .. message)
			message = message .. " Appeal on discord. Link on biterbattles.org", Color.warning
			if offender.force.name == "spectator" then join_team(offender, global.chosen_team[offender.name], true) end -- switches offender to their team if he's spectating
			kill(offender, punisher)
			game.ban_player(offender, message)
		elseif not offender.valid then
			punisher.print("Invalid name", Color.warning)
		else
			punisher.print("No valid reason given, or reason is too short", Color.warning)
		end
	elseif not punisher.admin then
		punisher.print("This is admin only command", Color.warning)
	else
		punisher.print("Usage: /punish <name> <reason>", Color.warning)
	end
end)
        
Event.add(defines.events.on_gui_text_changed, text_changed)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_selection_state_changed, on_gui_selection_state_changed)
