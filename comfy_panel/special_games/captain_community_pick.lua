local Color = require('utils.color_presets')

local CaptainCommunityPick = {}

local table_insert = table.insert
local math_random = math.random

---@param player string
---@param community_picks table<string, string[]>
---@return nil
local function remove_player_from_picks(player, community_picks)
    for _, player_list in pairs(community_picks) do
        for i, pick in ipairs(player_list) do
            if pick == player then
                table.remove(player_list, i)
                break
            end
        end
    end
end

-- This finds the top pick by running a ranked choice vote using "instant runoff" policies.
-- I wanted an algorithm that ignores the impact of outliers (like if a small number of
-- players ranked one player very highly or very low, it shouldn't matter exactly how high
-- or how low those players ranked one player).
-- This algorithm is somewhat similar to looking at each player's median rank, and sorting
-- based on that.
---@param community_picks table<string, string[]>
---@param num_votes_required_for_win integer
---@return string?
local function find_top_pick(community_picks, num_votes_required_for_win)
    -- do not modify the argument
    local orig_community_picks = community_picks
    community_picks = table.deepcopy(community_picks)
    -- run a ranked choice vote until we have a winner
    while true do
        local votes = {}
        for _, player_list in pairs(community_picks) do
            if #player_list == 0 then
                game.print('Error: empty player list in community_picks', { color = Color.red })
                game.print(serpent.line(orig_community_picks))
                return nil
            end
            votes[player_list[1]] = (votes[player_list[1]] or 0) + 1
        end
        local max_votes = 0
        local max_player = nil
        local min_votes = num_votes_required_for_win
        local min_player = nil
        for player, vote_count in pairs(votes) do
            if vote_count > max_votes then
                max_votes = vote_count
                max_player = player
            end
            if vote_count < min_votes then
                min_votes = vote_count
                min_player = player
            end
        end
        if max_votes >= num_votes_required_for_win then
            return max_player
        end
        -- remove min_player from all lists
        remove_player_from_picks(min_player --[[@as string]], community_picks)
    end
end

---@param list string[]
---@param item string
local function move_to_front_of_list(list, item)
    for i, list_item in ipairs(list) do
        if list_item == item then
            table.remove(list, i)
            table.insert(list, 1, item)
            return
        end
    end
end

---@param community_picks table<string, string[]>
---@return string[]?
function CaptainCommunityPick.pick_order(community_picks)
    -- do not modify the argument
    community_picks = table.deepcopy(community_picks)

    if table.size(community_picks) == 0 then
        return nil
    end
    -- verify that every entry in community_picks has the same entries (just potentially different orders)
    local num_players = nil
    local players = {}
    for picking_player, player_list in pairs(community_picks) do
        -- ignore the position that the player put themselves in (always put themselves first)
        move_to_front_of_list(player_list, picking_player)
        if num_players == nil then
            num_players = #player_list
            for _, player in ipairs(player_list) do
                if players[player] then
                    game.print(
                        string.format('Error: "%s" is repeated in community_picks for "%s"', player, picking_player),
                        { color = Color.red }
                    )
                    return nil
                end
                players[player] = true
            end
        else
            if #player_list ~= num_players then
                game.print(
                    string.format('Error: "%s" has wrong number of community_picks', picking_player),
                    { color = Color.red }
                )
                return nil
            end
            local this_unique_players = {}
            for _, player in ipairs(player_list) do
                if not players[player] or this_unique_players[player] then
                    game.print(
                        string.format('Error: "%s" is surprising to find in picks for "%s"', player, _),
                        { color = Color.red }
                    )
                    return nil
                end
                this_unique_players[player] = true
            end
        end
    end

    local result = {}
    local num_votes_required_for_win = math.ceil(table_size(community_picks) / 2)
    while num_players > 0 do
        local top_pick = find_top_pick(community_picks, num_votes_required_for_win)
        if not top_pick then
            return nil
        end

        table_insert(result, top_pick)
        remove_player_from_picks(top_pick, community_picks)
        num_players = num_players - 1
    end
    return result
end

---@param pick_order string[]
---@return string[][]
function CaptainCommunityPick.assign_teams(pick_order)
    local result = { {}, {} }
    local next_team_to_pick = math_random(#result)
    for _, pick in ipairs(pick_order) do
        -- game.print(string.format('picked %s for %s', pick, next_team_to_pick == 1 and 'North' or 'South'))
        table_insert(result[next_team_to_pick], pick)
        local other_possible_next_team_to_pick = 3 - next_team_to_pick
        -- do 1, 2, 2, 2, ... picking
        if #result[next_team_to_pick] > #result[other_possible_next_team_to_pick] then
            next_team_to_pick = other_possible_next_team_to_pick
        end
    end
    return result
end

return CaptainCommunityPick
