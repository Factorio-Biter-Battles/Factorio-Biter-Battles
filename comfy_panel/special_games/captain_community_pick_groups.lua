local CaptainCommunityPick = require("comfy_panel.special_games.captain_community_pick")
local Color = require('utils.color_presets')

local CaptainCommunityPickGroups = {}

-- Configuration
local DEFAULT_CONFIG = {
    max_iterations = 100,
    local_swap_range = 5,
    resistance_decay = 0.9,
    weight_group_integrity = 1.0,
    weight_order_preservation = 0.7,
    weight_team_balance = 0.5,
    max_team_size_diff = 1,
    seed = os.time()
}

-- Utility functions
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

local function shuffle(tbl, seed)
    local rng = math.randomseed(seed)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

local function calculate_resistance(position, total_positions, decay)
    return math.exp(-decay * (position - 1) / total_positions)
end

local function table_indexof(t, element)
    for i, v in ipairs(t) do
        if v == element then
            return i
        end
    end
    return nil
end

-- Core algorithm functions
local function generate_initial_pick_order(community_picks, config)
    local picks = {}
    for player, _ in pairs(community_picks) do
        table.insert(picks, player)
    end
    shuffle(picks, config.seed)
    return picks
end

local function calculate_group_cost(group, pick_order, config)
    local positions = {}
    for _, player in ipairs(group) do
        local pos = table_indexof(pick_order, player)
        if pos then
            table.insert(positions, pos)
        end
    end
    if #positions == 0 then
        return 0, nil
    end
    table.sort(positions)
    
    local median_pos = positions[math.ceil(#positions / 2)]
    local total_cost = 0
    for i, pos in ipairs(positions) do
        local target_pos = median_pos - math.floor(#positions / 2) + i - 1
        local resistance = calculate_resistance(pos, #pick_order, config.resistance_decay)
        total_cost = total_cost + math.abs(pos - target_pos) * resistance
    end
    return total_cost, median_pos
end

local function place_group(group, pick_order, config)
    local cost, median_pos = calculate_group_cost(group, pick_order, config)
    if not median_pos then return end  -- Exit if the group couldn't be placed
    
    -- Remove group members from current positions
    local group_set = {}
    for _, player in ipairs(group) do
        group_set[player] = true
    end
    local removed = {}
    for i = #pick_order, 1, -1 do
        if group_set[pick_order[i]] then
            table.insert(removed, 1, table.remove(pick_order, i))
        end
    end
    
    -- Find the best position to insert the group
    local best_pos = median_pos
    local best_cost = math.huge
    for pos = 1, #pick_order + 1 do
        local temp_order = deepcopy(pick_order)
        for i, player in ipairs(removed) do
            table.insert(temp_order, pos + i - 1, player)
        end
        local new_cost = calculate_group_cost(group, temp_order, config)
        if new_cost < best_cost then
            best_cost = new_cost
            best_pos = pos
        end
    end
    
    -- Insert group members at best position
    for i, player in ipairs(removed) do
        table.insert(pick_order, best_pos + i - 1, player)
    end
end

local function calculate_score(pick_order, original_order, groups, config)
    local order_score = 0
    local group_score = 0
    local balance_score = 0
    
    -- Order preservation score
    for i, player in ipairs(pick_order) do
        local original_pos = table_indexof(original_order, player)
        order_score = order_score + math.abs(i - original_pos)
    end
    
    -- Group integrity score
    for _, group in ipairs(groups) do
        local cost, _ = calculate_group_cost(group, pick_order, config)
        group_score = group_score + cost
    end
    
    -- Team balance score
    local team1_size = math.ceil(#pick_order / 2)
    local team2_size = #pick_order - team1_size
    balance_score = math.abs(team1_size - team2_size)
    
    return -(config.weight_order_preservation * order_score +
             config.weight_group_integrity * group_score +
             config.weight_team_balance * balance_score)
end

local function local_optimization(pick_order, original_order, groups, config)
    local best_score = calculate_score(pick_order, original_order, groups, config)
    local improved = true
    
    while improved do
        improved = false
        for i = 1, #pick_order do
            for j = math.max(1, i - config.local_swap_range), math.min(#pick_order, i + config.local_swap_range) do
                if i ~= j then
                    pick_order[i], pick_order[j] = pick_order[j], pick_order[i]
                    local new_score = calculate_score(pick_order, original_order, groups, config)
                    if new_score > best_score then
                        best_score = new_score
                        improved = true
                    else
                        pick_order[i], pick_order[j] = pick_order[j], pick_order[i]  -- Revert swap
                    end
                end
            end
        end
    end
end

function CaptainCommunityPickGroups.pick_order_with_groups(community_picks, groups, seed, pick_pattern)
    local config = deepcopy(DEFAULT_CONFIG)
    config.seed = seed or config.seed
    
    local original_order = generate_initial_pick_order(community_picks, config)
    local pick_order = deepcopy(original_order)
    
    -- Sort groups by size, largest first
    table.sort(groups, function(a, b) return #a > #b end)
    
    -- Place groups
    for _, group in ipairs(groups) do
        if #group > 0 then  -- Only place non-empty groups
            place_group(group, pick_order, config)
        end
    end
    
    -- Iterative optimization
    for _ = 1, config.max_iterations do
        local_optimization(pick_order, original_order, groups, config)
    end
    
    -- Assign teams and get final pick order
    local teams, final_pick_order = CaptainCommunityPickGroups.assign_teams_with_groups(pick_order, groups, original_order, pick_pattern)
    
    return final_pick_order
end
function CaptainCommunityPickGroups.assign_teams_with_groups(pick_order, groups, original_order, pick_pattern)
    original_order = original_order or deepcopy(pick_order)
    pick_pattern = pick_pattern or {1, 1}
    
    local teams = {{}, {}}
    local group_map = {}
    local assigned_players = {}
    
    -- Create a map of players to their groups
    for _, group in ipairs(groups) do
        for _, player in ipairs(group) do
            group_map[player] = group
        end
    end
    
    -- Assign players to teams in the order of pick_order, keeping groups together
    local current_team = 1
    local pattern_index = 1
    local pattern_count = pick_pattern[pattern_index]
    
    for _, player in ipairs(pick_order) do
        if not assigned_players[player] then
            local group = group_map[player]
            if group then
                -- Assign entire group
                for _, group_player in ipairs(group) do
                    if not assigned_players[group_player] then
                        table.insert(teams[current_team], group_player)
                        assigned_players[group_player] = true
                    end
                end
            else
                -- Assign individual player
                table.insert(teams[current_team], player)
                assigned_players[player] = true
            end
            
            pattern_count = pattern_count - 1
            if pattern_count == 0 then
                current_team = 3 - current_team  -- Switch teams (1 -> 2, 2 -> 1)
                pattern_index = pattern_index % #pick_pattern + 1
                pattern_count = pick_pattern[pattern_index]
            end
        end
    end
    
    -- Create final pick order by interleaving teams according to the pick pattern
    local final_pick_order = {}
    local team_indices = {1, 1}
    pattern_index = 1
    pattern_count = pick_pattern[pattern_index]
    
    while #final_pick_order < #pick_order do
        local team = pattern_index % 2 + 1
        if team_indices[team] <= #teams[team] then
            table.insert(final_pick_order, teams[team][team_indices[team]])
            team_indices[team] = team_indices[team] + 1
        end
        
        pattern_count = pattern_count - 1
        if pattern_count == 0 then
            pattern_index = pattern_index % #pick_pattern + 1
            pattern_count = pick_pattern[pattern_index]
        end
    end
    
    return teams, final_pick_order
end




return CaptainCommunityPickGroups
