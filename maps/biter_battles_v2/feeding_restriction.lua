local _TEST = storage['_TEST'] or false
local Score
if not _TEST then
    Score = require('comfy_panel.score')
end

local Tables = require('maps.biter_battles_v2.tables')

local Public = {}

--- Pure formula: calculate required build score from difficulty value.
--- Formula: 48 / difficulty_value (gives 240 at ITYTD, scales down with higher difficulty)
---@param difficulty_value number
---@return integer
function Public.calc_required_score(difficulty_value)
    return math.ceil(48 / difficulty_value)
end

--- Calculate required build score based on current difficulty.
---@return integer
function Public.get_required_build_score()
    if not storage.bb_settings or not storage.bb_settings.science_send_score_restriction then
        return 0
    end
    local difficulty = storage.difficulty_vote_value or Tables.difficulties[4].value -- default to Easy
    return Public.calc_required_score(difficulty)
end

--- Check if player can send science based on build score restriction.
---@param player LuaPlayer
---@return boolean
function Public.can_player_send_science(player)
    if not storage.bb_settings or not storage.bb_settings.science_send_score_restriction then
        return true
    end
    local score_table = Score.get_table().score_table
    local force_name = player.force.name
    local player_name = player.name

    local tbl = score_table[force_name]
    local score = (tbl and tbl.players and tbl.players[player_name]) or nil
    if not score then
        return false
    end

    local built = score.built_entities or 0
    local required = Public.get_required_build_score()
    return built >= required
end

return Public
