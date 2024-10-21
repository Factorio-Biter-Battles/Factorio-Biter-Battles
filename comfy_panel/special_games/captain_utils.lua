local player_utils = require('utils.player')

local CaptainUtils = {}

---@param tab table
---@param str any
---@return boolean
function CaptainUtils.table_contains(tab, str)
    for _, entry in ipairs(tab) do
        if entry == str then
            return true
        end
    end
    return false
end

---@param playerName string|integer
---@return LuaPlayer?
function CaptainUtils.cpt_get_player(playerName)
    if not playerName then
        return nil
    end
    local special = storage.special_games_variables.captain_mode
    if special and special.test_players and special.test_players[playerName] then
        local res = table.deepcopy(special.test_players[playerName])
        res.print = function(msg, color)
            game.print({ '', { 'info.dummy_print', playerName }, msg }, color)
        end
        res.force = { name = (storage.chosen_team[playerName] or 'spectator') }
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
