local Public = {}
local BiterRaffle = require "maps.biter_battles_v2.biter_raffle"
local Functions = require "maps.biter_battles_v2.functions"
local bb_config = require "maps.biter_battles_v2.config"
local fifo = require "maps.biter_battles_v2.fifo"
local Tables = require "maps.biter_battles_v2.tables"
local math_random = math.random
local math_abs = math.abs

local vector_radius = 512
local attack_vectors = {}
attack_vectors.north = {}
attack_vectors.south = {}
--awesomepatrol's pathing  updates
for p = 0.3, 0.71, 0.1 do
	local a = math.pi * p
	local x = vector_radius * math.cos(a)
	local y = vector_radius * math.sin(a)
	attack_vectors.north[#attack_vectors.north + 1] = {x, y * -1}
	attack_vectors.south[#attack_vectors.south + 1] = {x, y}
end
local size_of_vectors = #attack_vectors.north

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

local function get_target_entity(force_name)
	local force_index = game.forces[force_name].index
	local target_entity = Functions.get_random_target_entity(force_index)
	if not target_entity then print("Unable to get target entity for " .. force_name .. ".") return end
	for _ = 1, 2, 1 do
		local e = Functions.get_random_target_entity(force_index)
		if math_abs(e.position.x) < math_abs(target_entity.position.x) then
			target_entity = e
		end
	end
	if not target_entity then print("Unable to get target entity for " .. force_name .. ".") return end
	--print("Target entity for " .. force_name .. ": " .. target_entity.name .. " at x=" .. target_entity.position.x .. " y=" .. target_entity.position.y)
	return target_entity
end

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

local function is_biter_inactive(biter, unit_number, biter_force_name)
	if not biter.entity then
		if global.bb_debug then print("BiterBattles: active unit " .. unit_number .. " removed, possibly died.") end
		return true
	end
	if not biter.entity.valid then
		if global.bb_debug then print("BiterBattles: active unit " .. unit_number .. " removed, biter invalid.") end
		return true
	end
	if not biter.entity.unit_group then
		if global.bb_debug then print("BiterBattles: active unit " .. unit_number .. "  at x" .. biter.entity.position.x .. " y" .. biter.entity.position.y .. " removed, had no unit group.") end
		return true
	end
	if not biter.entity.unit_group.valid then
		if global.bb_debug then print("BiterBattles: active unit " .. unit_number .. " removed, unit group invalid.") end
		return true
	end
	if game.tick - biter.active_since > bb_config.biter_timeout then
		if global.bb_debug then print("BiterBattles: " .. biter_force_name .. " unit " .. unit_number .. " timed out at tick age " .. game.tick - biter.active_since .. ".") end
		biter.entity.destroy()
		return true
	end
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

local function select_units_around_spawner(spawner, force_name, side_target)
	local biter_force_name = spawner.force.name

	local valid_biters = {}
	local i = 0

	local threat = global.bb_threat[biter_force_name] / 10

	local unit_count = 0
	local max_unit_count = math.floor(global.bb_threat[biter_force_name] * 0.25) + math_random(6,12)
	if max_unit_count > bb_config.max_group_size then max_unit_count = bb_config.max_group_size end

	--Collect biters around spawners
	if math_random(1, 2) == 1 then
		local biters = spawner.surface.find_enemy_units(spawner.position, 96, force_name)
		if biters[1] then
			for _, biter in pairs(biters) do
				if unit_count >= max_unit_count then break end
				if biter.force.name == biter_force_name then
					i = i + 1
					valid_biters[i] = biter
					unit_count = unit_count + 1
					threat = threat - threat_values[biter.name]
				end
				if threat < 0 then break end
			end
		end
	end

	--Manual spawning of units
	local roll_type = unit_type_raffle[math_random(1, size_of_unit_type_raffle)]
	for _ = 1, max_unit_count - unit_count, 1 do
		if threat < 0 then break end
		local unit_name = BiterRaffle.roll(roll_type, global.bb_evolution[biter_force_name])
		local position = spawner.surface.find_non_colliding_position(unit_name, spawner.position, 128, 2)
		if not position then break end
		local biter = spawner.surface.create_entity({name = unit_name, force = biter_force_name, position = position})
		threat = threat - threat_values[biter.name]
		i = i + 1
		valid_biters[i] = biter
		--Announce New Spawn
		if(global.biter_spawn_unseen[force_name][unit_name]) then
			game.print("A " .. unit_name:gsub("-", " ") .. " was spotted far away on team " .. force_name .. "...")
			global.biter_spawn_unseen[force_name][unit_name] = false
		end
	end

	if global.bb_debug then game.print(get_active_biter_count(biter_force_name) .. " active units for " .. biter_force_name) end

	return valid_biters
end

local function send_group(unit_group, force_name, side_target)
	local target
	if side_target then
		target = side_target
	else
		target = get_target_entity(force_name)
	end
	if not target then print("No target for " .. force_name .. " biters.") return end

	target = target.position

	local commands = {}
	local vector = attack_vectors[force_name][math_random(1, size_of_vectors)]
	local distance_modifier = math_random(25, 100) * 0.01

	local position = {target.x + (vector[1] * distance_modifier), target.y + (vector[2] * distance_modifier)}
	position = unit_group.surface.find_non_colliding_position("stone-furnace", position, 96, 1)
	if position then
		if math.abs(position.y) < math.abs(unit_group.position.y) then
			commands[#commands + 1] = {
				type = defines.command.go_to_location,
				destination = position,
				radius = 32,
				distraction = defines.distraction.by_enemy
			}
		end
	end

	commands[#commands + 1] = {
		type = defines.command.attack_area,
		destination = target,
		radius = 32,
		distraction = defines.distraction.by_enemy
	}

	commands[#commands + 1] = {
		type = defines.command.attack,
		target = global.rocket_silo[force_name],
		distraction = defines.distraction.by_damage
	}

	unit_group.set_command({
		type = defines.command.compound,
		structure_type = defines.compound_command.logical_and,
		commands = commands
	})
	return true
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
		if global.bb_debug then game.print("No unit_group_position found for team " .. spawner.force.name) end
		return
	end
	return p
end

local function get_nearby_biter_nest(target_entity)
	local center = target_entity.position
	local biter_force_name = target_entity.force.name .. "_biters"
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

	local side_target = get_target_entity(force_name)
	if not side_target then
		print("No side target found for " .. force_name .. ".")
		return
	end

	local spawner = get_nearby_biter_nest(side_target)
	if not spawner then
		print("No spawner found for " .. force_name .. ".")
		return
	end

	local unit_group_position = get_unit_group_position(spawner)
	if not unit_group_position then return end

	local units = select_units_around_spawner(spawner, force_name, side_target)
	if not units then return end

	local unit_group = surface.create_unit_group({position = unit_group_position, force = biter_force_name})
	for _, unit in pairs(units) do unit_group.add_member(unit) end

	send_group(unit_group, force_name, side_target)
end

Public.pre_main_attack = function()
	local surface = game.surfaces[global.bb_surface_name]
	local force_name = global.next_attack

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

--By Maksiu1000 skip the last two tech
Public.unlock_satellite = function(event)
    -- Skip unrelated events
    if event.research.name ~= 'speed-module-3' then
        return
    end
    local force = event.research.force
    if not force.technologies['rocket-silo'].researched then
        force.technologies['rocket-silo'].researched=true
        force.technologies['space-science-pack'].researched=true
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

--Biter Threat Value Subtraction
function Public.subtract_threat(entity)
	if not threat_values[entity.name] then return end

	global.bb_threat[entity.force.name] = global.bb_threat[entity.force.name] - threat_values[entity.name]

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
		idx = math.random(idx - 1, idx)
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
	for force, id in pairs(global.dead_units) do
		-- Check for each side if there are any biters to reanimate.
		if fifo.empty(id) then
			goto reanim_units_cont
		end

		-- Balance amount of unit creation requests to get rid off
		-- excess stored in memory.
		local cycles = fifo.length(id) / global.reanim_balancer
		cycles = math.floor(cycles) + 1
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

	local reanimate = math.random(1, 100) <= chance
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
