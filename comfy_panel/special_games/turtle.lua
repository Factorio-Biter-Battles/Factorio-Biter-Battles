local Color = require 'utils.color_presets'

local function generate_turtle(moat_width, entrance_width, size_x, size_y)
	game.print("Special game turtle is being generated!", Color.warning)
	local surface = game.surfaces[global.bb_surface_name]
	local water_positions = {}
	local concrete_positions = {}
	local landfill_positions = {}

	for i = 0, size_y + moat_width do -- vertical canals
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
			table.insert(concrete_positions,
			             {name = "refined-concrete", position = {x = -entrance_width / 2 + i, y = size_y - 3 + a}})
			table.insert(concrete_positions,
			             {name = "refined-concrete", position = {x = -entrance_width / 2 + i, y = -size_y + 2 - a}})
			table.insert(landfill_positions, {name = "landfill", position = {x = -entrance_width / 2 + i, y = size_y - 3 + a}})
			table.insert(landfill_positions, {name = "landfill", position = {x = -entrance_width / 2 + i, y = -size_y + 2 - a}})
		end
	end

	surface.set_tiles(water_positions)
	surface.set_tiles(landfill_positions)
	surface.set_tiles(concrete_positions)
	global.active_special_games["turtle"] = true
end

local Public = {
    name = {type = "label", caption = "Turtle", tooltip = "Generate moat with given dimensions around the spawn"},
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
    button = {name = "apply", type = "button", caption = "Apply"},
    generate = function (config, player)
		local moat_width = config["moat_width"].text
		local entrance_width = config["entrance_width"].text
		local size_x = config["size_x"].text
		local size_y = config["size_y"].text

		generate_turtle(moat_width, entrance_width, size_x, size_y)
    end,
    gui_click = function (element, config, player)
        if element.name == "chart_turtle" then
            local moat_width = config["moat_width"].text
            local size_x = config["size_x"].text
            local size_y = config["size_y"].text

            game.forces["spectator"].chart(game.surfaces[global.bb_surface_name], {
                {-size_x / 2 - moat_width, -size_y - moat_width}, {size_x / 2 + moat_width, size_y + moat_width}
            })
        end
    end,
}

return Public
