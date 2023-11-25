--[[
local Public = {
    name = {type = "label", caption = "<Name displayed in gui>", tooltip = "<Short description of the mode"
    config = {
        list of all knobs, leavers and dials used to config your game
        [1] = {name = "<name of this element>" called in on_gui_click to set variables, type = "<type of this element>", any other parameters needed to define this element},
        [2] = {name = "example_1", type = "textfield", text = "200", numeric = true, width = 40},
        [3] = {name = "example_2", type = "checkbox", caption = "Some checkbox", state = false}
        [9] = {name = "example_custom_button_name", type = "button", caption = "Custom button", width = 60}
        NOTE all names should be unique in the scope of the game mode
    },
    button = {name = "apply", type = "button", caption = "Apply"}
    generate = function (config, player)
        -- Will be called when the apply button is clicked
    end,
    gui_click = function (element, config, player)
        if element.name == "example_custom_button_name" then
        -- if there are custom buttons in the special game config, add the handler code here
        end
    end
}

return Public
]]
