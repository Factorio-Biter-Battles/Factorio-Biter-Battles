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
        res.print = function(msg, options)
            game.print({ '', { 'info.dummy_print', playerName }, msg }, options)
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

-- Minimum samples before SMA is considered reliable.
CaptainUtils.SMA_MIN_SAMPLES = 4
-- Maximum samples to keep in memory. Upper bound increases SMA stability.
CaptainUtils.SMA_MAX_SAMPLES = 8

---Update SMA tracking for pick duration estimation.
---@param force string The force name.
function CaptainUtils.update_pick_sma(force)
    local special = storage.special_games_variables.captain_mode
    local time_taken = game.tick
        - special.captain_pick_timer_sma_last_tick[force]
        - special.captain_pick_timer_pause_duration
    local count = special.captain_pick_timer_sma_count[force] + 1
    special.captain_pick_timer_pause_duration = 0

    special.captain_pick_timer_sma_count[force] = count
    local id = ((count - 1) % CaptainUtils.SMA_MAX_SAMPLES) + 1
    special.captain_pick_timer_sma_samples[force][id] = time_taken
    if count < CaptainUtils.SMA_MIN_SAMPLES then
        return
    end

    local sum = 0
    for _, sample in ipairs(special.captain_pick_timer_sma_samples[force]) do
        sum = sum + sample
    end
    special.captain_pick_timer_sma_sum[force] = sum / math.min(count, CaptainUtils.SMA_MAX_SAMPLES)
end

return CaptainUtils
