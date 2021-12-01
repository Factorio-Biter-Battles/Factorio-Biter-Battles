local Event = require 'utils.event'
local Color = require 'utils.color_presets'
local Tables = require 'maps.biter_battles_v2.tables'
local Gui_styles = require 'utils.gui_styles'
local Public = {}
global.active_special_games = {}
global.special_games_variables = {}
local food_names = {}
for k, v in pairs(Tables.food_names) do
	table.insert(food_names, k)
end
local valid_special_games = {
	--[[
	Add your special game here.
	Syntax:
	<game_name> = {
		name = "<Name displayed in gui>"
		config = {
			list of all knobs, leavers and dials used to config your game
			[1] = {name = "<name of this element>" called in on_gui_click to set variables, type = "<type of this element>", any other parameters needed to define this element},
			[2] = {name = "example_1", type = "textfield", text = "200", numeric = true, width = 40},
			[3] = {name = "example_2", type = "checkbox", caption = "Some checkbox", state = false}
			NOTE all names should be unique in the scope of the game mode
		},
		button = {name = "<name of this button>" called in on_gui_clicked , type = "button", caption = "Apply"}
	}
	]]
	turtle = {
		name = "Turtle",
		config = {
			[1] = {name = "label1", type = "label", caption = "moat width"},
			[2] = {name = 'moat_width', type = "textfield", text = "5", numeric = true, width = 40},
			[3] = {name = "label2", type = "label", caption = "entrance width"},
			[4] = {name = 'entrance_width', type = "textfield", text = "20", numeric = true, width = 40},
			[5] = {name = "label3", type = "label", caption = "size x"},
			[6] = {name = 'size_x', type = "textfield", text = "200", numeric = true, width = 40},
			[7] = {name = "label4", type = "label", caption = "size y"},
			[8] = {name = 'size_y', type = "textfield", text = "200", numeric = true, width = 40},
			[9] = {name = "chart_turtle", type = "button", caption = "Chart", width = 60}
		},
		button = {name = "turtle_apply", type = "button", caption = "Apply"}
	},

	infinity_chest = {
		name = "Infinity chest",
		config = {
			[1] = {name = "separate_chests", type = "switch", left_label_caption = "Single", right_label_caption = "Multi", switch_state = "left"},
			[2] = {name = "label1", type = "label", caption = "Gap size"},
			[3] = {name = "gap", type = "textfield", text = "3", numeric = true, width = 40},
			[4] = {name = "eq1", type = "choose-elem-button", elem_type = "item"},
			[5] = {name = "eq2", type = "choose-elem-button", elem_type = "item"},
			[6] = {name = "eq3", type = "choose-elem-button", elem_type = "item"},
			[7] = {name = "eq4", type = "choose-elem-button", elem_type = "item"},
			[8] = {name = "eq5", type = "choose-elem-button", elem_type = "item"}
		},
		button = {name = "infinity_chest_apply", type = "button", caption = "Apply"}
	},

	power_feed = {
		name = "Power feed",
		config = {
			[1] = {name = "label1", caption = "Mutagen equivalent of 1GJ =", type = "label"},
			[2] = {name = "flasks_number", type = "textfield", text = "1", numeric = true, allow_decimal = true, width = 40},
			[3] = {name = "flask_type", type = "choose-elem-button", elem_type = "item", elem_filters = {{filter = "name", name = food_names}}, item = "automation-science-pack"},
			[4] = {name = "line1", type = "line", direction = "vertical"},
			[5] = {name = "min_charge", type = "textfield", numeric = true, text = "1", width = 40, tooltip = "Min charge required for feeding. [GJ]"},
			[6] = {name = "line2", type = "line", direction = "vertical"},
			[7] = {name = "capacity", type = "textfield", text = "10", numeric = true, width = 40, tooltip = "Capacity of the spawned accumulators"}
		},
		button = {name = "power_feed_apply", type = "button", caption = "Apply"}
	}

}

function Public.reset_active_special_games()
	for _, i in ipairs(global.active_special_games) do
		i = false
	end
end

local function generate_turtle(moat_width, entrance_width, size_x, size_y)
	game.print("Special game turtle is being generated!", Color.warning)
	local surface = game.surfaces[global.bb_surface_name]
	local water_positions = {}
	local concrete_positions = {}
	local landfill_positions = {}

	for i = 0, size_y + moat_width do -- veritcal canals
		for a = 1, moat_width do
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) + a, y = i}})
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) - size_x - a, y = i}})
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) + a, y = -i - 1}})
			table.insert(water_positions, {name = "deepwater", position = {x = (size_x / 2) - size_x - a, y = -i - 1}})
		end
	end
	for i = 0, size_x do -- horizontal canals
		for a = 1, moat_width do
			table.insert(water_positions, {name = "deepwater", position = {x = i - (size_x / 2), y = size_y + a}})
			table.insert(water_positions, {name = "deepwater", position = {x = i - (size_x / 2), y = -size_y - 1 - a}})
		end
	end

	for i = 0, entrance_width - 1 do
		for a = 1, moat_width + 6 do
			table.insert(concrete_positions, {name = "refined-concrete", position = {x = -entrance_width / 2 + i, y = size_y - 3 + a}})
			table.insert(concrete_positions, {name = "refined-concrete", position = {x = -entrance_width / 2 + i, y = -size_y + 2 - a}})
			table.insert(landfill_positions, {name = "landfill", position = {x = -entrance_width / 2 + i, y = size_y - 3 + a}})
			table.insert(landfill_positions, {name = "landfill", position = {x = -entrance_width / 2 + i, y = -size_y + 2 - a}})
		end
	end

	surface.set_tiles(water_positions)
	surface.set_tiles(landfill_positions)
	surface.set_tiles(concrete_positions)

end

local function generate_infinity_chest(separate_chests, gap, eq)
	local surface = game.surfaces[global.bb_surface_name]
	local position_0 = {x = 0, y = -42}

	local objects = surface.find_entities_filtered {name = 'infinity-chest'}
	for _, object in pairs(objects) do
		object.destroy()
	end

	game.print("Special game Infinity chest is being generated!", Color.warning)

	if separate_chests == "left" then
		local chest = surface.create_entity {name = "infinity-chest", position = position_0, force = "neutral", fast_replace = true}
		chest.minable = false
		chest.operable = false
		chest.destructible = false
		for i, v in ipairs(eq) do
			chest.set_infinity_container_filter(i, {name = v, index = i, count = game.item_prototypes[v].stack_size})
		end
		chest.clone {position = {position_0.x, -position_0.y}}

	elseif separate_chests == "right" then
		local k = gap + 1
		for i, v in ipairs(eq) do
			local chest = surface.create_entity {name = "infinity-chest", position = position_0, force = "neutral", fast_replace = true}
			chest.minable = false
			chest.operable = false
			chest.destructible = false
			chest.set_infinity_container_filter(i, {name = v, index = i, count = game.item_prototypes[v].stack_size})
			chest.clone {position = {position_0.x, -position_0.y}}
			position_0.x = position_0.x + (i * k)
			k = k * -1
		end
	end
end

local function generate_power_feed(flasks_number, flask_type, min_charge, capacity)
	local surface = game.surfaces[global.bb_surface_name]
	local silos = surface.find_entities_filtered {name = "rocket-silo"}

	for _, v in ipairs(silos) do
		local power_pole
		if v.force.name == "north" then
			power_pole = surface.create_entity {name = "medium-electric-pole", position = {v.position.x, v.position.y + 5}, force = v.force}
			global.special_games_variables["north_main_pole"] = power_pole
		elseif v.force.name == "south" then
			power_pole = surface.create_entity {name = "medium-electric-pole", position = {v.position.x, v.position.y - 6}, force = v.force}
			global.special_games_variables["south_main_pole"] = power_pole
		end
		power_pole.destructible = false
		power_pole.minable = false

		-- special_games_variables["power_poles"][v.force.name .. "_grid"] = power_pole
		for i, b in ipairs({-4, -2, 1, 3}) do
			local energy_interface = surface.create_entity {name = "electric-energy-interface", position = {power_pole.position.x + b, power_pole.position.y}, force = v.force}
			energy_interface.destructible = false
			energy_interface.minable = false
			energy_interface.electric_buffer_size = capacity * 1000000000 -- GJ
			energy_interface.power_production = 0
			energy_interface.power_usage = 0
			energy_interface.operable = false
		end
	end
	global.special_games_variables["flasks_per_1GJ"] = flasks_number
	global.special_games_variables["flask_type"] = flask_type
	if tonumber(flasks_number) < 1 then
		global.special_games_variables["min_charge"] = min_charge / flasks_number
	else	
		global.special_games_variables["min_charge"] = min_charge
	end
	global.active_special_games["power_feed"] = true
end

function Public.feed_energy(player)
	local surface = player.surface
    if not player.valid then return end
    if not player.force.valid then return end
    if game.ticks_played < global.difficulty_votes_timeout then player.print("Please wait for voting to finish before feeding") return end

	local enemy_force = game.forces[Tables.enemy_team_of[player.force.name]]
	local main_pole = global.special_games_variables[player.force.name .. "_main_pole"]

	-- summing up the charge from all connected accus
	local total_charge = 0
	local accumulators = surface.find_entities_filtered {name = {"accumulator", "electric-energy-interface"}, force = player.force, to_be_deconstructed = false}
	for _, i in ipairs(accumulators) do
		if i.electric_network_id == main_pole.electric_network_id then
			total_charge = total_charge + i.energy
		end
	end
	total_charge = total_charge / 1000000000 -- change J to GJ

	-- check if the charge is bigger than min value, to prevent spam
	if total_charge < tonumber(global.special_games_variables["min_charge"]) then
		player.print("Minimum charge required is " .. global.special_games_variables["min_charge"] .. "GJ!")
		return
	end

	-- translate GJs to non-round number of flasks chosen in config
	local flask_equivalent = total_charge * global.special_games_variables["flasks_per_1GJ"]

	-- charge to be returned in J, to prevent loosing energy cased by the translation
	local charge_to_return = (flask_equivalent - math.floor(flask_equivalent)) / global.special_games_variables["flasks_per_1GJ"] * 1000000000

	game.print(table.concat({Gui_styles.colored_player(player), " charged ", enemy_force.name, "'s biters with ", Gui_styles.colored_text(math.round(flask_equivalent / global.special_games_variables["flasks_per_1GJ"], 3) .. "GJ!", Color.yellow)}))
	
	local biter_force_name = enemy_force.name .. "_biters"
	set_evo_and_threat(math.floor(flask_equivalent), global.special_games_variables["flask_type"], biter_force_name)

	-- clearing accus
	for _, i in ipairs(accumulators) do
		i.energy = 0
	end
	surface.find_entity("electric-energy-interface", {main_pole.position.x + 1, main_pole.position.y}).energy = charge_to_return
end

local create_special_games_panel = (function(player, frame)
	frame.clear()
	frame.add{type = "label", caption = "Configure and apply a simple special game here"}.style.single_line = false

	for k, v in pairs(valid_special_games) do
		local a = frame.add {type = "frame"}
		a.style.width = 750
		local table = a.add {name = k, type = "table", column_count = 3, draw_vertical_lines = true}
		table.add{type = "label", caption = v.name}.style.width = 100
		local config = table.add {name = k .. "_config", type = "flow", direction = "horizontal"}
		config.style.width = 500
		for _, i in ipairs(v.config) do
			config.add(i)
			config[i.name].style.width = i.width
		end
		table.add {name = v.button.name, type = v.button.type, caption = v.button.caption}
		table[k .. "_config"].style.vertical_align = "center"
	end
end)

local function on_gui_click(event)
	local player = game.get_player(event.player_index)
	local element = event.element
	if not element.type == "button" then return end
	local config = element.parent.children[2]

	if string.find(element.name, "_apply") then
		local flow = element.parent.add {type = "flow", direction = "vertical"}
		flow.add {type = "button", name = string.gsub(element.name, "_apply", "_confirm"), caption = "Confirm"}
		flow.add {type = "button", name = "cancel", caption = "Cancel"}
		element.visible = false -- hides Apply button
		player.print("[SPECIAL GAMES] Are you sure? This change will be reversed only on map restart!", Color.cyan)

	elseif string.find(element.name, "_confirm") then
		config = element.parent.parent.children[2]

	end
	-- Insert logic for apply button here

	if element.name == "turtle_confirm" then

		local moat_width = config["moat_width"].text
		local entrance_width = config["entrance_width"].text
		local size_x = config["size_x"].text
		local size_y = config["size_y"].text

		generate_turtle(moat_width, entrance_width, size_x, size_y)
	elseif element.name == "chart_turtle" then
		config = element.parent.parent.children[2]
		local moat_width = config["moat_width"].text
		local entrance_width = config["entrance_width"].text
		local size_x = config["size_x"].text
		local size_y = config["size_y"].text

		game.forces["spectator"].chart(game.surfaces[global.bb_surface_name], {{-size_x / 2 - moat_width, -size_y - moat_width}, {size_x / 2 + moat_width, size_y + moat_width}})

	elseif element.name == "infinity_chest_confirm" then

		local separate_chests = config["separate_chests"].switch_state
		local gap = config["gap"].text
        local eq = {
			config["eq1"].elem_value, 
			config["eq2"].elem_value, 
			config["eq3"].elem_value, 
			config["eq4"].elem_value,
			config["eq5"].elem_value
		}

		generate_infinity_chest(separate_chests, gap, eq)

	elseif element.name == "power_feed_confirm" then
		local flasks_number = config["flasks_number"].text
		local flask_type = config["flask_type"].elem_value
		local min_charge = config["min_charge"].text
		local capacity = config["capacity"].text
		generate_power_feed(flasks_number, flask_type, min_charge, capacity)
	end

	if string.find(element.name, "_confirm") or element.name == "cancel" then
		element.parent.parent.children[3].visible = true -- shows back Apply button
		element.parent.destroy() -- removes confirm/Cancel buttons
	end
end
comfy_panel_tabs['Special games'] = {gui = create_special_games_panel, admin = true}

Event.add(defines.events.on_gui_click, on_gui_click)
Event.on_init(function()
	for k, v in pairs(valid_special_games) do
		global.active_special_games[k] = "false"
	end
end)

return Public
