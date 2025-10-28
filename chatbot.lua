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

commands.add_command('trust', 'Promotes a player to trusted!', function(cmd)
    local trusted = session.get_trusted_table()
    local player = game.player

    if player and player.valid then
        if not is_admin(player) then
            player.print("You're not admin!", { color = { r = 1, g = 0.5, b = 0.1 } })
            return
        end

        if cmd.parameter == nil then
            return
        end
        local target_player = game.get_player(cmd.parameter)
        if target_player then
            if trusted[target_player.name] then
                game.print(target_player.name .. ' is already trusted!')
                return
            end
            trusted[target_player.name] = true
            game.print(target_player.name .. ' is now a trusted player.', { color = { r = 0.22, g = 0.99, b = 0.99 } })
            for _, a in pairs(game.connected_players) do
                if is_admin(a) and a.name ~= player.name then
                    a.print(
                        '[ADMIN]: ' .. player.name .. ' trusted ' .. target_player.name,
                        { color = { r = 1, g = 0.5, b = 0.1 } }
                    )
                end
            end
        end
    else
        if cmd.parameter == nil then
            return
        end
        local target_player = game.get_player(cmd.parameter)
        if target_player then
            if trusted[target_player.name] == true then
                game.print(target_player.name .. ' is already trusted!')
                return
            end
            trusted[target_player.name] = true
            game.print(target_player.name .. ' is now a trusted player.', { color = { r = 0.22, g = 0.99, b = 0.99 } })
        end
    end
end)

commands.add_command('untrust', 'Demotes a player from trusted!', function(cmd)
    local trusted = session.get_trusted_table()
    local player = game.player
    local p

    if player then
        if player ~= nil then
            p = player.print
            if not is_admin(player) then
                p("You're not admin!", { color = { r = 1, g = 0.5, b = 0.1 } })
                return
            end
        else
            p = log
        end

        if cmd.parameter == nil then
            return
        end
        local target_player = game.get_player(cmd.parameter)
        if target_player then
            if trusted[target_player.name] == false then
                game.print(target_player.name .. ' is already untrusted!')
                return
            end
            trusted[target_player.name] = false
            game.print(target_player.name .. ' is now untrusted.', { color = { r = 0.22, g = 0.99, b = 0.99 } })
            for _, a in pairs(game.connected_players) do
                if is_admin(a) and a.name ~= player.name then
                    a.print(
                        '[ADMIN]: ' .. player.name .. ' untrusted ' .. target_player.name,
                        { color = { r = 1, g = 0.5, b = 0.1 } }
                    )
                end
            end
        end
    else
        if cmd.parameter == nil then
            return
        end
        local target_player = game.get_player(cmd.parameter)
        if target_player then
            if trusted[target_player.name] == false then
                game.print(target_player.name .. ' is already untrusted!')
                return
            end
            trusted[target_player.name] = false
            game.print(target_player.name .. ' is now untrusted.', { color = { r = 0.22, g = 0.99, b = 0.99 } })
        end
    end
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
