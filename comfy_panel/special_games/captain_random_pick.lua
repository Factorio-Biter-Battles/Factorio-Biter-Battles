
local CaptainRandomPick = {}

local function removeStringFromTable(tab, str)
	for i, entry in ipairs(tab) do
		if entry == str then
			table.remove(tab, i)
			break  -- Stop the loop once the string is found and removed
		end
	end
end

local function convert_zero_to_nil(x)
	if x == 0 then
		return nil
	else
		return x
	end
end

local function cancel_matching_surpluses(surpluses)
	for bucket, surplus in pairs(surpluses[1]) do
		local surplus2 = surpluses[2][bucket] or 0
		local min_surplus = math.min(surplus, surplus2)
		surpluses[1][bucket] = convert_zero_to_nil(surplus - min_surplus)
		surpluses[2][bucket] = convert_zero_to_nil(surplus2 - min_surplus)
	end
end

local function are_all_buckets_empty(buckets)
	for _, bucket in ipairs(buckets) do
		if #bucket > 0 then
			return false
		end
	end
	return true
end

-- Given a list of buckets, each containing a list of players, return a list of two teams, each containing a list of players.
---@param buckets_in string[][]
---@param forced_assignments table<string, number>
---@param groups table<string, string[]> -- groups of players that should be kept together
---@return string[][]
function CaptainRandomPick.assign_teams_from_buckets(buckets_in, forced_assignments, groups, seed)
	--log("buckets_in: " .. serpent.line(buckets_in) .. " forced_assignments: " .. serpent.line(forced_assignments) .. " groups: " .. serpent.line(groups) .. " seed: " .. seed)
	local buckets = table.deepcopy(buckets_in)
	local rnd = game.create_random_generator(seed)
	local valid_players = {}
	for _, bucket in ipairs(buckets) do
		for _, player in ipairs(bucket) do
			valid_players[player] = true
		end
	end

	local player_to_group_name = {}
	for group_name, group in pairs(groups) do
		local forced_team
		for i = #group, 1, -1 do
			if not valid_players[group[i]] then
				table.remove(group, i)
			elseif forced_assignments[group[i]] then
				local new_forced_team = forced_assignments[group[i]]
				if forced_team and forced_team ~= new_forced_team then
					-- Two players in same group are forced to different teams, remove someone from the team
					table.remove(group, i)
				else
					forced_team = new_forced_team
				end
			end
		end
		if #group == 0 then
			groups[group_name] = nil
		end
		for _, player in ipairs(group) do
			if valid_players[player] then
				player_to_group_name[player] = group_name
			end
		end
	end

	local groups_remaining = {}
	for group_name, _ in pairs(groups) do
		table.insert(groups_remaining, group_name)
	end
	table.sort(groups_remaining)


	local player_to_bucket = {}
	for bucket_index, bucket in ipairs(buckets) do
		for _, player in ipairs(bucket) do
			player_to_bucket[player] = bucket_index
		end
	end

	local result = {{}, {}}
	local result_surpluses = {{}, {}}

	local function assign_player_to_team(player, team)
		local players_in_group = {player}
		local group_name = player_to_group_name[player]
		if group_name then
			players_in_group = groups[group_name]
			removeStringFromTable(groups_remaining, group_name)
		end
		for _, player_in_group in ipairs(players_in_group) do
			if valid_players[player_in_group] then
				table.insert(result[team], player_in_group)
				local bucket = player_to_bucket[player_in_group]
				result_surpluses[team][bucket] = (result_surpluses[team][bucket] or 0) + 1
				removeStringFromTable(buckets[bucket], player_in_group)
			end
		end
	end

	-- First handle the forced assignments
	for player, team in pairs(forced_assignments) do
		if valid_players[player] then
			assign_player_to_team(player, team)
		end
	end

	---@param bucket number
	local function find_player_at_bucket(bucket)
		if #buckets[bucket] > 0 then
			return buckets[bucket][rnd(1, #buckets[bucket])]
		else
			for i = 1, #buckets * 2 do
				local bucket_delta = math.ceil(i / 2) * (i % 2 == 0 and -1 or 1)
				local close_bucket = buckets[bucket + bucket_delta]
				if close_bucket and #close_bucket > 0 then
					return close_bucket[rnd(1, #close_bucket)]
				end
			end
		end
	end

	::top_of_loop::
	while not are_all_buckets_empty(buckets) do
		cancel_matching_surpluses(result_surpluses)
		-- First address all surpluses
		for _, team in ipairs(rnd(1, 2) == 1 and {1, 2} or {2, 1}) do
			for bucket, surplus in pairs(result_surpluses[team]) do
				while surplus > 0 do
					local player = find_player_at_bucket(bucket)
					local found_player_bucket = player_to_bucket[player]
					if found_player_bucket ~= bucket then
						-- We couldn't find a matching player, so we adjust this surplus to match
						-- the player that we did find
						result_surpluses[team][bucket] = convert_zero_to_nil(surplus - 1)
						result_surpluses[team][found_player_bucket] = (result_surpluses[team][found_player_bucket] or 0) + 1
					end
					assign_player_to_team(player, team == 1 and 2 or 1)
					goto top_of_loop
				end
			end
		end
		-- No surpluses, do random assignment of someone
		local team = rnd(1, 2)
		-- First try and assign groups
		if #groups_remaining > 0 then
			local group_name = groups_remaining[rnd(1, #groups_remaining)]
			local group = groups[group_name]
			assign_player_to_team(group[1], team)
			goto top_of_loop
		end
		-- No groups, assign a random player from the best bucket first
		for bucket, bucket_players in ipairs(buckets) do
			if #bucket_players > 0 then
				assign_player_to_team(bucket_players[rnd(1, #bucket_players)], team)
				goto top_of_loop
			end
		end
	end

	return result
end

return CaptainRandomPick
