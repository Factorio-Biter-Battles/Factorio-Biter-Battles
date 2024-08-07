local player_utils = require('utils.player')

local CaptainUtils = {}

function CaptainUtils.table_contains(tab, str)
    for _, entry in ipairs(tab) do
        if entry == str then
            return true
        end
    end
    return false
end

function CaptainUtils.cpt_get_player(playerName)
    local special = global.special_games_variables.captain_mode
    if special and special.test_players and special.test_players[playerName] then
        local res = table.deepcopy(special.test_players[playerName])
        res.print = function(msg, color)
            game.print('to player ' .. playerName .. ':' .. msg, color)
        end
        res.force = { name = (global.chosen_team[playerName] or 'spectator') }
        return res
    end
    return game.get_player(playerName)
end

---@param names string[]
---@return string
function CaptainUtils.pretty_print_player_list(names)
    return table.concat(
        player_utils.get_colored_player_list(player_utils.get_lua_players_from_player_names(names)),
        ', '
    )
end

return CaptainUtils
