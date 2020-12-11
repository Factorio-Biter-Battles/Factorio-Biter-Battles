local Server = require 'utils.server'

local string_find = string.find

local function chat_with_team(message, team)
    local player = game.player
    local player_name = player.name
    local force = game.forces['player']

    local tag = player.tag
    if not tag then tag = "" end
    local color = player.chat_color

    local a, b = string_find(message, "gps=", 1, false)
    if a then return end

    local msg = "[To " .. team .. "] " .. player_name .. tag .. " (" ..
                    player.force.name .. "): " .. message

    game.forces.spectator.print(msg, color)

    if (team == "north" or player.force.name == "north") then
        game.forces.north.print(msg, color)
    end
    if (team == "south" or player.force.name == "south" ) then
        game.forces.south.print(msg, color)
    end
    Server.to_discord_player_chat(msg)
end

commands.add_command('sth', 'Chat with south. Same as /south-chat', function(cmd)
    local message = tostring(cmd.parameter)
   chat_with_team(message,'south')
end)

commands.add_command('south-chat', 'Chat with south. You can also use /sth', function(cmd)
    game.player.print("System: You can also you /sth")
    local message = tostring(cmd.parameter)
   chat_with_team(message,'south')
end)

commands.add_command('nth', 'Chat with north. Same as /north-chat', function(cmd)
    local message = tostring(cmd.parameter)
   chat_with_team(message,'north')
end)

commands.add_command('north-chat', 'Chat with north. You can also use /nth', function(cmd)
    game.player.print("System: You can also you /nth")
    local message = tostring(cmd.parameter)
   chat_with_team(message,'north')
end)
