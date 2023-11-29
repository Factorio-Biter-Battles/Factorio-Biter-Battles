local Server = require 'utils.server'
local Muted = require 'utils.muted'
local Functions = require "maps.biter_battles_v2.functions"
local string_find = string.find

local function chat_with_team(message, team)
    local player = game.player
    if player and player.valid then
        local player_name = player.name

        local tag = player.tag
        if not tag then tag = "" end
        local color = player.chat_color

        local a, b = string_find(message, "gps=", 1, false)
        if a then return end

        local msg = "[To " .. team .. "] " .. player_name .. tag .. " (" ..
                        player.force.name .. "): " .. message

        if not Muted.is_muted(player_name) then
			Functions.print_message_to_players(game.forces.spectator.players,player_name,msg,color)
            if (team == "north" or player.force.name == "north") then
				Functions.print_message_to_players(game.forces.north.players,player_name,msg,color)
            end
            if (team == "south" or player.force.name == "south") then
				Functions.print_message_to_players(game.forces.south.players,player_name,msg,color)
            end
        else
            msg = "[muted] " .. msg
            Muted.print_muted_message(player)
        end
        Server.to_discord_player_chat(msg)
    end
end

commands.add_command('sth', 'Chat with south. Same as /south-chat',
                     function(cmd)
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'south')
end)

commands.add_command('south-chat', 'Chat with south. You can also use /sth',
                     function(cmd)
    game.player.print("System: You can also you /sth")
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'south')
end)

commands.add_command('nth', 'Chat with north. Same as /north-chat',
                     function(cmd)
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'north')
end)

commands.add_command('north-chat', 'Chat with north. You can also use /nth',
                     function(cmd)
    game.player.print("System: You can also you /nth")
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'north')
end)

commands.add_command('spectator-chat', 'Chat with spectators.',
                     function(cmd)
    local message = tostring(cmd.parameter)
    chat_with_team(message, 'spectator')
end)
