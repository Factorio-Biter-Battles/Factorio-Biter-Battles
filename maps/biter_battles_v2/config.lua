--BITER BATTLES CONFIG--

local bb_config = {
	--Optional custom team names, can also be modified via "Team Manager"
	["north_side_team_name"] = "Team North",
	["south_side_team_name"] = "Team South",

	--TERRAIN OPTIONS--
	["border_river_width"] = 46,						--Approximate width of the horizontal impassable river separating the teams. (values up to 64)
	["builders_area"] = true,							--Grant each side a peaceful direction with no nests and biters?
	["random_scrap"] = true,							--Generate harvestable scrap around worms randomly?

	--BITER SETTINGS--
	["biter_timeout"] = 162000,						--Time it takes in ticks for an attacking unit to be deleted. This prevents permanent stuck units.
	["bitera_area_distance"] = 512,					--Distance to the biter area.

	["max_group_evo1"] = 200,						--Limit of unit group size for biters depending on evo.
	["max_group_evo2"] = 100,						--Limit of unit group size for biters depending on evo.
	["max_group_evo3"] = 75,						--Limit of unit group size for biters depending on evo.
	["max_group_evo4"] = 50,						--Limit of unit group size for biters depending on evo.
	["health_multiplier_boss"] = 20*1.3				--Health multiplier for boss biters
}

return bb_config
