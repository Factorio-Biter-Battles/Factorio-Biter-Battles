local Terrain = require "maps.biter_battles_v2.terrain"
local Force_health_booster = require "modules.force_health_booster"
local Score = require "comfy_panel.score"
local Tables = require "maps.biter_battles_v2.tables"

local Public = {}

function Public.initial_setup()
	game.map_settings.enemy_evolution.time_factor = 0
	game.map_settings.enemy_evolution.destroy_factor = 0
	game.map_settings.enemy_evolution.pollution_factor = 0
	game.map_settings.pollution.enabled = false
	game.map_settings.enemy_expansion.enabled = false

	game.create_force("north")
	game.create_force("south")
	game.create_force("north_biters")
	game.create_force("south_biters")
	game.create_force("spectator")

	game.forces.spectator.research_all_technologies()

	game.permissions.get_group("Default").set_allows_action(defines.input_action.open_blueprint_library_gui, false)
	game.permissions.get_group("Default").set_allows_action(defines.input_action.import_blueprint_string, false)

	local p = game.permissions.create_group("spectator")
	for action_name, _ in pairs(defines.input_action) do
		p.set_allows_action(defines.input_action[action_name], false)
	end

	local defs = {
		defines.input_action.activate_copy,
		defines.input_action.activate_cut,
		defines.input_action.activate_paste,
		defines.input_action.change_active_quick_bar,
		defines.input_action.clear_cursor,
		defines.input_action.edit_permission_group,
		defines.input_action.gui_click,
		defines.input_action.gui_confirmed,
		defines.input_action.gui_elem_changed,
		defines.input_action.gui_location_changed,
		defines.input_action.gui_selected_tab_changed,
		defines.input_action.gui_selection_state_changed,
		defines.input_action.gui_switch_state_changed,
		defines.input_action.gui_text_changed,
		defines.input_action.gui_value_changed,
		defines.input_action.open_character_gui,
		defines.input_action.open_kills_gui,
		defines.input_action.quick_bar_set_selected_page,
		defines.input_action.quick_bar_set_slot,
		defines.input_action.rotate_entity,
		defines.input_action.set_filter,
		defines.input_action.set_player_color,
		defines.input_action.start_walking,
		defines.input_action.toggle_show_entity_info,
		defines.input_action.write_to_console,
	}
	for _, d in pairs(defs) do p.set_allows_action(d, true) end

	global.gui_refresh_delay = 0
	global.game_lobby_active = true
	global.bb_debug = false
	global.bb_settings = {
		--TEAM SETTINGS--
		["team_balancing"] = true,			--Should players only be able to join a team that has less or equal members than the opposing team?
		["only_admins_vote"] = false,		--Are only admins able to vote on the global difficulty?
	}

	--Disable Nauvis
	local surface = game.surfaces[1]
	local map_gen_settings = surface.map_gen_settings
	map_gen_settings.height = 3
	map_gen_settings.width = 3
	surface.map_gen_settings = map_gen_settings
	for chunk in surface.get_chunks() do
		surface.delete_chunk({chunk.x, chunk.y})
	end

	--Playground Surface
	local map_gen_settings = {
		["water"] = 0,
		["starting_area"] = 1,
		["cliff_settings"] = {cliff_elevation_interval = 0, cliff_elevation_0 = 0},
		["default_enable_all_autoplace_controls"] = false,
		["autoplace_settings"] = {
			["entity"] = {treat_missing_as_default = false},
			["tile"] = {treat_missing_as_default = false},
			["decorative"] = {treat_missing_as_default = false},
		},
		autoplace_controls = {
			["coal"] = {frequency = 0, size = 0, richness = 0},
			["stone"] = {frequency = 0, size = 0, richness = 0},
			["copper-ore"] = {frequency = 0, size = 0, richness = 0},
			["iron-ore"] = {frequency = 0, size = 0, richness = 0},
			["uranium-ore"] = {frequency = 0, size = 0, richness = 0},
			["crude-oil"] = {frequency = 0, size = 0, richness = 0},
			["trees"] = {frequency = 0, size = 0, richness = 0},
			["enemy-base"] = {frequency = 0, size = 0, richness = 0}
		},
	}
	local surface = game.create_surface("biter_battles", map_gen_settings)
end

--Terrain Source Surface
function Public.source_surface()
	local map_gen_settings = {}
	map_gen_settings.seed = math.random(1, 99999999)
	map_gen_settings.water = math.random(15, 65) * 0.01
	map_gen_settings.starting_area = 2.5
	map_gen_settings.terrain_segmentation = math.random(30, 40) * 0.1
	map_gen_settings.cliff_settings = {cliff_elevation_interval = 0, cliff_elevation_0 = 0}
	map_gen_settings.autoplace_controls = {
		["coal"] = {frequency = 6.5, size = 0.34, richness = 0.24},
		["stone"] = {frequency = 5, size = 0.28, richness = 0.25},
		["copper-ore"] = {frequency = 6, size = 0.28, richness = 0.3},
		["iron-ore"] = {frequency = 8.5, size = 0.8, richness = 0.23},
		["uranium-ore"] = {frequency = 2, size = 1, richness = 1},
		["crude-oil"] = {frequency = 8, size = 1.4, richness = 0.45},
		["trees"] = {frequency = math.random(8, 28) * 0.1, size = math.random(6, 14) * 0.1, richness = math.random(2, 4) * 0.1},
		["enemy-base"] = {frequency = 0, size = 0, richness = 0}
	}
	local surface = game.create_surface("bb_source", map_gen_settings)
	surface.request_to_generate_chunks({x = 0, y = -256}, 8)
	surface.force_generate_chunk_requests()

	Terrain.draw_spawn_area(surface)
	Terrain.generate_additional_spawn_ore(surface)
	Terrain.generate_additional_rocks(surface)
	Terrain.generate_silo(surface)
	Terrain.draw_spawn_circle(surface)
	--Terrain.generate_spawn_goodies(surface)
end

function Public.tables()
	local get_score = Score.get_table()
	Force_health_booster.reset_tables()
	get_score.score_table = {}
	global.science_logs_text = nil
	global.science_logs_total_north = nil
	global.science_logs_total_south = nil
	global.active_biters = {}
	global.bb_evolution = {}
	global.bb_game_won_by_team = nil
	global.bb_threat = {}
	global.bb_threat_income = {}
	global.chosen_team = {}
	global.combat_balance = {}
	global.difficulty_player_votes = {}
	global.evo_raise_counter = 1
	global.force_area = {}
	global.main_attack_wave_amount = 0
	global.map_pregen_message_counter = {}
	global.rocket_silo = {}
	global.spectator_rejoin_delay = {}
	global.spy_fish_timeout = {}
	global.target_entities = {}
	global.terrain_gen = {}
	global.terrain_gen.chunk_copy = {}
	global.terrain_gen.chunk_mirror = {}
	global.terrain_gen.counter = 0
	global.terrain_gen.size_of_chunk_copy = 0
	global.terrain_gen.size_of_chunk_mirror = 0
	global.tm_custom_name = {}
	global.total_passive_feed_redpotion = 0
	global.unit_groups = {}
	global.unit_spawners = {}
	global.unit_spawners.north_biters = {}
	global.unit_spawners.south_biters = {}
	global.biter_spawn_unseen = {
		["north"] = {
			["medium-spitter"] = true, ["medium-biter"] = true, ["big-spitter"] = true, ["big-biter"] = true, ["behemoth-spitter"] = true, ["behemoth-biter"] = true
		},
		["south"] = {
			["medium-spitter"] = true, ["medium-biter"] = true, ["big-spitter"] = true, ["big-biter"] = true, ["behemoth-spitter"] = true, ["behemoth-biter"] = true
		}
	}
	global.difficulty_votes_timeout = 36000
	    -- [difficulty] = {[inc_start_time_in_minutes] = difficulty_in_percent}
    global.difficulty_increases = {
        [1] = {[0] = 0.25, [30] = 0.25, [60] = 0.50, [90] = 0.50, [120] = 1.00, [180] = 1.20, [240] = 1.40, [300] = 1.40, [360] = 1.40, [420] = 1.40, [480] = 1.40},
        [2] = {[0] = 0.50, [30] = 0.50, [60] = 0.50, [90] = 0.75, [120] = 1.00, [180] = 1.10, [240] = 1.20, [300] = 1.20, [360] = 1.30, [420] = 1.30, [480] = 1.30},
        [3] = {[0] = 0.75, [30] = 0.75, [60] = 0.75, [90] = 0.75, [120] = 1.00, [180] = 1.05, [240] = 1.10, [300] = 1.15, [360] = 1.20, [420] = 1.20, [480] = 1.20},
        [4] = {[0] = 1.00, [30] = 1.00, [60] = 1.00, [90] = 1.00, [120] = 1.00, [180] = 1.00, [240] = 1.00, [300] = 1.00, [360] = 1.00, [420] = 1.00, [480] = 1.00},
        [5] = {[0] = 1.25, [30] = 1.25, [60] = 1.50, [90] = 1.50, [120] = 1.50, [180] = 1.50, [240] = 1.50, [300] = 1.50, [360] = 1.50, [420] = 1.50, [480] = 1.50},
        [6] = {[0] = 1.50, [30] = 1.50, [60] = 1.75, [90] = 2.00, [120] = 2.00, [180] = 2.00, [240] = 2.00, [300] = 2.00, [360] = 2.00, [420] = 2.00, [480] = 2.00},
        [7] = {[0] = 2.00, [30] = 2.00, [60] = 2.50, [90] = 3.00, [120] = 3.00, [180] = 3.00, [240] = 3.00, [300] = 3.00, [360] = 3.00, [420] = 3.00, [480] = 3.00},
        [8] = {[0] = 3.00, [30] = 3.50, [60] = 4.00, [90] = 4.50, [120] = 5.00, [180] = 5.00, [240] = 5.00, [300] = 5.00, [360] = 5.00, [420] = 5.00, [480] = 5.00}
    }
	global.next_attack = "north"
	if math.random(1,2) == 1 then global.next_attack = "south" end
end

function Public.load_spawn()
	local surface = game.surfaces["biter_battles"]
	surface.request_to_generate_chunks({x = 0, y = 0}, 1)
	surface.force_generate_chunk_requests()

	surface.request_to_generate_chunks({x = 0, y = 0}, 2)
	surface.force_generate_chunk_requests()

	for y = 0, 576, 32 do
		surface.request_to_generate_chunks({x = 80, y = y + 16}, 0)
		surface.request_to_generate_chunks({x = 48, y = y + 16}, 0)
		surface.request_to_generate_chunks({x = 16, y = y + 16}, 0)
		surface.request_to_generate_chunks({x = -16, y = y - 16}, 0)
		surface.request_to_generate_chunks({x = -48, y = y - 16}, 0)
		surface.request_to_generate_chunks({x = -80, y = y - 16}, 0)

		surface.request_to_generate_chunks({x = 80, y = y * -1 + 16}, 0)
		surface.request_to_generate_chunks({x = 48, y = y * -1 + 16}, 0)
		surface.request_to_generate_chunks({x = 16, y = y * -1 + 16}, 0)
		surface.request_to_generate_chunks({x = -16, y = y * -1 - 16}, 0)
		surface.request_to_generate_chunks({x = -48, y = y * -1 - 16}, 0)
		surface.request_to_generate_chunks({x = -80, y = y * -1 - 16}, 0)
	end
end

function Public.forces()
	for _, force in pairs(game.forces) do
		if force.name ~= "spectator" then
			force.reset()
			force.reset_evolution()
		end
	end

	local surface = game.surfaces["biter_battles"]

	local f = game.forces["north"]
	f.set_spawn_position({0, -44}, surface)
	f.set_cease_fire('player', true)
	f.set_friend("spectator", true)
	f.set_friend("south_biters", true)
	f.share_chart = true

	local f = game.forces["south"]
	f.set_spawn_position({0, 44}, surface)
	f.set_cease_fire('player', true)
	f.set_friend("spectator", true)
	f.set_friend("north_biters", true)
	f.share_chart = true

	local f = game.forces["north_biters"]
	f.set_friend("south_biters", true)
	f.set_friend("south", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false

	local f = game.forces["south_biters"]
	f.set_friend("north_biters", true)
	f.set_friend("north", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false

	local f = game.forces["spectator"]
	f.set_spawn_position({0,0},surface)
	f.technologies["toolbelt"].researched = true
	f.set_cease_fire("north_biters", true)
	f.set_cease_fire("south_biters", true)
	f.set_friend("north", true)
	f.set_friend("south", true)
	f.set_cease_fire("player", true)
	f.share_chart = true

	local f = game.forces["player"]
	f.set_spawn_position({0,0},surface)
	f.set_cease_fire('spectator', true)
	f.set_cease_fire("north_biters", true)
	f.set_cease_fire("south_biters", true)
	f.set_cease_fire('north', true)
	f.set_cease_fire('south', true)
	f.share_chart = false

	for _, force in pairs(game.forces) do
		game.forces[force.name].technologies["artillery"].enabled = false
		game.forces[force.name].technologies["artillery-shell-range-1"].enabled = false
		game.forces[force.name].technologies["artillery-shell-speed-1"].enabled = false
		game.forces[force.name].technologies["atomic-bomb"].enabled = false
		game.forces[force.name].technologies["stronger-explosive-4"].enabled = false
		game.forces[force.name].technologies["stronger-explosive-5"].enabled = false
		game.forces[force.name].technologies["stronger-explosive-6"].enabled = false
		game.forces[force.name].technologies["stronger-explosive-7"].enabled = false
		game.forces[force.name].technologies["refined-flammables-4"].enabled = false
		game.forces[force.name].technologies["refined-flammables-5"].enabled = false
		game.forces[force.name].technologies["refined-flammables-6"].enabled = false
		game.forces[force.name].technologies["refined-flammables-7"].enabled = false
		game.forces[force.name].technologies["physical-projectile-damage-6"].enabled = false
		game.forces[force.name].technologies["cliff-explosives"].enabled = false
		game.forces[force.name].research_queue_enabled = true
		global.target_entities[force.index] = {}
		global.spy_fish_timeout[force.name] = 0
		global.active_biters[force.name] = {}
		global.bb_evolution[force.name] = 0
		global.bb_threat_income[force.name] = 0
		global.bb_threat[force.name] = 0
	end
	for _, force in pairs(Tables.ammo_modified_forces_list) do
		for ammo_category, value in pairs(Tables.base_ammo_modifiers) do
			game.forces[force]
				.set_ammo_damage_modifier(ammo_category, value)
		end
	end

	for _, force in pairs(Tables.ammo_modified_forces_list) do
		for turret_category, value in pairs(Tables.base_turret_attack_modifiers) do
			game.forces[force]
				.set_turret_attack_modifier(turret_category, value)
		end
	end

end

return Public
