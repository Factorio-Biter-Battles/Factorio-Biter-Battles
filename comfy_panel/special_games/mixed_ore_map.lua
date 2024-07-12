local Color = require 'utils.color_presets'

local function generate_mixed_ore_map(type, size)
    if type then
        if not size then
            -- size not specified, set default values
            if type == 1 then
                size = 9
            elseif type == 2 then
                size = 5
            elseif type == 4 then
                size = 4
            elseif type == 5 then
                size = 7
            end
        end
        if type == 1 and size > 10 then
            size = 10
        end
        global.next_special_games["mixed_ore_map"] = true
        global.next_special_games_variables["mixed_ore_map"] = {
            type = type,
            size = size
        }

        game.print("Special game Mixed ore map is being scheduled. The special game will start after restarting the map!", Color.warning)
    end
end

local Public = {
    name = {type = "label", caption = "Mixed ore map", tooltip = "Covers the entire map with mixed ore. Takes effect after map restart"},
    config = {
        [1] = {name = "label1", type = "label", caption = "Type"},
        [2] = {name = "type1", type = "drop-down", items = {"Mixed ore", "Checkerboard", "Vertical lines", "Patches", "Dots"}},
        [3] = {name = "label2", type = "label", caption = "Size"},
        [4] = {name = "size", type = "textfield", text = "", numeric = true, width = 40, tooltip = "Live empty for default"
            .. "\nFor a Mixed ore, a higher value means lower features. Value range from 1 to 10, Default 9."
            .. "\nFor Checkerboard its the size of the cell. Default 5"
            .. "\nFor Patches its the size of the patches. Value range from 1 to 10, Default 4."
            .. "\nFor Dots its the distance between dots. Value range from 0 to infinity, Default 7. set 0 to not have any ore."
        },
    },
    button = {name = "apply", type = "button", caption = "Apply"},
    generate = function (config, player)
        local type = tonumber(config["type1"].selected_index)
        local size = tonumber(config["size"].text)

        generate_mixed_ore_map(type, size)
    end,
}

return Public
