local lunatest = require("lunatest")
local CaptainCommunityPick = require("comfy_panel.special_games.captain_community_pick")
local CaptainCommunityPickGroups = require("comfy_panel.special_games.captain_community_pick_groups")

print("CaptainCommunityPickGroups type:", type(CaptainCommunityPickGroups))
if type(CaptainCommunityPickGroups) == "table" then
    for k, v in pairs(CaptainCommunityPickGroups) do
        print(k, type(v))
    end
else
    print("CaptainCommunityPickGroups is not a table")
end

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
    for _, value in pairs(t) do
        if value == element then
            return true
        end
    end
    return false
end

local function groups_together(teams, groups)
    for _, group in ipairs(groups) do
        local group_team = nil
        for team_index, team in ipairs(teams) do
            if table_contains(team, group[1]) then
                group_team = team_index
                break
            end
        end
        if group_team then
            for _, player in ipairs(group) do
                if not table_contains(teams[group_team], player) then
                    return false
                end
            end
        else
            return false
        end
    end
    return true
end

-- Test cases
function test_basic_group_assignment()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3"}
    }
    local groups = {{"player1", "player2"}, {"player4", "player5"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "Groups should always be kept together")
end

function test_multiple_groups()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6", "player7", "player8"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6", "player7", "player8"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6", "player7", "player8"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3", "player7", "player8"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3", "player7", "player8"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3", "player7", "player8"},
        player7 = {"player7", "player8", "player1", "player2", "player3", "player4", "player5", "player6"},
        player8 = {"player8", "player7", "player1", "player2", "player3", "player4", "player5", "player6"}
    }
    local groups = {{"player1", "player2"}, {"player4", "player5"}, {"player7", "player8"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "All groups should always be kept together")
end

function test_uneven_groups()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6", "player7"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6", "player7"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6", "player7"},
        player4 = {"player4", "player5", "player1", "player2", "player3", "player6", "player7"},
        player5 = {"player5", "player4", "player1", "player2", "player3", "player6", "player7"},
        player6 = {"player6", "player7", "player1", "player2", "player3", "player4", "player5"},
        player7 = {"player7", "player6", "player1", "player2", "player3", "player4", "player5"}
    }
    local groups = {{"player1", "player2", "player3"}, {"player6", "player7"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "Uneven groups should always be kept together")
end

function test_large_group()
    local community_picks = {}
    for i = 1, 10 do
        community_picks["player" .. i] = {}
        for j = 1, 10 do
            table.insert(community_picks["player" .. i], "player" .. j)
        end
    end
    local groups = {{"player1", "player2", "player3", "player4", "player5"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "Large groups should always be kept together, even if it causes imbalance")
end

function test_all_players_in_groups()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3"}
    }
    local groups = {{"player1", "player2", "player3"}, {"player4", "player5", "player6"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "All groups should be kept together even when all players are in groups")
    lunatest.assert_equal(2, #teams, "There should still be two teams")
    lunatest.assert_equal(3, #teams[1], "First team should have 3 players")
    lunatest.assert_equal(3, #teams[2], "Second team should have 3 players")
end

function test_group_priority_over_balance()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6", "player7"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6", "player7"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6", "player7"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3", "player7"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3", "player7"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3", "player7"},
        player7 = {"player7", "player1", "player2", "player3", "player4", "player5", "player6"}
    }
    local groups = {{"player1", "player2", "player3", "player4"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "Large group should be kept together even if it causes significant imbalance")
    local group_team = table_contains(teams[1], "player1") and 1 or 2
    lunatest.assert_equal(4, #teams[group_team], "Team with the group should have 4 players")
    lunatest.assert_equal(3, #teams[3-group_team], "Other team should have 3 players")
end

function test_maximum_group_size()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3"}
    }
    local groups = {{"player1", "player2", "player3"}}  -- Maximum allowed group size
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "Maximum size group should be kept together")
    local group_team = table_contains(teams[1], "player1") and 1 or 2
    lunatest.assert_equal(3, #teams[group_team], "Team with the maximum size group should have 3 players")
end

function test_multiple_maximum_size_groups()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3"}
    }
    local groups = {{"player1", "player2", "player3"}, {"player4", "player5", "player6"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "Multiple maximum size groups should be kept together")
    lunatest.assert_equal(3, #teams[1], "First team should have 3 players")
    lunatest.assert_equal(3, #teams[2], "Second team should have 3 players")
end

function test_mixed_group_sizes()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6", "player7"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6", "player7"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6", "player7"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3", "player7"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3", "player7"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3", "player7"},
        player7 = {"player7", "player1", "player2", "player3", "player4", "player5", "player6"}
    }
    local groups = {{"player1", "player2", "player3"}, {"player4", "player5"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_true(groups_together(teams, groups), "Groups of different sizes should be kept together")
    lunatest.assert_equal(7, #teams[1] + #teams[2], "All players should be assigned to teams")
end

function test_empty_groups()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4"},
        player2 = {"player2", "player1", "player3", "player4"},
        player3 = {"player3", "player4", "player1", "player2"},
        player4 = {"player4", "player3", "player1", "player2"}
    }
    local groups = {}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = CaptainCommunityPickGroups.assign_teams_with_groups(result, groups)
    
    lunatest.assert_equal(2, #teams, "There should be two teams even with no groups")
    lunatest.assert_true(math.abs(#teams[1] - #teams[2]) <= 1, "Teams should be balanced with no groups")
end


function test_pick_order_sorting()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3"}
    }
    local groups = {{"player1", "player2"}, {"player4", "player5"}}
    local pick_pattern = {1, 2, 1, 2}  -- Custom pick pattern
    
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups, 1, pick_pattern)
    
    -- Check if the pick order follows the specified pattern
    local expected_team_pattern = {1, 2, 2, 1, 1, 2}
    for i, player in ipairs(result) do
        local expected_team = expected_team_pattern[i]
        local actual_team = (i % 2 == 1) and 1 or 2
        lunatest.assert_equal(expected_team, actual_team, 
            string.format("Player %s should be in team %d but is in team %d", player, expected_team, actual_team))
    end
end



function test_team_position_changes_with_fewer_groups()
    local num_players = 50
    local num_iterations = 100
    local min_group_size = 2
    local max_group_size = 3
    local group_percentage = 0.1  -- 10% of players in groups

    local total_order_violations = 0
    local total_position_changes = 0

    -- Create predetermined pick order
    local original_pick_order = {}
    for i = 1, num_players do
        table.insert(original_pick_order, "player" .. i)
    end

    for iteration = 1, num_iterations do
        print("\nIteration " .. iteration .. ":")
        
        -- Create community picks that will result in the desired pick order
        local community_picks = {}
        for i, player in ipairs(original_pick_order) do
            community_picks[player] = {}
            for j = i, num_players do
                table.insert(community_picks[player], original_pick_order[j])
            end
            for j = 1, i-1 do
                table.insert(community_picks[player], original_pick_order[j])
            end
        end

        -- Create random groups
        local groups = {}
        local grouped_players = {}
        local group_count = 0
        local target_group_count = math.floor(num_players * group_percentage)
        while group_count < target_group_count do
            local remaining = target_group_count - group_count
            local group_size = math.min(max_group_size, math.max(min_group_size, remaining))
            local group = {}
            for _ = 1, group_size do
                local player
                repeat
                    player = original_pick_order[math.random(num_players)]
                until not grouped_players[player]
                table.insert(group, player)
                grouped_players[player] = true
            end
            table.insert(groups, group)
            group_count = group_count + group_size
        end

        -- Print groups
        print("Groups:")
        for i, group in ipairs(groups) do
            print(string.format("Group %d: %s", i, table.concat(group, ", ")))
        end

        -- Get new pick order with groups
        local new_pick_order = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)

        -- Print pick orders
        print("Original pick order: " .. table.concat(original_pick_order, ", "))
        print("New pick order:      " .. table.concat(new_pick_order, ", "))

        -- Check for order violations and position changes
        local order_violations = 0
        local position_changes = 0
        local last_player_number = 0
        for i, player in ipairs(new_pick_order) do
            local current_player_number = tonumber(player:match("%d+"))
            if current_player_number < last_player_number then
                order_violations = order_violations + 1
            end
            last_player_number = current_player_number
            
            local original_position = table.indexof(original_pick_order, player)
            position_changes = position_changes + math.abs(i - original_position)
        end
        
        print(string.format("Order violations: %d", order_violations))
        print(string.format("Total position changes: %d", position_changes))
        
        total_order_violations = total_order_violations + order_violations
        total_position_changes = total_position_changes + position_changes

        -- Get team assignments
        local teams = CaptainCommunityPickGroups.assign_teams_with_groups(new_pick_order, groups)

        -- Print teams
        print("Team 1: " .. table.concat(teams[1], ", "))
        print("Team 2: " .. table.concat(teams[2], ", "))
        print("Team 1 size: " .. #teams[1] .. ", Team 2 size: " .. #teams[2])
    end

    local avg_order_violations = total_order_violations / num_iterations
    local avg_position_changes = total_position_changes / num_iterations

    print(string.format("\nAverage over %d iterations:", num_iterations))
    print(string.format("Average order violations: %.2f", avg_order_violations))
    print(string.format("Average position changes: %.2f", avg_position_changes))
    print(string.format("Average position change per player: %.2f", avg_position_changes / num_players))

    -- You can set thresholds for acceptable changes
    local acceptable_order_violations = num_players * 0.1  -- 10% of players
    local acceptable_position_change_per_player = 5

    lunatest.assert_true(avg_order_violations <= acceptable_order_violations, 
        string.format("Average order violations (%.2f) exceeds acceptable threshold (%.2f)", 
        avg_order_violations, acceptable_order_violations))
    
    lunatest.assert_true((avg_position_changes / num_players) <= acceptable_position_change_per_player, 
        string.format("Average position change per player (%.2f) exceeds acceptable threshold (%.2f)", 
        avg_position_changes / num_players, acceptable_position_change_per_player))
end

function update_test_team_position_changes_with_fewer_groups()
    local num_players = 50
    local num_iterations = 100
    local min_group_size = 2
    local max_group_size = 4
    local group_percentage = 0.1  -- 40% of players in groups

    local function check_pick_pattern(pick_order, pattern)
        local pattern_index = 1
        local count = pattern[pattern_index]
        local team = 1
        for i, _ in ipairs(pick_order) do
            if i % 2 ~= team then
                print("Pick pattern violation at position " .. i .. " for player " .. pick_order[i])
                return false
            end
            count = count - 1
            if count == 0 then
                team = 3 - team
                pattern_index = pattern_index % #pattern + 1
                count = pattern[pattern_index]
            end
        end
        return true
    end

    local function check_groups_in_same_team(pick_order, groups)
        for _, group in ipairs(groups) do
            local team = table.indexof(pick_order, group[1]) % 2
            for i = 2, #group do
                if table.indexof(pick_order, group[i]) % 2 ~= team then
                    print("Group split: " .. table.concat(group, ", "))
                    return false
                end
            end
        end
        return true
    end

    local function calculate_order_preservation(original_order, new_order)
        local total_positions = #original_order
        local total_displacement = 0
        for i, player in ipairs(original_order) do
            local new_pos = table.indexof(new_order, player)
            total_displacement = total_displacement + math.abs(i - new_pos)
        end
        return 1 - (total_displacement / (total_positions * total_positions))
    end

    local total_order_violations = 0
    local total_position_changes = 0
    local total_order_preservation = 0

    for iteration = 1, num_iterations do
        print("\nIteration " .. iteration .. ":")
        
        -- Create original pick order
        local original_pick_order = {}
        for i = 1, num_players do
            table.insert(original_pick_order, "player" .. i)
        end

        -- Create community picks
        local community_picks = {}
        for i, player in ipairs(original_pick_order) do
            community_picks[player] = {}
            for j = 1, num_players do
                table.insert(community_picks[player], "player" .. j)
            end
        end

        -- Create random groups
        local groups = {}
        local grouped_players = {}
        local group_count = 0
        local target_group_count = math.floor(num_players * group_percentage)
        while group_count < target_group_count do
            local group_size = math.random(min_group_size, max_group_size)
            if group_count + group_size > target_group_count then
                group_size = target_group_count - group_count
            end
            local group = {}
            for _ = 1, group_size do
                local player
                repeat
                    player = "player" .. math.random(num_players)
                until not grouped_players[player]
                table.insert(group, player)
                grouped_players[player] = true
            end
            table.insert(groups, group)
            group_count = group_count + group_size
        end

        -- Get new pick order with groups
        local new_pick_order = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups, 1, {1, 2, 2, 2})
        print("Groups:")
        for i, group in ipairs(groups) do
            print(string.format("Group %d: %s", i, table.concat(group, ", ")))
        end        
        -- Print pick orders
        print("Original pick order: " .. table.concat(original_pick_order, ", "))
        print("New pick order:      " .. table.concat(new_pick_order, ", "))

        -- Print teams
        local team1, team2 = {}, {}
        for i, player in ipairs(new_pick_order) do
            if i % 2 == 1 then table.insert(team1, player) else table.insert(team2, player) end
        end
        print("Team 1: " .. table.concat(team1, ", "))
        print("Team 2: " .. table.concat(team2, ", "))

        -- Check if the pick pattern is followed
        local pattern_followed = check_pick_pattern(new_pick_order, {1, 2, 2, 2})
        lunatest.assert_true(pattern_followed, "Pick pattern should be followed")

        -- Check if groups are in the same team
        local groups_same_team = check_groups_in_same_team(new_pick_order, groups)
        lunatest.assert_true(groups_same_team, "Groups should be in the same team")

        -- Check if player1 is in the first team (odd index)
        local player1_index = table.indexof(new_pick_order, "player1")
        lunatest.assert_equal(1, player1_index, "player1 should be first in the pick order")

        -- Calculate order preservation
        local order_preservation = calculate_order_preservation(original_pick_order, new_pick_order)
        total_order_preservation = total_order_preservation + order_preservation
        print(string.format("Order preservation: %.2f", order_preservation))

        -- Calculate order violations and position changes
        local order_violations = 0
        local position_changes = 0
        local last_player_number = 0
        for i, player in ipairs(new_pick_order) do
            local current_player_number = tonumber(player:match("%d+"))
            if current_player_number < last_player_number then
                order_violations = order_violations + 1
            end
            last_player_number = current_player_number
            
            local original_position = table.indexof(original_pick_order, player)
            position_changes = position_changes + math.abs(i - original_position)
        end
        
        total_order_violations = total_order_violations + order_violations
        total_position_changes = total_position_changes + position_changes

        print(string.format("Order violations: %d", order_violations))
        print(string.format("Total position changes: %d", position_changes))
    end

    local avg_order_violations = total_order_violations / num_iterations
    local avg_position_changes = total_position_changes / num_iterations
    local avg_order_preservation = total_order_preservation / num_iterations

    print(string.format("\nAverage over %d iterations:", num_iterations))
    print(string.format("Average order violations: %.2f", avg_order_violations))
    print(string.format("Average position changes: %.2f", avg_position_changes))
    print(string.format("Average position change per player: %.2f", avg_position_changes / num_players))
    print(string.format("Average order preservation: %.2f", avg_order_preservation))

    -- Adjust these thresholds as needed
    local max_acceptable_violations = 20
    local max_acceptable_position_change_per_player = 20
    local min_acceptable_preservation = 0.7

    lunatest.assert_true(avg_order_violations <= max_acceptable_violations, 
        string.format("Average order violations (%.2f) exceeds acceptable threshold (%.2f)", 
        avg_order_violations, max_acceptable_violations))
    
    lunatest.assert_true((avg_position_changes / num_players) <= max_acceptable_position_change_per_player, 
        string.format("Average position change per player (%.2f) exceeds acceptable threshold (%.2f)", 
        avg_position_changes / num_players, max_acceptable_position_change_per_player))

    lunatest.assert_true(avg_order_preservation >= min_acceptable_preservation,
        string.format("Average order preservation (%.2f) is below acceptable threshold (%.2f)",
        avg_order_preservation, min_acceptable_preservation))
end
-- Helper function to find index of an element in a table
function table.indexof(t, element)
    for i, v in ipairs(t) do
        if v == element then
            return i
        end
    end
    return nil
end
-- Helper function to find index of an element in a table
function table.indexof(t, element)
    for i, v in ipairs(t) do
        if v == element then
            return i
        end
    end
    return nil
end


local function check_groups_together(teams, groups)
    for _, group in ipairs(groups) do
        local group_team = nil
        for team_index, team in ipairs(teams) do
            if table_contains(team, group[1]) then
                group_team = team_index
                break
            end
        end
        if group_team then
            for _, player in ipairs(group) do
                if not table_contains(teams[group_team], player) then
                    print("Group split: " .. table.concat(group, ", "))
                    return false
                end
            end
        else
            print("Group not found: " .. table.concat(group, ", "))
            return false
        end
    end
    return true
end

function test_basic_group_assignment()
    local community_picks = {
        player1 = {"player1", "player2", "player3", "player4", "player5", "player6"},
        player2 = {"player2", "player1", "player3", "player4", "player5", "player6"},
        player3 = {"player3", "player1", "player2", "player4", "player5", "player6"},
        player4 = {"player4", "player5", "player6", "player1", "player2", "player3"},
        player5 = {"player5", "player4", "player6", "player1", "player2", "player3"},
        player6 = {"player6", "player4", "player5", "player1", "player2", "player3"}
    }
    local groups = {{"player1", "player2"}, {"player4", "player5"}}
    local result = CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups)
    local teams = {{}, {}}
    for i, player in ipairs(result) do
        table.insert(teams[(i % 2) + 1], player)
    end
    
    print("Pick order: " .. table.concat(result, ", "))
    print("Team 1: " .. table.concat(teams[1], ", "))
    print("Team 2: " .. table.concat(teams[2], ", "))
    
    lunatest.assert_true(check_groups_together(teams, groups), "Groups should always be kept together")
end

-- Run the tests
lunatest.run()

