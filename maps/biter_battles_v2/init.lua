local Terrain = require "maps.biter_battles_v2.terrain"
local Score = require "comfy_panel.score"
local Tables = require "maps.biter_battles_v2.tables"
local fifo = require "maps.biter_battles_v2.fifo"
local Blueprint = require 'maps.biter_battles_v2.blueprints'

local Public = {}

local function createTrollSong(forceName,offset)
	local bp_string = Blueprint.get_blueprint("jail_song")
	local jailSurface = game.surfaces['gulag']
	local bp_entity = jailSurface.create_entity{name = 'item-on-ground', position= offset, stack = 'blueprint'}
	bp_entity.stack.import_stack(bp_string)
	local bp_entities = bp_entity.stack.get_blueprint_entities()
	local bpInfo = {surface = jailSurface, force = forceName, position = offset, force_build = 'true'}
	local bpResult = bp_entity.stack.build_blueprint(bpInfo)
	bp_entity.destroy()
	for k, v in pairs(bpResult) do
		if k == 27 then
			v.get_control_behavior().enabled = false
		end
		if k == 28 then
			v.get_control_behavior().enabled = true
		end
		v.revive()
	end
	local songBuildings = jailSurface.find_entities_filtered{area={{-11+offset.x, -23+offset.y}, {12+offset.x, 25+offset.y}}, name = {
		"constant-combinator",
		"decider-combinator", 
		"substation",
		"programmable-speaker",
		"arithmetic-combinator",
		"electric-energy-interface"
	}}
	for k, v in pairs(songBuildings) do
		v.minable = false
		v.destructible = false
		v.operable = false
	end
end

function Public.initial_setup()
	game.map_settings.enemy_evolution.time_factor = 0
	game.map_settings.enemy_evolution.destroy_factor = 0
	game.map_settings.enemy_evolution.pollution_factor = 0
	game.map_settings.pollution.enabled = false
	game.map_settings.enemy_expansion.enabled = false

	game.map_settings.path_finder.fwd2bwd_ratio = 2
	game.map_settings.path_finder.goal_pressure_ratio = 3
	game.map_settings.path_finder.short_cache_size = 30
	game.map_settings.path_finder.long_cache_size = 50
	game.map_settings.path_finder.short_cache_min_cacheable_distance = 8
	game.map_settings.path_finder.long_cache_min_cacheable_distance = 60
	game.map_settings.path_finder.max_clients_to_accept_any_new_request = 4
	game.map_settings.path_finder.max_clients_to_accept_short_new_request = 150
	game.map_settings.path_finder.start_to_goal_cost_multiplier_to_terminate_path_find = 10000

	game.create_force("north")
	game.create_force("south")
	game.create_force("north_biters")
	game.create_force("south_biters")
	game.create_force("north_biters_boss")
	game.create_force("south_biters_boss")
	game.create_force("spectator")

	game.forces.spectator.research_all_technologies()
	local defs = {
		defines.input_action.open_blueprint_library_gui,
		defines.input_action.import_blueprint_string,
		defines.input_action.launch_rocket
	}
	local p = game.permissions.get_group("Default")
	for k, v in pairs(defs) do
		p.set_allows_action(v, false)
	end
	
	p = game.permissions.create_group("spectator")
	for action_name, _ in pairs(defines.input_action) do
		p.set_allows_action(defines.input_action[action_name], false)
	end

	defs = {
		defines.input_action.activate_copy,
		defines.input_action.activate_cut,
		defines.input_action.activate_paste,
		defines.input_action.change_active_quick_bar,
		defines.input_action.change_active_item_group_for_filters,
		defines.input_action.clear_cursor,
		defines.input_action.edit_permission_group,
		defines.input_action.gui_checked_state_changed,
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
		defines.input_action.set_filter,
		defines.input_action.set_player_color,
		defines.input_action.start_walking,
		defines.input_action.toggle_show_entity_info,
		defines.input_action.write_to_console,
		defines.input_action.map_editor_action,
		defines.input_action.toggle_map_editor,
		defines.input_action.change_multiplayer_config,
		defines.input_action.admin_action,
	}
	for _, d in pairs(defs) do p.set_allows_action(d, true) end

	global.suspend_time_limit = 3600
	global.reroll_time_limit = 1800
	global.gui_refresh_delay = 0
	global.game_lobby_active = true
	global.bb_debug = false
	global.bb_settings = {
		--TEAM SETTINGS--
		["team_balancing"] = true,			--Should players only be able to join a team that has less or equal members than the opposing team?
		["only_admins_vote"] = false,		--Are only admins able to vote on the global difficulty?
		--MAP SETTINGS--
		["new_year_island"] = false,
		["bb_map_reveal_toggle"] = true,
		["map_reroll_admin_disable"] = true,
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
	createTrollSong(game.forces.south.name,{x=6,y=0})
	createTrollSong(game.forces.north.name,{x=-40,y=0})
	createTrollSong(game.forces.spectator.name,{x=-80,y=0})
end



--Terrain Playground Surface
function Public.playground_surface()
	local map_gen_settings = {}
	map_gen_settings.seed = global.next_map_seed
	-- reset next_map_seed for next round
	global.next_map_seed = 1
	map_gen_settings.water = global.random_generator(15, 65) * 0.01
	map_gen_settings.starting_area = 2.5
	map_gen_settings.terrain_segmentation = global.random_generator(30, 40) * 0.1
	map_gen_settings.cliff_settings = {cliff_elevation_interval = 0, cliff_elevation_0 = 0}
	map_gen_settings.autoplace_controls = {
		["coal"] = {frequency = 6.5, size = 0.34, richness = 0.24},
		["stone"] = {frequency = 6, size = 0.385, richness = 0.25},
		["copper-ore"] = {frequency = 8.05, size = 0.352, richness = 0.35},
		["iron-ore"] = {frequency = 8.5, size = 0.8, richness = 0.23},
		["uranium-ore"] = {frequency = 2.2, size = 1, richness = 1},
		["crude-oil"] = {frequency = 8, size = 1.4, richness = 0.45},
		["trees"] = {frequency = global.random_generator(8, 28) * 0.1, size = global.random_generator(6, 14) * 0.1, richness = global.random_generator(2, 4) * 0.1},
		["enemy-base"] = {frequency = 0, size = 0, richness = 0}
	}
	local surface = game.create_surface(global.bb_surface_name, map_gen_settings)
	surface.request_to_generate_chunks({x = 0, y = -256}, 7)
	surface.force_generate_chunk_requests()
	surface.brightness_visual_weights = { -1.17, -0.975, -0.52 }
end

function Public.draw_structures()
	local surface = game.surfaces[global.bb_surface_name]
	Terrain.draw_spawn_area(surface)
	if global.active_special_games['mixed_ore_map'] then
		Terrain.draw_mixed_ore_spawn_area(surface)
	else
		Terrain.clear_ore_in_main(surface)
		Terrain.generate_spawn_ore(surface)
	end
	Terrain.generate_additional_rocks(surface)
	Terrain.generate_silo(surface)
	Terrain.draw_spawn_island(surface)
	--Terrain.generate_spawn_goodies(surface)
end

function Public.reveal_map()
	if global.bb_settings["bb_map_reveal_toggle"] then
		local surface = game.surfaces[global.bb_surface_name]
		local width = 2000 -- for one side
		local height = 500 -- for one side
		for x = 16, width, 32 do
			for y = 16, height, 32 do
				game.forces["spectator"].chart(surface, {{-x, -y}, {-x, -y}})
				game.forces["spectator"].chart(surface, {{x, -y}, {x, -y}})
				game.forces["spectator"].chart(surface, {{-x, y}, {-x, y}})
				game.forces["spectator"].chart(surface, {{x, y}, {x, y}})
			end
		end
	end
end

function Public.tables()
	local get_score = Score.get_table()
	get_score.score_table = {}
	global.science_logs_text = nil
	global.science_logs_total_north = nil
	global.science_logs_total_south = nil
	-- Name of main BB surface within game.surfaces
	-- We hot-swap here between 2 surfaces.
	if global.bb_surface_name == 'bb0' then
		global.bb_surface_name = "bb1"
	else
		global.bb_surface_name = "bb0"
	end

	global.suspended_time = 36000
	global.suspend_target = nil
	global.suspend_voting = {}
	global.suspended_players = {}
	if global.random_generator == nil then
		global.random_generator = game.create_random_generator()
	end
	if global.next_map_seed == nil or global.next_map_seed < 341 then
		-- Seeds 1-341 inclusive are the same
		-- https://lua-api.factorio.com/latest/classes/LuaRandomGenerator.html#re_seed
		global.next_map_seed = global.random_generator(341, 4294967294)
	end
	-- Our terrain gen seed IS the map seed
	global.random_generator.re_seed(global.next_map_seed)
	global.reroll_map_voting = {}
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
	global.tm_custom_name = {}
	global.total_passive_feed_redpotion = 0
	global.unit_spawners = {}
	global.boss_units = {}
	global.unit_spawners.north_biters = {}
	global.unit_spawners.south_biters = {}
	global.ai_strikes = {}
	global.ai_targets = {}
	global.player_data_afk = {}
	global.max_group_size_initial = 300							--Maximum unit group size for all biters at start, just used as a reference, doesnt change initial group size.
	global.max_group_size = {}
	global.max_group_size["north_biters"] = 300							--Maximum unit group size for north biters.
	global.max_group_size["south_biters"] = 300							--Maximum unit group size for south biters.
	global.biter_spawn_unseen = {
		["north"] = {
			["medium-spitter"] = true, ["medium-biter"] = true, ["big-spitter"] = true, ["big-biter"] = true, ["behemoth-spitter"] = true, ["behemoth-biter"] = true
		},
		["south"] = {
			["medium-spitter"] = true, ["medium-biter"] = true, ["big-spitter"] = true, ["big-biter"] = true, ["behemoth-spitter"] = true, ["behemoth-biter"] = true
		},
		["north_biters_boss"] = {
			["medium-spitter"] = true, ["medium-biter"] = true, ["big-spitter"] = true, ["big-biter"] = true, ["behemoth-spitter"] = true, ["behemoth-biter"] = true
		},
		["south_biters_boss"] = {
			["medium-spitter"] = true, ["medium-biter"] = true, ["big-spitter"] = true, ["big-biter"] = true, ["behemoth-spitter"] = true, ["behemoth-biter"] = true
		}
	}
	global.difficulty_vote_value = 1
	global.difficulty_vote_index = 4

	global.difficulty_votes_timeout = 36000

	-- A FIFO that holds dead unit positions. It is used by unit
	-- reanimation logic. This container is to be accessed by force index.
	global.dead_units = {}

	-- A size of pre-allocated pool memory to be used in every FIFO.
	-- Higher value = higher memory footprint, faster I/O.
	-- Lower value = more resize cycles during push, dynamic memory footprint.
	global.bb_fifo_size = 1024

	-- A balancer threshold that instructs reanimation logic to increase
	-- number of API calls to LuaSurface::create_entity. This cycle threshold
	-- is representing amount of nodes within dead_units list. If it exceeds
	-- a multiplication of this value, additional call is made.
	--  * 50 = 1 additional call
	--  * 2250 = 45 additional call(s)
	-- This threshold is mainly used to protect against overflowing of
	-- reanimation requests at 100% reanimation chance. Additional benefit
	-- of it is to quickly revive a critical mass of biters in case defenses
	-- of attacked team are overpowered.
	global.reanim_balancer = 50

	-- Maximum evolution threshold after which biters have 100% chance
	-- to reanimate. The reanimation starts after evolution factor reaches
	-- 100, so this value starts having an effect only at that point.
	-- To reach 100% reanimation chance at 200% evolution, set it to 100.
	-- To reach 100% reanimation chance at 350% evolution, set it to 250.
	global.max_reanim_thresh = 250

	-- Container for storing chance of reanimation. The stored value
	-- is a range between [0, 100], accessed by key with force's index.
	global.reanim_chance = {}

	fifo.init()

	global.next_attack = "north"
	if global.random_generator(1,2) == 1 then global.next_attack = "south" end
end

function Public.load_spawn()
	local surface = game.surfaces[global.bb_surface_name]
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

	local surface = game.surfaces[global.bb_surface_name]

	local f = game.forces["north"]
	f.set_spawn_position({0, -44}, surface)
	f.set_cease_fire('player', true)
	f.set_friend("spectator", true)
	f.set_friend("south_biters", true)
	f.set_friend("south_biters_boss", true)
	f.share_chart = true

	local f = game.forces["south"]
	f.set_spawn_position({0, 44}, surface)
	f.set_cease_fire('player', true)
	f.set_friend("spectator", true)
	f.set_friend("north_biters", true)
	f.set_friend("north_biters_boss", true)
	f.share_chart = true

	local f = game.forces["north_biters"]
	f.set_friend("south_biters", true)
	f.set_friend("south_biters_boss", true)
	f.set_friend("north_biters_boss", true)
	f.set_friend("south", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false
	global.dead_units[f.index] = fifo.create(global.bb_fifo_size)

	local f = game.forces["south_biters"]
	f.set_friend("north_biters", true)
	f.set_friend("north_biters_boss", true)
	f.set_friend("south_biters_boss", true)
	f.set_friend("north", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false
	global.dead_units[f.index] = fifo.create(global.bb_fifo_size)
	

	local f = game.forces["north_biters_boss"]
	f.set_friend("south_biters", true)
	f.set_friend("north_biters", true)
	f.set_friend("south_biters_boss", true)
	f.set_friend("south", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false
	global.dead_units[f.index] = fifo.create(global.bb_fifo_size)

	local f = game.forces["south_biters_boss"]
	f.set_friend("north_biters", true)
	f.set_friend("south_biters", true)
	f.set_friend("north_biters_boss", true)
	f.set_friend("north", true)
	f.set_friend("player", true)
	f.set_friend("spectator", true)
	f.share_chart = false
	global.dead_units[f.index] = fifo.create(global.bb_fifo_size)

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
		game.forces[force.name].technologies["cliff-explosives"].enabled = false
		game.forces[force.name].technologies["land-mine"].enabled = false
		game.forces[force.name].research_queue_enabled = true
		global.ai_targets[force.name] = { available = {}, selected = {} }
		global.spy_fish_timeout[force.name] = 0
		global.bb_evolution[force.name] = 0
		global.reanim_chance[force.index] = 0
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
