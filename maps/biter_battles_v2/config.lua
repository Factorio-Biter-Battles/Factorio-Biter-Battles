--BITER BATTLES CONFIG--

local bb_config = {
    --Optional custom team names, can also be modified via "Team Manager"
    ['north_side_team_name'] = 'Team North',
    ['south_side_team_name'] = 'Team South',

    --TERRAIN OPTIONS--
    ['border_river_width'] = 44, --Approximate width of the horizontal impassable river separating the teams. (values up to 64)

    --BITER SETTINGS--
    ['bitera_area_distance'] = 512, --Distance to the biter area.
    ['biter_area_slope'] = 0.45, -- Slope of the biter area. For example, 0 - an area parallel to the river, 1 - at an angle of 45° to the river

    ['health_multiplier_boss'] = 20 * 1.3, --Health multiplier for boss biters
    ['threat_scale_factor_past_evo100'] = 3, --Threat scale factor past 100% evo
}

return bb_config
