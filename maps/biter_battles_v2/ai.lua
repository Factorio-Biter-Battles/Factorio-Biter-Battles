local Public = {}
local BiterRaffle = require "maps.biter_battles_v2.biter_raffle"
local bb_config = require "maps.biter_battles_v2.config"
local BossUnit = require "functions.boss_unit"
local fifo = require "maps.biter_battles_v2.fifo"
local Tables = require "maps.biter_battles_v2.tables"
local AiStrikes = require "maps.biter_battles_v2.ai_strikes"
local AiTargets = require "maps.biter_battles_v2.ai_targets"
local functions = require "maps.biter_battles_v2.functions"
local math_random = math.random
local math_floor = math.floor

local threat_values = {
	["small-spitter"] = 1.5,
	["small-biter"] = 1.5,
	["medium-spitter"] = 4.5,
	["medium-biter"] = 4.5,
	["big-spitter"] = 13,
	["big-biter"] = 13,
	["behemoth-spitter"] = 38.5,
	["behemoth-biter"] = 38.5,
	["small-worm-turret"] = 8,
	["medium-worm-turret"] = 16,
	["big-worm-turret"] = 24,
	["behemoth-worm-turret"] = 32,
	["biter-spawner"] = 32,
	["spitter-spawner"] = 32
}

local function get_threat_ratio(biter_force_name)
	if global.bb_threat[biter_force_name] <= 0 then return 0 end
	local t1 = global.bb_threat["north_biters"]
	local t2 = global.bb_threat["south_biters"]
	if t1 == 0 and t2 == 0 then return 0.5 end
	if t1 < 0 then t1 = 0 end
	if t2 < 0 then t2 = 0 end
	local total_threat = t1 + t2
	local ratio = global.bb_threat[biter_force_name] / total_threat
	return ratio
end

Public.send_near_biters_to_silo = function()
	if game.ticks_played < 108000 then return end
	if not global.rocket_silo["north"] then return end
	if not global.rocket_silo["south"] then return end

	game.surfaces[global.bb_surface_name].set_multi_command({
		command={
			type=defines.command.attack,
			target=global.rocket_silo["north"],
			distraction=defines.distraction.none
			},
		unit_count = 8,
		force = "north_biters",
		unit_search_distance = 64
		})

	game.surfaces[global.bb_surface_name].set_multi_command({
		command={
			type=defines.command.attack,
			target=global.rocket_silo["south"],
			distraction=defines.distraction.none
			},
		unit_count = 8,
		force = "south_biters",
		unit_search_distance = 64
		})
end

local function get_random_spawner(biter_force_name)
	local spawners = global.unit_spawners[biter_force_name]
	local size_of_spawners = #spawners

	for _ = 1, 256, 1 do
		if size_of_spawners == 0 then return end
		local index = math_random(1, size_of_spawners)
		local spawner = spawners[index]
		if spawner and spawner.valid then
			return spawner
		else
			table.remove(spawners, index)
			size_of_spawners = size_of_spawners - 1
		end
	end
end

-- composition_type - Returns a dominant type of biter group composition.
local function composition_type()
	local types = {"biter", "mixed", "mixed", "spitter", "spitter"}
	return types[math_random(1, #types)]
end

-- potential_boss_cnt - Outputs a number of bosses to be present in group for a given threat
-- value. The formula works by increasing the amount of bosses depending on evolution
-- factor. The evolution factor is used here indirectly. The 'max_group_size' is changed
-- depending on evolution factor.
local function potential_boss_cnt(b_force)
	local coeff = global.max_group_size_initial - global.max_group_size[b_force]
	return math.ceil(coeff / 20)
end

-- boss_health_reanim_buff - Compute the extra factor for boss health. It comes
-- from reanimation chance. The higher the chance, the higher the % is. At 90%
-- revive chance, we have 0.01% extra health. Not really sure if that was original
-- idea, but let's keep it in.
local function boss_health_reanim_buff(b_force)
        return 1.0 / (1.0 - global.reanim_chance[b_force.index] / 100)
end

-- boss_health_factor - Output factor by which HP of original biter must be multiplied
-- to arrive at final boss HP value.
local function boss_health_factor(b_force)
        return bb_config.health_multiplier_boss * boss_health_reanim_buff(b_force)
end

-- boss_threat_yield - Output a value which represents how much threat we expect
-- to subtract by killing it.
local function boss_threat_yield(b_force, name)
        local buff = boss_health_reanim_buff(b_force)
        return threat_values[name] * 20 * buff
end

-- biter_composition - Compute the composition of a forming biter group, based on
-- threat and evo. The result of this function is an array of entity names, boss
-- count and the reminder of threat that must be piped back into this function.
-- Each biter composition is soaking in all available threat.
local function biter_composition(b_force)
	-- Establish dominant composition of biter group, then compute
	-- capacity and start rolling names of biters.
	local threat = global.bb_threat_realized[b_force]
	local group_type = composition_type()
	local cap = global.max_group_size[b_force]
	local evo = global.bb_evolution[b_force]
	local names = {}
	-- Loop until we get full capacity or we exceed threat.
	for i = 1, cap do
		if threat <= 0 then
			break
		end

		local name = BiterRaffle.roll(group_type, evo)
		threat = threat - threat_values[name]
		names[#names + 1] = name
	end
	cap = #names

	-- Compute the potential.
	local cnt = potential_boss_cnt(b_force)
	-- Now check if potential can be realized. If bosses killed don't turn threat
	-- negative, that's the only condition for them to be spawned.
	if cap < cnt then
		-- If there're more bosses than the capacity in the group, we know
		-- that loop won't yield any nominations.
		global.bb_threat_realized[b_force] = threat
		return names, 0
	end

	-- Loop until we can realize full potential or we get throttled by threat.
	local boss_cnt = 0
	for i = 1, cnt do
		if threat <= 0 then
			break
		end

		boss_cnt = boss_cnt + 1
		local name = names[i]
		local force = game.forces[b_force]
		threat = threat - boss_threat_yield(force, name)
	end

	global.bb_threat_realized[b_force] = threat
	return names, boss_cnt
end

-- request_valid - Checks if request is valid, what that means it checks if it can
-- be overriden by other request.
local function request_valid(request)
	-- Is it empty?
	if next(request) == nil then
		return false
	end

	-- Is group valid?
	local group = request.group
	if group and group.valid then
		return true
	end

	group = request.group_boss
	return (group and group.valid)
end

-- find_spare_position - Iterates over all requests and finds first request that
-- is not valid or empty. By 'not valid' we mean here request, which was executed
-- and 'group' field is no longer valid, because it was deleted by the game engine.
local function find_spare_position(force)
	local requests = global.request_groups[force]
	for i = 1, global.request_max_groups do
		local request = requests[i]
		-- If size != capacity we know that request is in use, just not fully
		-- executed yet - so skip it.
		if request.size ~= request.capacity then
			goto f_s_p
		end

		-- If request is empty or not valid, request was executed and managed
		-- unit group is deleted - up for grabs.
		if not request_valid(request) then
			return i
		end

		::f_s_p::
	end

	return nil
end

-- assign_request - Takes a fresh request, looks for spare position in pre-allocated
-- request array and overwrites it.
local function assign_request(request, b_force)
	local index = find_spare_position(b_force)
	if index == nil then
		-- Although not accessible branch, let's log an error anyway.
		print("ai::assign_request: race condition on request_groups_cnt?")
		return false
	end

	local requests = global.request_groups[b_force]
	requests[index] = request
	global.request_groups_cnt[b_force] = global.request_groups_cnt[b_force] + 1

	return true
end

-- find_request_by_id - Iterates over requests per given force trying to find request
-- with supplied id.
local function find_request_by_id(id, b_force)
	local requests = global.request_groups[b_force]
	for i = 1, global.request_max_groups do
		local request = requests[i]
		if request.group_id == id then
			return request
		end
	end

	return nil
end

-- lower_request_group_cnt - Finds to which set 'id' belongs to. The parent set is
-- then associated with biter group for which request counter is decremented.
local function request_group_lower_count(id)
	if find_request_by_id(id, "north_biters") then
		global.request_groups_cnt["north_biters"] = global.request_groups_cnt["north_biters"] - 1
	elseif find_request_by_id(id, "south_biters") then
		global.request_groups_cnt["south_biters"] = global.request_groups_cnt["south_biters"] - 1
	end
end

-- request_group_new - Creates structure representing a request. This request
-- schedules and forms unit group,
-- The expected schema of this object is a follows:
-- {
--     # Final size of a group.
--     'capacity': integer,
--     # Current size of a group.
--     'size': integer,
--     # How many of biters in this group are a boss.
--     'boss_cnt': integer,
--     # Non-unique names of entities that are expected to form a group.
--     'names': [ name1, name2, name3, ... ]
--     # Reference to unit group.
--     'group': LuaUnitGroup,
--     # Unit ID of a 'group'.
--     'group_id': integer,
--     # Reference to boss unit group.
--     'group_boss': LuaUnitGroup
--     # Unit ID of a 'group_boss'.
--     'group_boss_id': integer,
-- }
local function request_group_new(surface, position, force, names, boss_cnt)
	local group = surface.create_unit_group({
		position = position, force = force
	})
        local group_boss = surface.create_unit_group({
		position = position, force = force .. '_boss'
	})
	return {
		capacity = #names,
		size = 0,
		boss_cnt = boss_cnt,
		names = names,
		group = group,
		group_id = group.group_number,
		group_boss = group_boss,
		group_boss_id = group_boss.group_number,
	}
end

-- request_in_motion - Checks if request is in state of execution. i.e. either of
-- groups are fully formed and in state of execution.
local function request_in_motion(request)
	local group = request.group
	if group and group.valid then
		if group.command ~= nil then
			return true
		end
	end

	group = request.group_boss
	if group and group.valid then
		return (group.command ~= nil)
	end

	return false
end

-- schedule_attack_group - Requests an attack group to be created and assembled.
-- This function only creates in-memory structure. The actual work of spawning
-- it in, in done in on_tick steps.
local function schedule_attack_group(surface, b_force)
	-- Check if threat is negative.
	local threat = global.bb_threat[b_force]
	if threat <= 0 then
		return false
	end

	-- Get random spawner. Don't care about it's position.
	local spawner = get_random_spawner(b_force)
	if not spawner then
		print("no spawner found for " .. b_force)
		return false
	end

	-- Get the group composition based on evolution
	local names, boss_cnt = biter_composition(b_force)
	if #names == 0 then
		return false
	end

	-- We know there's always something to attack, as long as game is not won. So no
	-- need to check for targets yet. Use the position of spawner as rally point for
	-- biters. Allocate group request and update global state.
	local position = spawner.position
	position = surface.find_non_colliding_position("electric-furnace", position, 256, 1)
	local request = request_group_new(surface, position, b_force, names, boss_cnt)
	assign_request(request, b_force)

	return true
end

-- schedule_attack_groups - Manages the state of scheduled biter groups.
local function schedule_attack_groups(surface, force_name)
	-- If game is concluded already, don't do anything.
	if global.bb_game_won_by_team then
		return false
	end

	-- Check if we're at max capacity of groups.
	if global.request_max_groups <= global.request_groups_cnt[force_name] then
		-- We're - so abort. We enter this function periodically.
		return false
	end

	return schedule_attack_group(surface, force_name)
end

-- nominate_boss - Nominates a biter to a boss rank.
local function nominate_boss(entity)
	local factor = boss_health_factor(entity.force)
        entity.force = entity.force.name .. "_boss"
	BossUnit.add_boss_unit(entity, factor, 0.55)
end

-- step_group_formation - A re-entrant function that spawns a biter into group.
-- If the group is formed, 'true' is returned - 'false' otherwise.
local function step_group_formation(request)
	local capacity = request.capacity
	local size = request.size
	if size == capacity then
		return true
	end

	-- Create single entity per tick per each group.
	local surface = request.group.surface
	local position = request.group.position
	local boss_cnt = request.boss_cnt
	local group = request.group
	local group_boss = request.group_boss
	local force = group.force

	local index = capacity - size
	local name = request.names[index]
	position = surface.find_non_colliding_position(name, position, 128, 2)

	local e = surface.create_entity({
		name = name,
		force = force,
		position = position,
	})
	-- Create bosses if any requested.
	if boss_cnt > 0 then
		nominate_boss(e)
		group_boss.add_member(e)
		request.boss_cnt = boss_cnt - 1
	else
		group.add_member(e)
	end

	request.size = request.size + 1
	request.names[index] = nil

	-- Group not formed yet.
	return false
end

-- request_attack - Puts the unit group into motion. Optionally accepts cached strike
-- and target position. Returns final position of a strike request.
local function request_attack(group, p_force, s_position, t_position)
	if not (group and group.valid) then
		-- If boss group has no members, it's not valid
		-- Just drop the request.
		return
	end

	if s_position == nil or t_position == nil then
		t_position = AiTargets.poll(p_force)
		if not t_position then
			-- As each call to poll() function takes one selected target from pool
			-- we need to make sure to check if something is returned. For example
			-- if science is thrown at empty base without silo, this branch will
			-- be triggered.
			return
		end

		s_position = AiStrikes.calculate_strike_position(group, t_position)
	end

	AiStrikes.initiate(group, p_force, s_position, t_position)
	return s_position, t_position
end

-- _form_groups - Iterates over each available group and execute step function that will
-- incrementally form a group.
local function _form_groups(b_force, p_force)
	local requests = global.request_groups[b_force]
	for i = 1, global.request_max_groups do
		local request = requests[i]
		if not request_valid(request) then
			goto _f_g
		end

		if request_in_motion(request) then
			goto _f_g
		end

		if step_group_formation(request) then
			local s_p, t_p = request_attack(request.group, p_force)
			request_attack(request.group_boss, p_force, s_p, t_p)
		end

		::_f_g::
	end
end

-- form_groups - Module relevant function to perform any distributed action, like spawning
-- biter groups.
Public.form_groups = function()
        -- If game is concluded already, don't do anything.
	if global.bb_game_won_by_team then
		return false
	end

	_form_groups("north_biters", "north")
	_form_groups("south_biters", "south")
end

Public.manage_group = function(event)
	local id = event.unit_number
	local result = event.result

	if result ~= defines.behavior_result.in_progress then
		request_group_lower_count(id)
	end
end

Public.pre_main_attack = function()
	local force_name = global.next_attack
	AiTargets.select(force_name)

	if not global.training_mode or (global.training_mode and #game.forces[force_name].connected_players > 0) then
		local biter_force_name = force_name .. "_biters"
		global.main_attack_wave_amount = math.ceil(get_threat_ratio(biter_force_name) * 7)

		if global.bb_debug then game.print(global.main_attack_wave_amount .. " unit groups designated for " .. force_name .. " biters.") end
	else
		global.main_attack_wave_amount = 0
	end
end


Public.perform_main_attack = function()
	if global.main_attack_wave_amount > 0 then
		local surface = game.surfaces[global.bb_surface_name]
		local force_name = global.next_attack
		local biter_force_name = force_name .. "_biters"

		schedule_attack_groups(surface, biter_force_name)
		global.main_attack_wave_amount = global.main_attack_wave_amount - 1
	end
end

Public.post_main_attack = function()
	global.main_attack_wave_amount = 0
	if global.next_attack == "north" then
		global.next_attack = "south"
	else
		global.next_attack = "north"
	end
end

Public.raise_evo = function()
	if global.freeze_players then return end
	if not global.training_mode and (#game.forces.north.connected_players == 0 or #game.forces.south.connected_players == 0) then return end
	if game.ticks_played < 7200 then return end
	if ( 1 <= global.difficulty_vote_index) and ( 3 >= global.difficulty_vote_index) then
		local x = game.ticks_played/3600 -- current length of the match in minutes
		global.difficulty_vote_value = ((x / 470) ^ 3.7) + Tables.difficulties[global.difficulty_vote_index].value
	end

	local amount = math.ceil(global.evo_raise_counter * 0.75)

	if not global.total_passive_feed_redpotion then global.total_passive_feed_redpotion = 0 end
	global.total_passive_feed_redpotion = global.total_passive_feed_redpotion + amount

	local biter_teams = {["north_biters"] = "north", ["south_biters"] = "south"}
	local a_team_has_players = false
	for bf, pf in pairs(biter_teams) do
		if #game.forces[pf].connected_players > 0 then
			set_evo_and_threat(amount, "automation-science-pack", bf)
			a_team_has_players = true
		end
	end
	if not a_team_has_players then return end
	global.evo_raise_counter = global.evo_raise_counter + (1 * 0.50)
end

Public.reset_evo = function()
	-- Shouldn't reset evo if any of the teams fed. Feeding is blocked when voting is in progress.
	if game.ticks_played >= global.difficulty_votes_timeout then return end

	local amount = global.total_passive_feed_redpotion
	if amount < 1 then return end
	global.total_passive_feed_redpotion = 0

	local biter_teams = {["north_biters"] = "north", ["south_biters"] = "south"}
	for bf, _ in pairs(biter_teams) do
		global.bb_evolution[bf] = 0
		set_evo_and_threat(amount, "automation-science-pack", bf)
	end
end

-- on_unit_added_to_group - Announce new biter type if not revealed yet.
Public.on_unit_added_to_group = function(event)
	local entity = event.unit
	local name = entity.name
	local force = entity.force.name
	local team = functions.biters_to_team(force)
	team = global.tm_custom_name[team] or team

	if not global.biter_spawn_unseen[force][name] then
		return
	end

	global.biter_spawn_unseen[force][name] = false
	name = name:gsub("-", " ")
	if BossUnit.is_boss(entity) then
		game.print("A " .. name .. " boss was spotted far away on team " ..  team)
	else
		game.print("A " .. name .. " was spotted far away on team " ..  team)
	end
end

-- subtract_threat - Subtract threat by killing biters and biter structures.
function Public.subtract_threat(entity)
	local name = entity.name
	if not threat_values[name] then
		return
	end

	local f_name = entity.force.name
        local threat = threat_values[name]
	if BossUnit.is_boss(entity) then
		threat = boss_threat_yield(entity.force, name)
		f_name = functions.drop_boss_appendix(f_name)
	end

	global.bb_threat[f_name] = global.bb_threat[f_name] - threat
	if entity.type == "unit" and entity.unit_group == nil then
		-- Non-managed biter
		global.bb_threat_realized[f_name] = global.bb_threat_realized[f_name] - threat
	elseif entity.type ~= "unit" then
		-- Enemy structure
		global.bb_threat_realized[f_name] = global.bb_threat_realized[f_name] - threat
	end

	return true
end

local UNIT_NAMES = {
	'small-biter',
	'small-spitter',
	'medium-biter',
	'medium-spitter',
	'big-biter',
	'big-spitter',
	'behemoth-biter',
	'behemoth-spitter',
}
local UNIT_NAMES_LEN = #UNIT_NAMES

local function likely_biter_name(force_name)
	-- Get most likely biter name based on current evolution.
	local idx = UNIT_NAMES_LEN
	local evo = global.bb_evolution[force_name]
	-- Bother calculating threshold only for evolution less than 90.
	if evo < 0.9 then
		-- Map evolution onto array indicies.
		idx = math.ceil((evo + 0.1) * UNIT_NAMES_LEN)
	end

	-- Randomly choose between pair and respect array boundaries.
	if idx > 1 then
		idx = math_random(idx - 1, idx)
	end

	return UNIT_NAMES[idx]
end

local CORPSE_NAMES = {
	'behemoth-biter-corpse',
	'big-biter-corpse',
	'medium-biter-corpse',
	'small-biter-corpse',
	'behemoth-spitter-corpse',
	'big-spitter-corpse',
	'medium-spitter-corpse',
	'small-spitter-corpse',
}

local function reanimate_unit(id)
	local position = fifo.pop(id)

	-- Find corpse to spawn unit on top of.
	local surface = game.surfaces[global.bb_surface_name]
	local corpse = surface.find_entities_filtered {
		type = 'corpse',
		name = CORPSE_NAMES,
		position = position,
		radius = 1,
		limit = 1,
	}[1]

	local force = 'south_biters'
	if position.y < 0 then
		force = 'north_biters'
	end

	local direction = nil
	local name = nil
	if corpse == nil then
		-- No corpse data, choose unit based on evolution %.
		name = likely_biter_name(force)
	else
		-- Extract name by cutting of '-corpse' part.
		name = string.sub(corpse.name, 0, -8)
		position = corpse.position
		direction = corpse.direction
		corpse.destroy()
	end

	surface.create_entity {
		name = name,
		position = position,
		force = force,
		direction = direction,
	}
end

local function _reanimate_units(id, cycles)
	repeat
		-- Reanimate unit and reassign current fifo state
		reanimate_unit(id)
		cycles = cycles - 1
	until cycles == 0
end

function Public.reanimate_units()
	-- This FIFOs can be accessed by force indices.
	for _, id in pairs(global.dead_units) do
		-- Check for each side if there are any biters to reanimate.
		if fifo.empty(id) then
			goto reanim_units_cont
		end

		-- Balance amount of unit creation requests to get rid off
		-- excess stored in memory.
		local cycles = fifo.length(id) / global.reanim_balancer
		cycles = math_floor(cycles) + 1
		_reanimate_units(id, cycles)

		::reanim_units_cont::
	end
end

Public.schedule_reanimate = function(event)
	-- This event is to be fired from on_post_entity_died. Standard version
	-- of this event is racing with current reanimation logic. Corpse
	-- takes few ticks to spawn, there is also a short dying animation. This
	-- combined makes renimation to miss corpses on the battle field
	-- sometimes.
	
	-- If rocket silo was blown up - disable reanimate logic.
	if global.server_restart_timer ~= nil then
		return
	end

	-- There is no entity within this event and so we have to guess
	-- force based on y axis.
	local force = game.forces['south_biters']
	local position = event.position
	if position.y < 0 then
		force = game.forces['north_biters']
	end

	local idx = force.index
	local chance = global.reanim_chance[idx]
	if chance <= 0 then
		return
	end

	local reanimate = math_random(1, 100) <= chance
	if not reanimate then
		return
	end

	-- Store only position, that is enough to guess force and type of biter.
	fifo.push(global.dead_units[idx], position)
end

function Public.empty_reanim_scheduler()
	for force, id in pairs(global.dead_units) do
		-- Check for each side if there are any biters to reanimate.
		if not fifo.empty(id) then
			return false
		end
	end

	return true
end

return Public
