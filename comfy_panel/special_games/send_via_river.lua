--- Copy and paste this code into the run lua snippets box in the editor to run it
--- You may:
--- - change the next_map_seed or unset it to be random
--- To remove it, you should:
--- Event.remove_removable_function(defines.events.on_tick, RUN_SPECIAL_NAME)
--- global.active_special_games["disable_sciences"] = false
--- global.special_games_variables["disabled_food"] = {}
--- global.drbuttons_special_boxes = {}

-- global.next_map_seed = 3393475325
-- global.server_restart_timer = 0
-- global.bb_settings["bb_map_reveal_toggle"] = true
-- require("maps.biter_battles_v2.game_over").server_restart()
-- game.speed = 10

local Event = require("utils.event")
local bb_config = require("maps.biter_battles_v2.config")
local Server = require("utils.server")
local tables = require("maps.biter_battles_v2.tables")
local food_values = tables.food_values
local enemy_team_of = tables.enemy_team_of
-- local INIT_SPECIAL_NAME = "drbuttons-special-init"
-- local RUN_SPECIAL_NAME = "drbuttons-special-run"

--- Class representing an entity to be placed on the surface
Entity = {}
---@class Entity
---@field name string
---@field position table
---@field force string
---@field direction int
---@field type string|nil
function Entity:new(o, name, position, force, direction, type)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	o.name = name
	o.position = position
	o.force = force
	o.direction = direction
	o.type = type
	return o
end

--- Place landfill at the given position on the surface
---@param surface LuaSurface
---@param position table
local function place_landfill(surface, position)
	if not surface or not position then
		return
	end
	surface.set_tiles({ { name = "landfill", position = position } }, true)
end

--- Clears entities in a specified area, unused for now
---@param x int The x-coordinate around which entities will be cleared
---@param y int The y-coordinate around which entities will be cleared
---@param surface LuaSurface The surface on which entities are to be cleared
---@param radius int The radius around the (x, y) within which entities will be cleared
local function clear_entities_around(x, y, surface, radius)
	local area = { { x - radius, y - radius }, { x + radius, y + radius } }
	local entities = surface.find_entities_filtered({ area = area })
	for _, entity in pairs(entities) do
		if entity.valid and entity.name ~= "player" then -- Exclude player entity from being destroyed
			entity.destroy()
		end
	end
end

--- Place an entity on the given surface, add 1x1 landfill if water
---@param surface LuaSurface
---@param entity Entity
---@return LuaEntity|nil
local function place_entity(surface, entity)
	if not surface or not entity then
		game.print(
			"No surface or entity: Unable to place entity: "
				.. serpent.line(entity)
				.. " on surface: "
				.. serpent.line(surface)
		)
		return
	end
	local chunk_position = { x = math.floor(entity.position.x / 32), y = math.floor(entity.position.y / 32) }
	if not surface.is_chunk_generated(chunk_position) then
		game.print("generating chunk?")
		surface.request_to_generate_chunks(chunk_position, 5)
		surface.force_generate_chunk_requests()
	end

	-- clear_entities_around(entity.position.x, entity.position.y, surface, 1)
	if surface.get_tile(entity.position.x, entity.position.y).collides_with("water-tile") then
		place_landfill(surface, entity.position)
	end
	local maybe_entity = surface.create_entity({
		name = entity.name,
		position = entity.position,
		force = entity.force,
		direction = entity.direction,
		type = entity.type,
	})
	if not maybe_entity then
		game.print(
			"Returned nil: Unable to place entity: " .. serpent.line(entity) .. " on surface: " .. serpent.line(surface)
		)
	end
	maybe_entity.minable = false
	maybe_entity.destructible = false
	maybe_entity.rotatable = false
	maybe_entity.operable = false
	return maybe_entity
end

--- Determine the y position to place entities
--- Will fail if not charted yet
---@param x int
---@param surface LuaSurface
---@param force string
---@return int
local function find_non_water_y_position(x, surface, force)
	local y_position = 12
	local increment = 1
	if force == "north" then
		y_position = -y_position
		increment = -increment
	end
	while surface.get_tile(x, y_position).collides_with("water-tile") do
		y_position = y_position + increment
	end
	return y_position
end

--- Place an inserter at the end of the water
---@param x int
---@param y int
---@param surface LuaSurface
---@param force string
local function place_inserter_at_water_end(x, y, surface, force)
	local inserter_direction = force == "north" and defines.direction.north or defines.direction.south
	local inserter = Entity:new(nil, "long-handed-inserter", { x = x, y = y }, force, inserter_direction)
	place_entity(surface, inserter)
end

--- Place a series of underground belts
---@param x int
---@param y_start int
---@param y_end int
---@param surface LuaSurface
---@param force string
---@param direction int
local function place_underground_belts(x, y_start, y_end, surface, force, direction)
	local under_in = Entity:new(nil, "underground-belt", { x = x, y = y_start }, force, direction, "input")
	local under_out = Entity:new(nil, "underground-belt", { x = x, y = y_end }, force, direction, "output")
	place_entity(surface, under_in)
	place_entity(surface, under_out)
end

---@param x_start int
---@param y_start int
---@param x_end int
---@param surface LuaSurface
---@param force string
---@param direction int
local function place_main_trunk_transport_belts(x_start, y_start, x_end, surface, force, direction)
	local x_increment = x_start < x_end and 1 or -1
	for x = x_start, x_end, x_increment do
		local belt = Entity:new(nil, "transport-belt", { x = x, y = y_start }, force, direction)
		place_entity(surface, belt)
	end
end

---@param west_start_x int
---@param east_start_x int
---@param trunk_start_y int
---@param surface LuaSurface
---@param force string
---@param meeting_x int
---@param meeting_y int
local function join_west_east_trunks(west_start_x, east_start_x, trunk_start_y, surface, force, meeting_x, meeting_y)
	local y_left = math.abs(meeting_y - trunk_start_y)
	local first_kink_direction = force == "north" and defines.direction.north or defines.direction.south
	local first_kink_delta = force == "north" and -1 or 1
	local current_y = trunk_start_y
	for i = 1, y_left, 1 do
		local west_belt =
			Entity:new(nil, "transport-belt", { x = west_start_x + 1, y = current_y }, force, first_kink_direction)
		place_entity(surface, west_belt)
		local east_belt =
			Entity:new(nil, "transport-belt", { x = east_start_x - 1, y = current_y }, force, first_kink_direction)
		place_entity(surface, east_belt)
		current_y = current_y + first_kink_delta
	end

	-- west
	local current_x = west_start_x + 1
	local second_kink_delta = 1
	local second_kink_direction = defines.direction.east
	while math.abs(current_x - meeting_x) >= 1 do
		local east_belt =
			Entity:new(nil, "transport-belt", { x = current_x, y = meeting_y }, force, second_kink_direction)
		place_entity(surface, east_belt)
		current_x = current_x + second_kink_delta
	end

	-- east
	current_x = east_start_x - 1
	second_kink_delta = -1
	second_kink_direction = defines.direction.west
	while math.abs(current_x - meeting_x) >= 1 do
		local east_belt =
			Entity:new(nil, "transport-belt", { x = current_x, y = meeting_y }, force, second_kink_direction)
		place_entity(surface, east_belt)
		current_x = current_x + second_kink_delta
	end

	local final_direction = force == "north" and defines.direction.south or defines.direction.north
	local middle_belt = Entity:new(nil, "transport-belt", { x = meeting_x, y = meeting_y }, force, final_direction)
	place_entity(surface, middle_belt)
end

--- Implement the connection logic for inserters to the belts
---@param x int
---@param y int
---@param surface LuaSurface
---@param force string
---@param trunk_position int
local function make_belts_from_inserter_to_trunk(x, y, surface, force, trunk_position)
	local direction = force == "north" and defines.direction.south or defines.direction.north
	local offset = force == "north" and 1 or -1
	local working_y_start = y
	local function y_end_from_start(y_start)
		return y_start + (offset * 5)
	end
	local y_end = y_end_from_start(working_y_start)
	local final_end_pos = trunk_position - offset
	while y_end ~= final_end_pos and math.abs(y_end / final_end_pos) > 1.0 do
		place_underground_belts(x, working_y_start, y_end, surface, force, direction)
		working_y_start = y_end + offset
		y_end = y_end_from_start(working_y_start)
	end
	local tiles_left = math.abs(working_y_start - final_end_pos)
	if tiles_left >= 3 then
		place_underground_belts(x, working_y_start, final_end_pos, surface, force, direction)
	else
		for _ = 1, tiles_left + 1, 1 do
			local belt = Entity:new(nil, "transport-belt", { x = x, y = working_y_start }, force, direction)
			place_entity(surface, belt)
			working_y_start = working_y_start + offset
		end
	end
end

local function main_function()
	local surface = game.surfaces[global.bb_surface_name]
	local trunk_medial_point = 20
	local trunk_distal_point = 1900
	local distance_between_inserter_points = 400
	local required_min_distance_from_medial = 50
	global.drbuttons_special_boxes = {}
	for _, force in pairs({ "north", "south" }) do
		local trunk_position = force == "north" and -5 or 4
		local offset = force == "north" and 2 or -2
		local last_point = -9999
		for x = -trunk_distal_point, -trunk_medial_point, distance_between_inserter_points do
			local y = find_non_water_y_position(x, surface, force) + offset
			place_inserter_at_water_end(x, y, surface, force)
			make_belts_from_inserter_to_trunk(x, y + offset, surface, force, trunk_position)
			last_point = x
		end
		if last_point < -required_min_distance_from_medial then
			local x = -required_min_distance_from_medial
			local y = find_non_water_y_position(x, surface, force) + offset
			place_inserter_at_water_end(x, y, surface, force)
			make_belts_from_inserter_to_trunk(x, y + offset, surface, force, trunk_position)
		end
		place_main_trunk_transport_belts(
			-trunk_distal_point,
			trunk_position,
			-trunk_medial_point,
			surface,
			force,
			defines.direction.east
		)
		for x = trunk_distal_point, trunk_medial_point, -distance_between_inserter_points do
			local y = find_non_water_y_position(x, surface, force) + offset
			place_inserter_at_water_end(x, y, surface, force)
			make_belts_from_inserter_to_trunk(x, y + offset, surface, force, trunk_position)
			last_point = x
		end
		if last_point > required_min_distance_from_medial then
			local x = required_min_distance_from_medial
			local y = find_non_water_y_position(x, surface, force) + offset
			place_inserter_at_water_end(x, y, surface, force)
			make_belts_from_inserter_to_trunk(x, y + offset, surface, force, trunk_position)
		end
		place_main_trunk_transport_belts(
			trunk_medial_point,
			trunk_position,
			trunk_distal_point,
			surface,
			force,
			defines.direction.west
		)
		local meeting_y_point = force == "north" and -15 or 14
		local meeting_x_point = force == "north" and -1 or 0

		join_west_east_trunks(
			-trunk_medial_point,
			trunk_medial_point,
			trunk_position,
			surface,
			force,
			meeting_x_point,
			meeting_y_point
		)
		local final_loader_check_point = (force == "north" and 2 or -1) + meeting_y_point
		-- place_inserter_at_water_end(meeting_x_point, final_inserter_check_point, surface, force)

		local loader_direction = force == "north" and defines.direction.south or defines.direction.north
		local loader_type = "input"
		place_landfill(surface, { x = meeting_x_point, y = final_loader_check_point })
		place_landfill(surface, { x = meeting_x_point, y = final_loader_check_point + (force == "north" and -1 or 1) })
		local loader = Entity:new(
			nil,
			"loader",
			{ x = meeting_x_point, y = final_loader_check_point },
			force,
			loader_direction,
			loader_type
		)
		place_entity(surface, loader)
		-- local inserter = Entity:new(nil, "long-handed-inserter", { x = x, y = y }, force, inserter_direction)
		-- place_entity(surface, inserter)

		local y_final = force == "north" and meeting_y_point + 3 or meeting_y_point - 3
		local box = Entity:new(nil, "steel-chest", { x = meeting_x_point, y = y_final }, force, nil)
		local box_entity = place_entity(surface, box)
		global.drbuttons_special_boxes[force] = box_entity
	end
	-- if you switch to inserters to slow even more, you can use this.
	-- local pole_type = "medium-electric-pole"
	-- local small_pole_points = {
	-- 	{ x = 2, y = -12 },
	-- 	{ x = 7, y = -8 },
	-- 	{ x = 10, y = -4 },
	-- 	{ x = 10, y = 4 },
	-- 	{ x = 7, y = 8 },
	-- 	{ x = 2, y = 12 },
	-- }
	-- for _, point in pairs(small_pole_points) do
	-- 	local pole = Entity:new(nil, pole_type, { x = point.x, y = point.y }, "spectator", nil)
	-- 	place_entity(surface, pole)
	-- end
	-- local eei = Entity:new(nil, "electric-energy-interface", { x = 12, y = 0 }, "spectator", nil)
	-- place_landfill(surface, { x = 11, y = -1 })
	-- place_landfill(surface, { x = 12, y = -1 })
	-- place_landfill(surface, { x = 11, y = 0 })
	-- place_entity(surface, eei)
end

local science_packs = {
	["automation-science-pack"] = true,
	["logistic-science-pack"] = true,
	["military-science-pack"] = true,
	["chemical-science-pack"] = true,
	["production-science-pack"] = true,
	["utility-science-pack"] = true,
	["space-science-pack"] = true,
}

--- Get a random player from a specified force
---@param force_name string The name of the force
---@return LuaPlayer|nil
local function get_random_player_from_force(force_name)
	local force = game.forces[force_name]
	if not force then
		return nil
	end

	local players = force.players
	if #players == 0 then
		return nil -- No players in this force
	end

	local random_index = math.random(#players)
	return players[random_index]
end

---Copied from feeding.lua
---@param team string
---@return string
local function get_enemy_team_of(team)
	if global.training_mode then
		return team
	else
		return enemy_team_of[team]
	end
end

---Copied from feeding.lua
---@param player LuaPlayer
---@param food string
---@param flask_amount int
local function print_feeding_msg(player, food, flask_amount)
	if not get_enemy_team_of(player.force.name) then
		return
	end

	local n = bb_config.north_side_team_name
	local s = bb_config.south_side_team_name
	if global.tm_custom_name["north"] then
		n = global.tm_custom_name["north"]
	end
	if global.tm_custom_name["south"] then
		s = global.tm_custom_name["south"]
	end
	local team_strings = {
		["north"] = table.concat({ "[color=120, 120, 255]", n, "'s[/color]" }),
		["south"] = table.concat({ "[color=255, 65, 65]", s, "'s[/color]" }),
	}

	local colored_player_name = table.concat({
		"[color=",
		player.color.r * 0.6 + 0.35,
		",",
		player.color.g * 0.6 + 0.35,
		",",
		player.color.b * 0.6 + 0.35,
		"]",
		player.name,
		"[/color]",
	})
	local formatted_food = table.concat({
		"[color=",
		food_values[food].color,
		"]",
		food_values[food].name,
		" juice[/color]",
		"[img=item/",
		food,
		"]",
	})
	local formatted_amount =
		table.concat({ "[font=heading-1][color=255,255,255]" .. flask_amount .. "[/color][/font]" })

	if flask_amount >= 20 then
		local enemy = get_enemy_team_of(player.force.name)
		game.print(
			table.concat({
				colored_player_name,
				" fed ",
				formatted_amount,
				" flasks of ",
				formatted_food,
				" to team ",
				team_strings[enemy],
				" biters!",
			}),
			{ r = 0.9, g = 0.9, b = 0.9 }
		)
		Server.to_discord_bold(table.concat({
			player.name,
			" fed ",
			flask_amount,
			" flasks of ",
			food_values[food].name,
			" to team ",
			enemy,
			" biters!",
		}))
	else
		local target_team_text = "the enemy"
		if global.training_mode then
			target_team_text = "your own"
		end
		if flask_amount == 1 then
			player.print(
				"You fed one flask of " .. formatted_food .. " to " .. target_team_text .. " team's biters.",
				{ r = 0.98, g = 0.66, b = 0.22 }
			)
		else
			player.print(
				"You fed "
					.. formatted_amount
					.. " flasks of "
					.. formatted_food
					.. " to "
					.. target_team_text
					.. " team's biters.",
				{ r = 0.98, g = 0.66, b = 0.22 }
			)
		end
	end
end

---@param box LuaEntity
local function check_box_for_science(box)
	local enemy_team = get_enemy_team_of(box.force.name)
	local biter_force_name = enemy_team .. "_biters"
	if box.valid then
		local inventory = box.get_inventory(defines.inventory.chest)
		if inventory then
			for item_name, item_count in pairs(inventory.get_contents()) do
				if science_packs[item_name] ~= nil then
					inventory.remove({ name = item_name, count = item_count })
					-- local evolution_before_feed = global.bb_evolution[biter_force_name]
					-- local threat_before_feed = global.bb_threat[biter_force_name]
					set_evo_and_threat(item_count, item_name, biter_force_name)
					local maybe_player = get_random_player_from_force(box.force.name)
					if maybe_player then
						print_feeding_msg(maybe_player, item_name, item_count)
					end
					if item_name == "space-science-pack" then
						global.spy_fish_timeout[box.force] = game.tick + 99999999
					end
				else
					inventory.remove({ name = item_name, count = item_count })
				end
			end
		end
	end
end

local function drbuttons_special_game_watcher(event)
	if not global.send_via_river_specialbox_check_interval then
		return
	end
	if event.tick % global.send_via_river_specialbox_check_interval == 0 then
		for _, box in pairs(global.drbuttons_special_boxes) do
			check_box_for_science(box)
		end
	end
end

local function drbuttons_temporary_tick_handler(event)
	if not global.send_via_river_special_init then
		return
	end
	game.speed = 1
	main_function()
	global.send_via_river_special_init = false
	global.send_via_river_specialbox_check_interval = 60*60*5

	local disabled_food = {
		["automation-science-pack"] = true,
		["logistic-science-pack"] = true,
		["military-science-pack"] = true,
		["chemical-science-pack"] = true,
		["production-science-pack"] = true,
		["utility-science-pack"] = true,
		["space-science-pack"] = true,
	}
	global.active_special_games["disable_sciences"] = true
	global.special_games_variables["disabled_food"] = disabled_food
end

local Public = {
	name = { type = "label", caption = "Send via River", tooltip = "Send the science via river belts" },
	config = {},
	button = { name = "apply", type = "button", caption = "Apply" },
	generate = function(config, player)
		global.send_via_river_special_init = true
	end,
}

Event.add(defines.events.on_tick, drbuttons_temporary_tick_handler)
Event.add(defines.events.on_tick, drbuttons_special_game_watcher)
return Public
