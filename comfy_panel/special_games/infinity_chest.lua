local Color = require 'utils.color_presets'

local function generate_infinity_chest(separate_chests, operable, gap, eq)
    local surface = game.surfaces[global.bb_surface_name]
    local position_0 = {x = 0, y = -42}

    local objects = surface.find_entities_filtered {name = 'infinity-chest'}
    for _, object in pairs(objects) do object.destroy() end

    game.print("Special game Infinity chest is being generated!", Color.warning)
    if operable == "left" then
        operable = true
    else
        operable = false
    end

    if separate_chests == "left" then
        local chest = surface.create_entity {
            name = "infinity-chest",
            position = position_0,
            force = "neutral",
            fast_replace = true
        }
        chest.minable = false
        chest.operable = operable
        chest.destructible = false
        for i, v in ipairs(eq) do
            chest.set_infinity_container_filter(i, {name = v, index = i, count = game.item_prototypes[v].stack_size})
        end
        chest.clone {position = {position_0.x, -position_0.y}}

    elseif separate_chests == "right" then
        local k = gap + 1
        for i, v in ipairs(eq) do
            local chest = surface.create_entity {
                name = "infinity-chest",
                position = position_0,
                force = "neutral",
                fast_replace = true
            }
            chest.minable = false
            chest.operable = operable
            chest.destructible = false
            chest.set_infinity_container_filter(i, {name = v, index = i, count = game.item_prototypes[v].stack_size})
            chest.clone {position = {position_0.x, -position_0.y}}
            position_0.x = position_0.x + (i * k)
            k = k * -1
        end
    end
    global.active_special_games["infinity_chest"] = true
end

local Public = {
    name = {type = "label", caption = "Infinity chest", tooltip = "Spawn infinity chests with given filters"},
    config = {
        [1] = {name = "eq1", type = "choose-elem-button", elem_type = "item"},
        [2] = {name = "eq2", type = "choose-elem-button", elem_type = "item"},
        [3] = {name = "eq3", type = "choose-elem-button", elem_type = "item"},
        [4] = {name = "eq4", type = "choose-elem-button", elem_type = "item"},
        [5] = {name = "eq5", type = "choose-elem-button", elem_type = "item"},
        [6] = {name = "eq6", type = "choose-elem-button", elem_type = "item"},
        [7] = {name = "eq7", type = "choose-elem-button", elem_type = "item"},
        [8] = {name = "separate_chests", type = "switch", switch_state = "right", tooltip = "Single chest / Multiple chests"},
        [9] = {name = "operable", type = "switch", switch_state = "right", tooltip = "Operable? Y / N"},
        [10] = {name = "label1", type = "label", caption = "Gap size"},
        [11] = {name = "gap", type = "textfield", text = "3", numeric = true, width = 40},
    },
    button = {name = "apply", type = "button", caption = "Apply"},
    generate = function (config, player)
        local separate_chests = config["separate_chests"].switch_state
        local operable = config["operable"].switch_state
        local gap = config["gap"].text
        local eq = {
            config["eq1"].elem_value, 
            config["eq2"].elem_value, 
            config["eq3"].elem_value, 
            config["eq4"].elem_value,
            config["eq5"].elem_value,
            config["eq6"].elem_value,
            config["eq7"].elem_value
        }

        generate_infinity_chest(separate_chests, operable, gap, eq)
    end,
}

return Public
