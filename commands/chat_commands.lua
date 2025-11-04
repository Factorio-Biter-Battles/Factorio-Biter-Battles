local Server = require('utils.server')
local Muted = require('utils.muted')
local String = require('utils.string')
local Functions = require('maps.biter_battles_v2.functions')

local function chat_with_team(message, team)
    local player = game.player
    if player and player.valid then
        local player_name = player.name

        local tag = player.tag
        if not tag then
            tag = ''
        end
        local color = player.chat_color

        -- Drop messages with gps tag not meant for spectators.
        local sane_msg = String.sanitize_gps_tags(message)
        if String.has_sanitized_gps_tag(sane_msg) and team ~= 'spectator' then
            player.print('A message with GPS tag is not allowed')
            return
        end

        local preamble = '[To ' .. team .. '] ' .. player_name .. tag .. ' (' .. player.force.name .. '): '
        local msg = preamble .. message
        if not Muted.is_muted(player_name) then
            Functions.print_message_to_players(
                game.forces.spectator.connected_players,
                player_name,
                msg,
                color,
                do_ping
            )
            if team == 'north' or player.force.name == 'north' then
                Functions.print_message_to_players(
                    game.forces.north.connected_players,
                    player_name,
                    msg,
                    color,
                    do_ping
                )
            end
            if team == 'south' or player.force.name == 'south' then
                Functions.print_message_to_players(
                    game.forces.south.connected_players,
                    player_name,
                    msg,
                    color,
                    do_ping
                )
            end
        else
            Muted.print_muted_message(player)
        end

        -- Do not pass messages to discord with just a GPS ping to avoid spam.
        if String.only_sanitized_gps_tag(sane_msg) then
            return
        end

        msg = preamble .. sane_msg
        if Muted.is_muted(player_name) then
            msg = '[muted] ' .. msg
        end

        Server.to_discord_player_chat(msg)
    end
end

commands.add_command('sth', 'Chat with south. Same as /south-chat', function(cmd)
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'south')
end)

commands.add_command('south-chat', 'Chat with south. You can also use /sth', function(cmd)
    game.player.print('System: You can also you /sth')
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'south')
end)

commands.add_command('nth', 'Chat with north. Same as /north-chat', function(cmd)
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'north')
end)

commands.add_command('north-chat', 'Chat with north. You can also use /nth', function(cmd)
    game.player.print('System: You can also you /nth')
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'north')
end)

commands.add_command('spectator-chat', 'Chat with spectators.', function(cmd)
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'spectator')
end)
