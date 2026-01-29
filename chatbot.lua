local Event = require('utils.event')
local session = require('utils.datastore.session_data')
local Timestamp = require('utils.timestamp')
local Server = require('utils.server')
local Color = require('utils.color_presets')
local Muted = require('utils.muted')

local font_color = Color.warning
local font = 'default-game'
local format = string.format

local brain = {
    [1] = { 'Our Discord server is at: https://discord.com/invite/hAYW3K7J2A' },
    [2] = {
        'Need an admin? Join our discord at: https://discord.com/invite/hAYW3K7J2A,',
        'and report it in #support',
        'If you are trusted, you are eligible to run the command /jail <player-name> "reason" and /free',
    },
    [3] = { 'Scenario repository for download:', 'https://github.com/Factorio-Biter-Battles/Factorio-Biter-Battles' },
    [4] = {
        "If you're not trusted and have been playing here for awhile, ask an admin to trust you.  Use the /admins command to see if any are available.",
    },
    [5] = {
        'Need a guide to help learn the server?',
        "Check out the pinned messages at our discord's #learning channel",
        'for a link to one of many guides written by members of the community.',
    },
    [6] = {
        'Warning - Foul language will not be tolerated on this server',
        'Repeated offenses will be met with a jail/ban',
    },
}

local links = {
    ['admin'] = brain[2],
    ['administrator'] = brain[2],
    ['discord'] = brain[1],
    ['download'] = brain[3],
    ['github'] = brain[3],
    ['greifer'] = brain[2],
    ['grief'] = brain[2],
    ['griefer'] = brain[2],
    ['griefing'] = brain[2],
    ['jail'] = brain[2],
    ['ban'] = brain[2],
    ['report'] = brain[2],
    ['mod'] = brain[2],
    ['moderator'] = brain[2],
    ['scenario'] = brain[3],
    ['stealing'] = brain[2],
    ['stole'] = brain[2],
    ['troll'] = brain[2],
    ['trust'] = brain[4],
    ['trusted'] = brain[4],
    ['untrusted'] = brain[4],
    ['learn'] = brain[5],
    ['guide'] = brain[5],
    ['meta'] = brain[5],
    ['asshole'] = brain[6],
    ['bitch'] = brain[6],
    ['cunt'] = brain[6],
    ['fuck'] = brain[6],
    ['fucking'] = brain[6],
    ['idiot'] = brain[6],
    ['moron'] = brain[6],
    ['retard'] = brain[6],
    ['stfu'] = brain[6],
}

local function on_player_created(event)
    local player = game.get_player(event.player_index)
    player.print(
        '[font=' .. font .. ']' .. 'Welcome! Join us on discord >> https://discord.com/invite/hAYW3K7J2A' .. '[/font]',
        { color = font_color }
    )
end

---Notify all other connected admins about a trust action.
---@param admin_name string The name of the admin performing the action
---@param action string The action verb (e.g., "trusted" or "untrusted")
---@param target_names string The name(s) of the player(s) being trusted/untrusted
local function notify_admins(admin_name, action, target_names)
    for _, admin in pairs(game.connected_players) do
        if is_admin(admin) and admin.name ~= admin_name then
            admin.print('[ADMIN]: ' .. admin_name .. ' ' .. action .. ' ' .. target_names, { color = Color.comfy })
        end
    end
end

---Parse player names from a command parameter string.
---@param param string? The command parameter string
---@return string[] names Array of player names
local function parse_player_names(param)
    local names = {}
    if param then
        for name in string.gmatch(param, '%S+') do
            names[#names + 1] = name
        end
    end
    return names
end

---Set trust status for a single player.
---@param target_name string The name of the player to trust/untrust
---@param should_trust boolean true for trust, false for untrust
---@return boolean success Whether the operation succeeded
---@return string? error_message Error message if operation failed
---@return string? player_name The actual player name if found
local function set_player_trust(target_name, should_trust)
    local trusted = session.get_trusted_table()
    local target_player = game.get_player(target_name)

    if not target_player then
        return false, 'Player not found: ' .. target_name, nil
    end

    local current_trust = trusted[target_player.name] or false
    if current_trust == should_trust then
        local status = should_trust and 'trusted' or 'untrusted'
        return false, target_player.name .. ' is already ' .. status .. '!', nil
    end

    trusted[target_player.name] = should_trust
    return true, nil, target_player.name
end

local trust_commands = {
    trust = {
        description = 'Promotes player(s) to trusted!',
        should_trust = true,
        verb = 'trusted',
    },
    untrust = {
        description = 'Demotes player(s) from trusted!',
        should_trust = false,
        verb = 'untrusted',
    },
}

local function handle_trust_command(cmd, cmd_name)
    local config = trust_commands[cmd_name]
    local player = game.player

    -- Admin check (only for in-game players, server console always allowed)
    if player and player.valid and not is_admin(player) then
        player.print("You're not admin!", { color = Color.comfy })
        return
    end

    local names = parse_player_names(cmd.parameter)
    if #names == 0 then
        if player then
            player.print('Usage: /' .. cmd_name .. ' <player-name> [player-name2] ...', { color = Color.warning })
        end
        return
    end

    local affected_players = {}
    for _, name in ipairs(names) do
        local success, err_msg, player_name = set_player_trust(name, config.should_trust)
        if success then
            affected_players[#affected_players + 1] = player_name
        elseif player then
            player.print(err_msg, { color = Color.warning })
        end
    end

    if #affected_players > 0 then
        local player_list = table.concat(affected_players, ', ')
        game.print(
            player_list .. (#affected_players == 1 and ' is' or ' are') .. ' now ' .. config.verb .. '.',
            { color = Color.cyan }
        )

        if player then
            notify_admins(player.name, config.verb, player_list)
        end
    end
end

commands.add_command('trust', trust_commands.trust.description, function(cmd)
    handle_trust_command(cmd, 'trust')
end)

commands.add_command('untrust', trust_commands.untrust.description, function(cmd)
    handle_trust_command(cmd, 'untrust')
end)

local function process_bot_answers(event)
    local player = game.get_player(event.player_index)
    local message = event.message
    message = string.lower(message)
    for word in string.gmatch(message, '%g+') do
        if links[word] then
            for _, bot_answer in pairs(links[word]) do
                player.print('[font=' .. font .. ']' .. bot_answer .. '[/font]', { color = font_color })
            end
            return
        end
    end
end

local function on_console_chat(event)
    if not event.player_index then
        return
    end
    process_bot_answers(event)
end

--share vision of silent-commands with other admins
local function on_console_command(event)
    local cmd = event.command
    if not event.player_index then
        return
    end
    local player = game.get_player(event.player_index)
    local param = event.parameters

    local commands = {
        ['editor'] = true,
        ['silent-command'] = true,
        ['sc'] = true,
        ['debug'] = true,
    }

    if (cmd == 'shout' or cmd == 's') and player and param then
        local chatmsg = '[shout] ' .. player.name .. ' (' .. player.force.name .. '): ' .. param
        Server.to_discord_player_chat(chatmsg)
        return
    elseif not is_admin(player) or not commands[cmd] then
        return
    end

    local server_time = Server.get_current_time()
    if server_time then
        server_time = format(' (Server time: %s)', Timestamp.to_string(server_time))
    else
        server_time = ' at tick: ' .. game.tick
    end

    if string.len(param) <= 0 then
        param = nil
    end

    if player then
        for _, p in pairs(game.connected_players) do
            if is_admin(p) and p.name ~= player.name then
                if param then
                    p.print(
                        player.name .. ' ran: ' .. cmd .. ' "' .. param .. '" ' .. server_time,
                        { color = { r = 0.22, g = 0.99, b = 0.99 } }
                    )
                else
                    p.print(player.name .. ' ran: ' .. cmd .. server_time, { color = { r = 0.22, g = 0.99, b = 0.99 } })
                end
            end
        end
        if param then
            print(player.name .. ' ran: ' .. cmd .. ' "' .. param .. '" ' .. server_time)
            return
        else
            print(player.name .. ' ran: ' .. cmd .. server_time)
            return
        end
    else
        if param then
            print('ran: ' .. cmd .. ' "' .. param .. '" ' .. server_time)
            return
        else
            print('ran: ' .. cmd .. server_time)
            return
        end
    end
end

Event.add(defines.events.on_player_created, on_player_created)
Event.add(defines.events.on_console_chat, on_console_chat)
Event.add(defines.events.on_console_command, on_console_command)
