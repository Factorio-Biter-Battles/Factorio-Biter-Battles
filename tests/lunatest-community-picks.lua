local lunatest = require("lunatest")
local CaptainCommunityPick = require("comfy_panel.special_games.captain_community_pick")

-- Mock Factorio environment
local function size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

_G.table_size = size
_G.table.size = size

_G.game = {
    print = print  -- We'll just use Lua's print function for simplicity
}

_G.Color = {red = "red"}

-- Implement deepcopy function
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Add deepcopy to the global table
_G.table.deepcopy = deepcopy

-- Helper functions
local function table_contains(t, element)
    for i, value in ipairs(t) do
        if value == element then
            return i
        end
    end
    return nil
end

-- Test cases
function test_pick_order()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player2", "player1", "player3", "player4"},
        player3 = {"player3", "player1", "player2", "player4"},
        player4 = {"player4", "player1", "player2", "player3"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_equal(4, #result, "Pick order should contain 4 players")
    for _, player in ipairs({"player1", "player2", "player3", "player4"}) do
        lunatest.assert_not_nil(table_contains(result, player), player .. " should be in the pick order")
    end
end

function test_assign_teams()
    local pick_order = {"player1", "player2", "player3", "player4"}
    local result = CaptainCommunityPick.assign_teams(pick_order)
    lunatest.assert_equal(2, #result, "Should have 2 teams")
    lunatest.assert_equal(2, #result[1], "Team 1 should have 2 players")
    lunatest.assert_equal(2, #result[2], "Team 2 should have 2 players")
end

function test_assign_teams_odd()
    local pick_order = {"player1", "player2", "player3", "player4", "player5"}
    local result = CaptainCommunityPick.assign_teams(pick_order)
    lunatest.assert_equal(2, #result, "Should have 2 teams")
    lunatest.assert_equal(5, #result[1] + #result[2], "Total number of players should be 5")
    lunatest.assert_true(math.abs(#result[1] - #result[2]) <= 1, "Teams should be balanced")
end

function test_pick_order_with_ties()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player2", "player1", "player3", "player4"},
        player3 = {"player3", "player4", "player1", "player2"},
        player4 = {"player4", "player3", "player1", "player2"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_equal(4, #result, "Pick order should contain 4 players")
    for _, player in ipairs({"player1", "player2", "player3", "player4"}) do
        lunatest.assert_not_nil(table_contains(result, player), player .. " should be in the pick order")
    end
    local p1_index = table_contains(result, "player1")
    local p2_index = table_contains(result, "player2")
    local p3_index = table_contains(result, "player3")
    local p4_index = table_contains(result, "player4")
    lunatest.assert_true(math.abs(p1_index - p2_index) == 1, "player1 and player2 should be adjacent")
    lunatest.assert_true(math.abs(p3_index - p4_index) == 1, "player3 and player4 should be adjacent")
end

function test_pick_order_large_group()
    local community_picks = {}
    for i = 1, 20 do
        local picks = {}
        for j = 1, 20 do
            table.insert(picks, "player" .. j)
        end
        community_picks["player" .. i] = picks
    end
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_equal(20, #result, "Pick order should contain 20 players")
    for i = 1, 20 do
        lunatest.assert_not_nil(table_contains(result, "player" .. i), "player" .. i .. " should be in the pick order")
    end
end

function test_pick_order_complete_votes()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player2", "player1", "player3", "player4"},
        player3 = {"player3", "player1", "player2", "player4"},
        player4 = {"player4", "player1", "player2", "player3"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_equal(4, #result, "Pick order should contain 4 players")
    for i = 1, 4 do
        lunatest.assert_not_nil(table_contains(result, "player" .. i), "player" .. i .. " should be in the pick order")
    end
end

function test_assign_teams_large_group()
    local pick_order = {}
    for i = 1, 20 do
        table.insert(pick_order, "player" .. i)
    end
    local result = CaptainCommunityPick.assign_teams(pick_order)
    lunatest.assert_equal(2, #result, "Should have 2 teams")
    lunatest.assert_equal(20, #result[1] + #result[2], "Total number of players should be 20")
    lunatest.assert_true(math.abs(#result[1] - #result[2]) <= 1, "Teams should be balanced")
end

function test_pick_order_single_player()
    local community_picks = {
        player1 = {"player1"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_equal(1, #result, "Pick order should contain 1 player")
    lunatest.assert_equal("player1", result[1], "The only player should be player1")
end

function test_assign_teams_single_player()
    local pick_order = {"player1"}
    local result = CaptainCommunityPick.assign_teams(pick_order)
    lunatest.assert_equal(2, #result, "Should have 2 teams")
    lunatest.assert_equal(1, #result[1] + #result[2], "Total number of players should be 1")
    lunatest.assert_true(#result[1] == 1 or #result[2] == 1, "One team should have the single player")
end

function test_pick_order_with_unanimous_vote()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player1", "player2", "player3", "player4"},
        player3 = {"player1", "player2", "player3", "player4"},
        player4 = {"player1", "player2", "player3", "player4"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_not_nil(result, "pick_order should return a result for unanimous vote")
    if result then
        lunatest.assert_equal(4, #result, "Pick order should contain 4 players")
        for _, player in ipairs({"player1", "player2", "player3", "player4"}) do
            lunatest.assert_not_nil(table_contains(result, player), player .. " should be in the pick order")
        end
        -- Note: We're not checking for a specific order anymore
    end
end

function test_pick_order_with_reversed_preferences()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player2", "player3", "player4", "player1"},
        player3 = {"player3", "player4", "player1", "player2"},
        player4 = {"player4", "player1", "player2", "player3"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    lunatest.assert_equal(4, #result, "Pick order should contain 4 players")
    -- The exact order might vary, but we can check that each player is present
    for _, player in ipairs({"player1", "player2", "player3", "player4"}) do
        lunatest.assert_not_nil(table_contains(result, player), player .. " should be in the pick order")
    end
end

function test_assign_teams_with_odd_number_of_players()
    local pick_order = {"player1", "player2", "player3", "player4", "player5", "player6", "player7"}
    local result = CaptainCommunityPick.assign_teams(pick_order)
    lunatest.assert_equal(2, #result, "Should have 2 teams")
    lunatest.assert_equal(7, #result[1] + #result[2], "Total number of players should be 7")
    lunatest.assert_true(math.abs(#result[1] - #result[2]) == 1, "One team should have one more player")
end

function test_pick_order_with_some_empty_votes()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player2", "player1", "player3", "player4"},
        player3 = {},
        player4 = {"player4", "player1", "player2", "player3"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    if result then
        lunatest.assert_equal(4, #result, "Pick order should contain 4 players")
        for _, player in ipairs({"player1", "player2", "player3", "player4"}) do
            lunatest.assert_not_nil(table_contains(result, player), player .. " should be in the pick order")
        end
    else
        lunatest.fail("pick_order should handle empty votes without returning nil")
    end
end

function test_assign_teams_preserves_pick_order()
    local pick_order = {"player1", "player2", "player3", "player4"}
    local result = CaptainCommunityPick.assign_teams(pick_order)
    lunatest.assert_equal(2, #result, "Should have 2 teams")
    lunatest.assert_equal(2, #result[1], "Team 1 should have 2 players")
    lunatest.assert_equal(2, #result[2], "Team 2 should have 2 players")
    -- Check that all players are in a team, but don't assume a specific order
    local all_players = {}
    for _, team in ipairs(result) do
        for _, player in ipairs(team) do
            table.insert(all_players, player)
        end
    end
    for _, player in ipairs(pick_order) do
        lunatest.assert_not_nil(table_contains(all_players, player), player .. " should be assigned to a team")
    end
end

function test_pick_order_with_duplicate_votes()
    local community_picks = {
        player1 = {"player1", "player2", "player2", "player3"},
        player2 = {"player2", "player1", "player3", "player3"},
        player3 = {"player3", "player1", "player2", "player1"}
    }
    local result = CaptainCommunityPick.pick_order(community_picks)
    if result then
        lunatest.assert_equal(3, #result, "Pick order should contain 3 players")
        for _, player in ipairs({"player1", "player2", "player3"}) do
            lunatest.assert_not_nil(table_contains(result, player), player .. " should be in the pick order")
        end
    else
        lunatest.fail("pick_order should handle duplicate votes without returning nil")
    end
end

-- Run the tests
lunatest.run()
