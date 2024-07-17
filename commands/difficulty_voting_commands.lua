local Server = require 'utils.server'
local Color = require 'utils.color_presets'
local tables = require 'maps.biter_battles_v2.tables'
local difficulty_vote = require 'maps.biter_battles_v2.difficulty_vote'

local function revote()
    local player = game.player

    if player and player ~= nil then
        if not player.admin then
            player.print("[ERROR] Command is admin-only. Please ask an admin.", Color.warning)
            return

        else
            local tick = game.ticks_played
            global.difficulty_votes_timeout = tick + 10800
            global.difficulty_player_votes = {}
            local msg = player.name .. " opened difficulty voting. Voting enabled for 3 mins"
            game.print(msg)
            Server.to_discord_embed(msg)
        end
    end
end

local function close_difficulty_votes(cmd)
    local player = game.player
    if not player then return end
    if not player.admin then
        player.print("[ERROR] Command is admin-only. Please ask an admin.", Color.warning)
        return
    end
    if cmd.parameter and cmd.parameter ~= "" then
        local param = string.lower(cmd.parameter)
        local idx = tables.difficulty_lowered_names_to_index[param]
        if idx then
            global.difficulty_vote_index = idx
            global.difficulty_vote_value = tables.difficulties[idx].value
        elseif string.match(param, "^%d+%.?%d*%%$") then
            global.difficulty_vote_index = nil
            global.difficulty_vote_value = tonumber(param:sub(1, -2)) / 100.0
        else
            player.print("Invalid difficulty parameter. Please provide either a difficulty name/abbreviation or mutagen effectiveness as a percentage, i.e. `33%'.")
            return
        end
        local message = table.concat({">> Map difficulty has changed to ", difficulty_vote.difficulty_name(), " difficulty!"})
        game.print(message, difficulty_vote.difficulty_print_color())
        Server.to_discord_embed(message)
    end
    global.difficulty_votes_timeout = game.ticks_played
    local msg = player.name .. " closed difficulty voting"
    game.print(msg)
    Server.to_discord_embed(msg)
end

commands.add_command('difficulty-revote', 'open difficulty revote',
                     function(cmd) revote(); end)

commands.add_command('difficulty-close-vote', 'closes difficulty revote. Takes optional argument of new difficulty, either by name/abbreviation or mutagen effectiveness.',
                     function(cmd) close_difficulty_votes(cmd); end)
