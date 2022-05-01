local Public = {}
local math_random = math.random
local math_floor = math.floor
local Tables = require "maps.biter_battles_v2.tables"

local function linear_biter_function(x, slope, x_intercept)
	-- x_intercept == evo when this biter starts appearing
	-- (or dissapearing for small-biters)
	return slope *(x - x_intercept)
end


local function get_raffle_table(level, name)
	local medium_thr = Tables.biter_mutagen_thresholds["medium"]
	local big_thr = Tables.biter_mutagen_thresholds["big"]
	local behemoth_thr = Tables.biter_mutagen_thresholds["behemoth"]

	local small_biter_name = "small-" .. name
	local medium_biter_name = "medium-" .. name
	local big_biter_name = "big-" .. name
	local behemoth_biter_name = "behemoth-" .. name

	-- As an example of what's going on here:
	-- 'probabilility in this case is the current biters value / total value of all the biters 'probability' summed'
	-- Small biters probability starts at 1000 and goes down linearly at a slope of 'biter_mutagen_initial_slopes'
	-- Medium biters probability starts at -166.66 (anything below 0 is 0), and then once it hits 166.66 (or 16.6% in game)
	--       Medium biters start happening.
	local raffle = {
		[small_biter_name] = linear_biter_function(level, Tables.biter_mutagen_initial_slopes["small"], -1000/Tables.biter_mutagen_initial_slopes["small"]),
		[medium_biter_name] = linear_biter_function(level, Tables.biter_mutagen_initial_slopes["medium"], medium_thr),
		[big_biter_name] = 0,
		[behemoth_biter_name] = 0,
	}

	if level > big_thr then
		raffle[medium_biter_name] = big_thr - (level - big_thr)
		raffle[big_biter_name] = linear_biter_function(level, Tables.biter_mutagen_initial_slopes["big"], big_thr)
	end

	if level > behemoth_thr then
		raffle[behemoth_biter_name] = linear_biter_function(level, Tables.biter_mutagen_initial_slopes["behemoth"], big_thr)
	end

	for k, _ in pairs(raffle) do
		if raffle[k] < 0 then raffle[k] = 0 end
	end
	return raffle
end


local function roll(evolution_factor, name)
	local raffle = get_raffle_table(math_floor(evolution_factor * 1000), name)
	local max_chance = 0
	for _, v in pairs(raffle) do
		max_chance = max_chance + v
	end
	local r = math_random(0, math_floor(max_chance))	
	local current_chance = 0
	for k, v in pairs(raffle) do
		current_chance = current_chance + v
		if r <= current_chance then return k end
	end
end

local function get_biter_name(evolution_factor)
	return roll(evolution_factor, "biter")
end

local function get_spitter_name(evolution_factor)	
	return roll(evolution_factor, "spitter")	
end

local function get_worm_raffle_table(level)
	local raffle = {
		["small-worm-turret"] = 1000 - level * 1.75,		
		["medium-worm-turret"] = level,		
		["big-worm-turret"] = 0,		
		["behemoth-worm-turret"] = 0,
	}
	
	if level > 500 then
		raffle["medium-worm-turret"] = 500 - (level - 500)
		raffle["big-worm-turret"] = (level - 500) * 2
	end
	if level > 900 then
		raffle["behemoth-worm-turret"] = (level - 900) * 3
	end
	for k, _ in pairs(raffle) do
		if raffle[k] < 0 then raffle[k] = 0 end
	end
	return raffle
end

local function get_worm_name(evolution_factor)
	local raffle = get_worm_raffle_table(math_floor(evolution_factor * 1000))
	local max_chance = 0
	for _, v in pairs(raffle) do
		max_chance = max_chance + v
	end
	local r = math_random(0, math_floor(max_chance))	
	local current_chance = 0
	for k, v in pairs(raffle) do
		current_chance = current_chance + v
		if r <= current_chance then return k end
	end
end

local function get_unit_name(evolution_factor)
	if math_random(1, 3) == 1 then
		return get_spitter_name(evolution_factor)
	else
		return get_biter_name(evolution_factor)
	end
end

local type_functions = {
	["spitter"] = get_spitter_name,
	["biter"] = get_biter_name,
	["mixed"] = get_unit_name,
	["worm"] = get_worm_name,
}

function Public.roll(entity_type, evolution_factor)
	if not entity_type then return end
	if not type_functions[entity_type] then return end
	local evo = evolution_factor
	if not evo then evo = game.forces.enemy.evolution_factor end
	return type_functions[entity_type](evo)
end

return Public
