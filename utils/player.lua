local malloc = require('maps.biter_battles_v2.pool').malloc

local Public = {}

local function get_or_create_dummy_player(playerName)
    local special = storage.special_games_variables.captain_mode
    return game.get_player(playerName)
        or {
            name = playerName,
            color = { r = 255, g = 255, b = 255, a = 1 },
            force = { name = (storage.chosen_team[playerName] or 'spectator') },
            print = function(msg, color)
                game.print('to player ' .. playerName .. ':' .. msg, { color = color })
            end,
            tag = special and special.test_players[playerName],
        }
end

---@param player_list LuaPlayer[]
---@return string[]
function Public.get_colored_player_list(player_list)
    local players_with_colors = malloc(#player_list)
    local i = 1
    for _, player in pairs(player_list) do
        players_with_colors[i] = string.format(
            '[color=%.2f,%.2f,%.2f]%s[/color]',
            player.color.r * 0.6 + 0.4,
            player.color.g * 0.6 + 0.4,
            player.color.b * 0.6 + 0.4,
            player.name
        )
        i = i + 1
    end

    return players_with_colors
end

---@param player_list LuaPlayer[]
---@return string[]
function Public.get_sorted_colored_player_list(player_list)
    local players_with_sort_keys = malloc(#player_list)
    local i = 1
    for _, player in pairs(player_list) do
        players_with_sort_keys[i] = { player, string.lower(player.name) }
        i = i + 1
    end
    table.sort(players_with_sort_keys, function(a, b)
        return a[2] < b[2]
    end)

    for i = 1, #player_list do
        players_with_sort_keys[i][2] = nil
    end

    return Public.get_colored_player_list(players_with_sort_keys)
end

---@param names string[]
---@return LuaPlayer[]
function Public.get_lua_players_from_player_names(names)
    local players = malloc(#names)
    for i = 1, #names do
        players[i] = get_or_create_dummy_player(names[i])
    end
    return players
end

return Public
