local Public = {}
local BiterRaffle = require "maps.biter_battles_v2.biter_raffle"
local bb_config = require "maps.biter_battles_v2.config"
local BossUnit = require "functions.boss_unit"
local Event = require 'utils.event'
local Feeding = require "maps.biter_battles_v2.feeding"
local Functions = require "maps.biter_battles_v2.functions"
local Tables = require "maps.biter_battles_v2.tables"
local AiStrikes = require "maps.biter_battles_v2.ai_strikes"
local AiTargets = require "maps.biter_battles_v2.ai_targets"
local math_random = math.random
local math_floor = math.floor

local unit_type_raffle = {"biter", "mixed", "mixed", "spitter", "spitter"}
local size_of_unit_type_raffle = #unit_type_raffle

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
	if Functions.get_ticks_since_game_start() < 108000 then return end
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

--Manual spawning of units
local function spawn_biters(isItnormalBiters, maxLoopIteration,spawner,biter_threat,biter_force_name,max_unit_count,valid_biters,force_name)
	local roll_type = unit_type_raffle[math_random(1, size_of_unit_type_raffle)]
	local boss_biter_force_name = biter_force_name .. "_boss"
	-- *1.5 because we add 50% health bonus as it's just one unit.
	-- *20 because one boss is equal of 20 biters in theory
	-- formula because 90% revive chance is 1/(1-0.9) = 10, which means biters needs to be killed 10 times, so *10 . easy fast-check : 50% revive is 2 biters worth, formula matches. 0% revive -> 1 biter worth
	local health_buff_equivalent_revive = 1.0/(1.0-global.reanim_chance[game.forces[biter_force_name].index]/100)
	if not isItnormalBiters then
		health_buff_equivalent_revive = health_buff_equivalent_revive * 20
	end
	local i = #valid_biters
	for _ = 1, maxLoopIteration, 1 do
		local unit_name = BiterRaffle.roll(roll_type, global.bb_evolution[biter_force_name])
		if isItnormalBiters and biter_threat < 0 then break end
		if not isItnormalBiters and biter_threat - threat_values[unit_name] * health_buff_equivalent_revive < 0 then break end -- Do not add a biter if it will make the threat goes negative when all the biters of wave were killed
		local position = spawner.surface.find_non_colliding_position(unit_name, spawner.position, 128, 2)
		if not position then break end
		local biter

		if isItnormalBiters then
			biter = spawner.surface.create_entity({name = unit_name, force = biter_force_name, position = position})
		else
			biter = spawner.surface.create_entity({name = unit_name, force = boss_biter_force_name, position = position})
		end
		if isItnormalBiters then
			biter_threat = biter_threat - threat_values[biter.name]
		else
			biter_threat = biter_threat - threat_values[biter.name] * health_buff_equivalent_revive
		end
		i = i + 1
		valid_biters[i] = biter
		if health_buff_equivalent_revive > 1 then
			BossUnit.add_high_health_unit(biter, health_buff_equivalent_revive, not isItnormalBiters)
		end

		--Announce New Spawn
		if(isItnormalBiters and global.biter_spawn_unseen[force_name][unit_name]) then
			game.print({"", "A ", unit_name:gsub("-", " "), " was spotted far away on ", Functions.team_name_with_color(force_name), "..."})
			global.biter_spawn_unseen[force_name][unit_name] = false
		end
		if(not isItnormalBiters and global.biter_spawn_unseen[boss_biter_force_name][unit_name]) then
			game.print({"", "A ", unit_name:gsub("-", " "), " boss was spotted far away on ", Functions.team_name_with_color(force_name), "..."})
			global.biter_spawn_unseen[boss_biter_force_name][unit_name] = false
		end
	end
end

local function on_entity_spawned(event)
	local entity = event.entity
	if not entity.valid then return end
	if entity.force.name == "north_biters" or entity.force.name == "south_biters" then
		local health_factor = 1 / (1 - global.reanim_chance[entity.force.index] / 100)
		if health_factor > 1 then
			BossUnit.add_high_health_unit(entity, health_factor, false)
		end
	end
end

Event.add(defines.events.on_entity_spawned, on_entity_spawned)

local function select_units_around_spawner(spawner, force_name)
	local biter_force_name = spawner.force.name

	local valid_biters = {}
	local i = 0

	-- Half threat goes to normal biters, half threat goes for bosses, to get half bosses and half normal biters
	local threat = global.bb_threat[biter_force_name] / 10
	local threat_for_normal_biters = threat

	local max_group_size_biters_force = global.max_group_size[biter_force_name]

	if max_group_size_biters_force ~= global.max_group_size_initial then
		threat_for_normal_biters = threat_for_normal_biters / 2
	end
	local threat_for_boss_biters = threat  / 2
	local max_unit_count = math.floor(global.bb_threat[biter_force_name] * 0.25) + math_random(6,12)
	if max_unit_count > max_group_size_biters_force then max_unit_count = max_group_size_biters_force end

	--Manual spawning of units
	spawn_biters(true,max_unit_count,spawner,threat_for_normal_biters,biter_force_name,max_unit_count,valid_biters,force_name)

	--Manual spawning of boss units
	if max_group_size_biters_force ~= global.max_group_size_initial then
		spawn_biters(false,math.ceil((global.max_group_size_initial - max_group_size_biters_force)/20),spawner,threat_for_boss_biters,biter_force_name,max_unit_count,valid_biters,force_name)
	end

	return valid_biters
end

local function get_unit_group_position(spawner)
	local p
	if spawner.force.name == "north_biters" then
		p = {x = spawner.position.x, y = spawner.position.y + 4}
	else
		p = {x = spawner.position.x, y = spawner.position.y - 4}
	end
	p = spawner.surface.find_non_colliding_position("electric-furnace", p, 256, 1)
	if not p then
		if global.bb_debug then game.print("No unit_group_position found for force " .. spawner.force.name) end
		return
	end
	return p
end

local function get_nearby_biter_nest(center, biter_force_name)
	local spawner = get_random_spawner(biter_force_name)
	if not spawner then return end
	local best_distance = (center.x - spawner.position.x) ^ 2 + (center.y - spawner.position.y) ^ 2

	for _ = 1, 16, 1 do
		local new_spawner = get_random_spawner(biter_force_name)
		local new_distance = (center.x - new_spawner.position.x) ^ 2 + (center.y - new_spawner.position.y) ^ 2
		if new_distance < best_distance then
			spawner = new_spawner
			best_distance = new_distance
		end
	end

	if not spawner then return end
	--print("Nearby biter nest found at x=" .. spawner.position.x .. " y=" .. spawner.position.y .. ".")
	return spawner
end

local function create_attack_group(surface, force_name, biter_force_name)
	local threat = global.bb_threat[biter_force_name]
	if threat <= 0 then return false end

	local target_position = AiTargets.get_random_target(force_name)
	if not target_position then
		print("No side target found for " .. force_name .. ".")
		return
	end

	local spawner = get_nearby_biter_nest(target_position, biter_force_name)
	if not spawner then
		print("No spawner found for " .. force_name .. ".")
		return
	end

	local unit_group_position = get_unit_group_position(spawner)
	if not unit_group_position then return end
	local units = select_units_around_spawner(spawner, force_name)
	if not units then return end
	local boss_force_name = biter_force_name .. "_boss"
	local unit_group = surface.create_unit_group({position = unit_group_position, force = biter_force_name})
	local unit_group_boss = surface.create_unit_group({position = unit_group_position, force = boss_force_name})
	for _, unit in pairs(units)
	do
		if unit.force.name == boss_force_name then
			unit_group_boss.add_member(unit)
		else
			unit_group.add_member(unit)
		end
	end
	local strike_position = AiStrikes.calculate_strike_position(unit_group, target_position)
	AiStrikes.initiate(unit_group, force_name, strike_position, target_position)
	AiStrikes.initiate(unit_group_boss, force_name, strike_position, target_position)
end

Public.pre_main_attack = function()
	local force_name = global.next_attack

	-- In headless benchmarking, there are no connected_players so we need a global to override this
	if not global.training_mode or (global.training_mode and (global.benchmark_mode or #game.forces[force_name].connected_players > 0))then
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

		create_attack_group(surface, force_name, biter_force_name)
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
	if Functions.get_ticks_since_game_start() < 7200 then return end
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
			Feeding.do_raw_feed(amount, "automation-science-pack", bf)
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
		Feeding.do_raw_feed(amount, "automation-science-pack", bf)
	end
end

--Biter Threat Value Subtraction
function Public.subtract_threat(entity)
	if not threat_values[entity.name] then return end
	local biter_not_boss_force = entity.force.name
	local is_boss = false
	local factor = 1
	if entity.force.name == 'south_biters_boss' then
		biter_not_boss_force = 'south_biters'
		is_boss = true
	elseif entity.force.name == 'north_biters_boss' then
		biter_not_boss_force = 'north_biters'
		is_boss = true
	end
	if is_boss == true then
		local health_buff_equivalent_revive = 1.0/(1.0-global.reanim_chance[game.forces[biter_not_boss_force].index]/100)
		factor = bb_config.health_multiplier_boss*health_buff_equivalent_revive
	end
	global.bb_threat[biter_not_boss_force] = global.bb_threat[biter_not_boss_force] - threat_values[entity.name] * factor
	return true
end

return Public
