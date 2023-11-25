local Public = {}

-- List of forces that will be affected by ammo modifier
Public.ammo_modified_forces_list = {"north", "south", "spectator"}

-- Ammo modifiers via set_ammo_damage_modifier
-- [ammo_category] = value
-- ammo_modifier_dmg = base_damage * base_ammo_modifiers
-- damage = base_damage + ammo_modifier_dmg
Public.base_ammo_modifiers = {
	["bullet"] = 0.16,
	["shotgun-shell"] = 1,
	["flamethrower"] = -0.6,
	["landmine"] = -0.9
}

-- turret attack modifier via set_turret_attack_modifier
Public.base_turret_attack_modifiers = {
	["flamethrower-turret"] = -0.8,
	["laser-turret"] = 0.0
}

Public.upgrade_modifiers = {
	["flamethrower"] = 0.02,
	["flamethrower-turret"] = 0.02,
	["laser-turret"] = 0.3,
	["shotgun-shell"] = 0.6,
	["grenade"] = 0.48,
	["landmine"] = 0.04
}

Public.food_values = {
	["automation-science-pack"] =		{value = 0.0009, name = "automation science", color = "255, 50, 50"},
	["logistic-science-pack"] =		{value = 0.0023, name = "logistic science", color = "50, 255, 50"},
	["military-science-pack"] =		{value = 0.0095, name = "military science", color = "105, 105, 105"},
	["chemical-science-pack"] = 		{value = 0.0250, name = "chemical science", color = "100, 200, 255"},
	["production-science-pack"] =		{value = 0.1050, name = "production science", color = "150, 25, 255"},
	["utility-science-pack"] =		{value = 0.1600, name = "utility science", color = "210, 210, 60"},
	["space-science-pack"] = 		{value = 0.5000, name = "space science", color = "255, 255, 255"},
}

Public.gui_foods = {}
for k, v in pairs(Public.food_values) do
	Public.gui_foods[k] = math.floor(v.value * 10000) .. " Mutagen strength"
end
Public.gui_foods["raw-fish"] = "Send a fish to spy for 45 seconds.\nLeft Mouse Button: Send one fish.\nRMB: Sends 5 fish.\nShift+LMB: Send all fish.\nShift+RMB: Send half of all fish."

Public.force_translation = {
	["south_biters"] = "south",
	["north_biters"] = "north"
}

Public.enemy_team_of = {
	["north"] = "south",
	["south"] = "north"
}

Public.wait_messages = {
	"Once upon a dreary night...",
	"Nevermore.",
	"go and grab a drink.",
	"take a short healthy break.",
	"go and stretch your legs.",
	"please pet the cat.",
	"time to get a bowl of snacks :3",
}

Public.food_names = {
	["automation-science-pack"] = true,
	["logistic-science-pack"] = true,
	["military-science-pack"] = true,
	["chemical-science-pack"] = true,
	["production-science-pack"] = true,
	["utility-science-pack"] = true,
	["space-science-pack"] = true
}

Public.food_long_and_short = {
	[1] = {short_name= "automation", long_name = "automation-science-pack"},
	[2] = {short_name= "logistic", long_name = "logistic-science-pack"},
	[3] = {short_name= "military", long_name = "military-science-pack"},
	[4] = {short_name= "chemical", long_name = "chemical-science-pack"},
	[5] = {short_name= "production", long_name = "production-science-pack"},
	[6] = {short_name= "utility", long_name = "utility-science-pack"},
	[7] = {short_name= "space", long_name = "space-science-pack"}
}

Public.food_long_to_short = {
	["automation-science-pack"] = {short_name= "automation", indexScience = 1},
	["logistic-science-pack"] = {short_name= "logistic", indexScience = 2},
	["military-science-pack"] = {short_name= "military", indexScience = 3},
	["chemical-science-pack"] = {short_name= "chemical", indexScience = 4},
	["production-science-pack"] = {short_name= "production", indexScience = 5},
	["utility-science-pack"] = {short_name= "utility", indexScience = 6},
	["space-science-pack"] = {short_name= "space", indexScience = 7}
}

-- This array contains parameters for spawn area ore patches.
-- These are non-standard units and they do not map to values used in factorio
-- map generation. They are only used internally by scenario logic.
Public.spawn_ore = {
	-- Value "size" is a parameter used as coefficient for simplex noise
	-- function that is applied to shape of an ore patch. You can think of it
	-- as size of a patch on average. Recomended range is from 1 up to 50.

	-- Value "density" controls the amount of resource in a single tile.
	-- The center of an ore patch contains specified amount and is decreased
	-- proportionally to distance from center of the patch.

	-- Value "big_patches" and "small_patches" represents a number of an ore
	-- patches of given type. The "density" is applied with the same rule
	-- regardless of the patch size.
	["iron-ore"] = {
		size = 23,
		density = 3500,
		big_patches = 2,
		small_patches = 1
	},
	["copper-ore"] = {
		size = 21,
		density = 3000,
		big_patches = 1,
		small_patches = 2
	},
	["coal"] = {
		size = 22,
		density = 2500,
		big_patches = 1,
		small_patches = 1
	},
	["stone"] = {
		size = 20,
		density = 2000,
		big_patches = 1,
		small_patches = 0
	}
}

Public.difficulties = {
	
	[1] = {name = "I'm Too Young to Die", str = "25%", value = 0.25, color = {r=0.00, g=0.45, b=0.00}, print_color = {r=0.00, g=0.9, b=0.00}},
	[2] = {name = "Piece of Cake", str = "50%", value = 0.5, color = {r=0.00, g=0.35, b=0.00}, print_color = {r=0.00, g=0.7, b=0.00}},
	[3] = {name = "Easy", str = "75%", value = 0.75, color = {r=0.00, g=0.25, b=0.00}, print_color = {r=0.00, g=0.5, b=0.00}},
	[4] = {name = "Normal", str = "100%", value = 1, color = {r=0.00, g=0.00, b=0.25}, print_color = {r=0.0, g=0.0, b=0.7}},
	[5] = {name = "Hard", str = "150%", value = 1.5, color = {r=0.25, g=0.00, b=0.00}, print_color = {r=0.5, g=0.0, b=0.00}},
	[6] = {name = "Nightmare", str = "300%", value = 3, color = {r=0.35, g=0.00, b=0.00}, print_color = {r=0.7, g=0.0, b=0.00}},
	[7] = {name = "Fun and Fast", str = "500%", value = 5, color = {r=0.55, g=0.00, b=0.00}, print_color = {r=0.9, g=0.0, b=0.00}}
}

Public.forces_list = { "all teams", "north", "south" }
Public.science_list = { "all science", "very high tier (space, utility, production)", "high tier (space, utility, production, chemical)", "mid+ tier (space, utility, production, chemical, military)","space","utility","production","chemical","military", "logistic", "automation" }
Public.evofilter_list = { "all evo jump", "no 0 evo jump", "10+ only","5+ only","4+ only","3+ only","2+ only","1+ only" }
Public.food_value_table_version = { Public.food_values["automation-science-pack"].value, Public.food_values["logistic-science-pack"].value, Public.food_values["military-science-pack"].value, Public.food_values["chemical-science-pack"].value, Public.food_values["production-science-pack"].value, Public.food_values["utility-science-pack"].value, Public.food_values["space-science-pack"].value}

return Public
