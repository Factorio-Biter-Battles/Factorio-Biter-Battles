--BITER BATTLES CONFIG--

local bb_config = {
	--Optional custom team names, can also be modified via "Team Manager"
	["north_side_team_name"] = "Team North",
	["south_side_team_name"] = "Team South",

	--TERRAIN OPTIONS--
	["border_river_width"] = 44,						--Approximate width of the horizontal impassable river separating the teams. (values up to 100)
	["builders_area"] = true,							--Grant each side a peaceful direction with no nests and biters?
	["random_scrap"] = true,							--Generate harvestable scrap around worms randomly?

	--BITER SETTINGS--
	["max_group_size"] = 300,							--Maximum unit group size.
	["biter_timeout"] = 162000,						--Time it takes in ticks for an attacking unit to be deleted. This prevents permanent stuck units.
	["bitera_area_distance"] = 512					--Distance to the biter area.
}

return bb_config
