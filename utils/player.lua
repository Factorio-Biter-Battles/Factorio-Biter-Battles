local Public = {}

local function cpt_get_player(playerName)
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

---@param player_list LuaPlayer[]
---@return string[]
function Public.get_sorted_colored_player_list(player_list)
	local players_with_sort_keys = {}
	for _, p in pairs(player_list) do
		table.insert(players_with_sort_keys, { player = p, sort_key = string.lower(p.name) })
	end
	table.sort(players_with_sort_keys, function(a, b) return a.sort_key < b.sort_key end)

	local players_with_colors = {}
	for _, pair in ipairs(players_with_sort_keys) do
		local p = pair.player
		local color = p.color or { r = 1, g = 1, b = 1, a = 1}
		table.insert(players_with_colors, string.format("[color=%.2f,%.2f,%.2f]%s[/color]", color.r * 0.6 + 0.4, color.g * 0.6 + 0.4, color.b * 0.6 + 0.4, p.name))
	end

	return players_with_colors
end

---@param names string[]
---@return LuaPlayer[]
function Public.get_lua_players_from_player_names(names)
	local players = {}
	for _, name in pairs(names) do
		table.insert(players, cpt_get_player(name))
	end
	return players
end

return Public