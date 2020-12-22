local Server = require 'utils.server'
local Color = require 'utils.color_presets'

local function revote()
    local player = game.player

    if player and player ~= nil then
        if not player.admin then
            player.print("[ERROR] Command is admin-only. Please ask an admin.", Color.warning)
            return

        else
            local tick = game.ticks_played
            global.difficulty_votes_timeout = tick + 10800
            game.print(player.name .. " opened difficulty voting. Voting enabled for 3 mins" )
        end
    end
end

local function close_difficulty_votes()
    local player = game.player

    if player and player ~= nil then
        if not player.admin then
            player.print("[ERROR] Command is admin-only. Please ask an admin.", Color.warning)
            return
        else
            global.difficulty_votes_timeout = game.ticks_played
            game.print(player.name .. " closed difficulty voting")
        end
    end
end

commands.add_command('difficulty-revote', 'open difficulty revote',
                     function(cmd) revote(); end)

commands.add_command('difficulty-close-vote', 'open difficulty revote',
                     function(cmd) close_difficulty_votes(); end)
