local Event = require 'utils.event'
local Color = require 'utils.color_presets'
local valid_special_games = {
	turtle = {
		name = "Turtle",
		config = {
			[1] = {name = "label1", type = "label", caption = "moat width"},
			[2] = {name = 'moat_width', type = "textfield", text = "3", numeric = true, width = 40},
			[3] = {name = "label2", type = "label", caption = "entrance width"},
			[4] = {name = 'entrance_width', type = "textfield", text = "20", numeric = true, width = 40},
			[5] = {name = "label3", type = "label", caption = "size x"},
			[6] = {name = 'size_x', type = "textfield", text = "200", numeric = true, width = 40},
			[7] = {name = "label4", type = "label", caption = "size y"},
			[8] = {name = 'size_y', type = "textfield", text = "200", numeric = true, width = 40}

		},
		button = {name = "turtle_apply", type = "button", caption = "Apply"}
	},
	infinity_chest = {
		name = "Infinity chest",
		config = {
			[1] = {name = "separate_chests", type = "checkbox", caption = "Separate chest for each item", state = false},
			[2] = {name = "eq1", type = "choose-elem-button", elem_type = "item"},
			[3] = {name = "eq2", type = "choose-elem-button", elem_type = "item"},
			[4] = {name = "eq3", type = "choose-elem-button", elem_type = "item"},
			[5] = {name = "eq4", type = "choose-elem-button", elem_type = "item"},
			[6] = {name = "eq5", type = "choose-elem-button", elem_type = "item"}
		},
		button = {name = "infinity_chest_apply", type = "button", caption = "Apply"}
	}
}

local function generate_turtle(moat_width, entrance_width, size_x, size_y)
	game.print("Special game turtle is being generated!", Color.warning)
	local surface = game.surfaces[global.bb_surface_name]
	local water_positions = {}
	local concrete_positions = {}
	local k = 1
	for i = 1, size_y + moat_width do
		for a = 0, moat_width do
			table.insert(water_positions, {name = "water", position = {x = (size_x / 2) + a, y = i}}) -- north
			table.insert(water_positions, {name = "water", position = {x = -(size_x / 2) - a, y = i}})
			table.insert(water_positions, {name = "water", position = {x = (size_x / 2) + a, y = -i}}) -- south
			table.insert(water_positions, {name = "water", position = {x = -(size_x / 2) - a, y = -i}})
		end
	end
	for i = 1, size_x do
		for a = 0, moat_width do
			table.insert(water_positions, {name = "water", position = {x = i - (size_x / 2), y = size_y + a}}) -- north 
			table.insert(water_positions, {name = "water", position = {x = i - (size_x / 2), y = -size_y - a}}) -- south
		end
	end

	for i = 1, entrance_width do
		for a = 0, moat_width + 6 do
			table.insert(concrete_positions,
			             {name = "refined-concrete", position = {x = i - (entrance_width / 2), y = size_y - 3 + a}}) -- north
			table.insert(concrete_positions,
			             {name = "refined-concrete", position = {x = i - (entrance_width / 2), y = -size_y + 3 - a}}) -- south
			k = k * -1
		end
	end
	surface.set_tiles(water_positions)
	surface.set_tiles(concrete_positions)

end

local function generate_infinity_chest(separate_chests, eq)
	local surface = game.surfaces[global.bb_surface_name]
	local position_0 = {x = 0, y = -42}

	local objects = surface.find_entities_filtered {name = 'infinity-chest'}
	for _, object in pairs(objects) do object.destroy() end

	game.print("Special game Infinity chest is being generated!", Color.warning)

	if separate_chests == false then
		local chest = surface.create_entity {
			name = "infinity-chest",
			position = position_0,
			force = "neutral",
			fast_replace = true
		}
		chest.minable = false
		chest.operable = false
		chest.destructible = false
		for i, v in ipairs(eq) do
			chest.set_infinity_container_filter(i, {name = v, index = i, count = game.item_prototypes[v].stack_size})
		end
		chest.clone {position = {position_0.x, -position_0.y}}

	elseif separate_chests == true then
		local k = 1
		for i, v in ipairs(eq) do
			game.print(i)
			local chest = surface.create_entity {
				name = "infinity-chest",
				position = position_0,
				force = "neutral",
				fast_replace = true
			}
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

--[[
	Gui structure
	Every element is taken from table valid_special_games

	frame - from comfy_panel_tabs
		label - title, description of panel
		
		a - frame containig a single special game, used mostly for astetic purposes
			table - table with 3 columns
				label - name of the mode
				config - flow containing all the config for this mode, used mostly for astetic purposes, so that all settings are in the 2nd column
					labels, textfields, checkboxes etc - used for configuration of the mode. Every setting used by generate_<mode>() should be picked manually in on_gui_clicked()
				button - name from valid_special_games, used for calling generate_<name>()

		Example for turtle: 

		a{type = "frame"}
			table{name = "turtle", type = "table"}
				label{caption = "Turtle"}
				config{name = "turtle", type = "flow"}
					label{name = "label1", type = "label"}
					textfield{name = "moat_width", type = "textfield"}
					...
				button{name = "turtle_apply", type = "button"}
]]

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
			config.add {
				name = i.name,
				type = i.type,
				caption = i.caption,
				text = i.text,
				numeric = i.numeric,
				item = i.item,
				state = i.state,
				elem_type = i.elem_type
				--[[ Add here any new parameters required by your config elements ]]
			}
			config[i.name].style.width = i.width
		end
		table.add {name = v.button.name, type = v.button.type, caption = v.button.caption}
	end
end)

local function on_gui_click(event)
	local element = event.element
	if not element.type == "button" then return end
	if element.name == "turtle_apply" then
		local config = element.parent["turtle_config"]
		local moat_width = config["moat_width"].text
		local entrance_width = config["entrance_width"].text
		local size_x = config["size_x"].text
		local size_y = config["size_y"].text

		generate_turtle(moat_width, entrance_width, size_x, size_y)

	elseif element.name == "infinity_chest_apply" then
		local config = element.parent["infinity_chest_config"]
		local separate_chests = config["separate_chests"].state

		local eq = {
			config["eq1"].elem_value, 
			config["eq2"].elem_value, 
			config["eq3"].elem_value, 
			config["eq4"].elem_value,
   			config["eq5"].elem_value
		}

		generate_infinity_chest(separate_chests, eq)
		
	end
end
comfy_panel_tabs['Special games'] = {gui = create_special_games_panel, admin = true}

Event.add(defines.events.on_gui_click, on_gui_click)

