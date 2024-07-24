local Token = require 'utils.token'
local Event = require 'utils.event'
local Global = require 'utils.global'
local mod_gui = require '__core__/lualib/mod-gui'

local _utils = require 'utils.utils'
local gui_style = _utils.gui_style
local gui_themes = _utils.gui_themes
local top_button_style = _utils.top_button_style
local left_frame_style = _utils.left_frame_style

local tostring = tostring
local next = next

local Gui = {}

local data = {}
local element_map = {}

Gui.token =
    Global.register(
    {data = data, element_map = element_map},
    function(tbl)
        data = tbl.data
        element_map = tbl.element_map
    end
)

local top_elements = {}
local on_visible_handlers = {}
local on_pre_hidden_handlers = {}

function Gui.uid_name()
    return tostring(Token.uid())
end

function Gui.uid()
    return Token.uid()
end

-- Associates data with the LuaGuiElement. If data is nil then removes the data
function Gui.set_data(element, value)
    local player_index = element.player_index
    local values = data[player_index]

    if value == nil then
        if not values then
            return
        end

        values[element.index] = nil

        if next(values) == nil then
            data[player_index] = nil
        end
    else
        if not values then
            values = {}
            data[player_index] = values
        end

        values[element.index] = value
    end
end
local set_data = Gui.set_data

-- Gets the Associated data with this LuaGuiElement if any.
function Gui.get_data(element)
    local player_index = element.player_index

    local values = data[player_index]
    if not values then
        return nil
    end

    return values[element.index]
end

local remove_data_recursively
-- Removes data associated with LuaGuiElement and its children recursively.
function Gui.remove_data_recursively(element)
    set_data(element, nil)

    local children = element.children

    if not children then
        return
    end

    for _, child in next, children do
        if child.valid then
            remove_data_recursively(child)
        end
    end
end
remove_data_recursively = Gui.remove_data_recursively

local remove_children_data
function Gui.remove_children_data(element)
    local children = element.children

    if not children then
        return
    end

    for _, child in next, children do
        if child.valid then
            set_data(child, nil)
            remove_children_data(child)
        end
    end
end
remove_children_data = Gui.remove_children_data

function Gui.destroy(element)
    remove_data_recursively(element)
    element.destroy()
end

function Gui.clear(element)
    remove_children_data(element)
    element.clear()
end

---@param player LuaPlayer
function Gui.init_gui_style(player)
    local mod_gui_top_frame = player.gui.top.mod_gui_top_frame
    gui_style(mod_gui_top_frame, { padding = 2 })

    --local mod_gui_inner_frame = mod_gui_top_frame.mod_gui_inner_frame
    --gui_style(mod_gui_inner_frame, { })
end

---@param player LuaPlayer
function Gui.get_top_index(player)
    local flow = mod_gui.get_button_flow(player)
    if flow.bb_toggle_statistics then
        return flow.bb_toggle_statistics.get_index_in_parent() 
    end
    return
end

---@param player LuaPlayer
---@param element_name string
---@return LuaGuiElement|nil
function Gui.get_top_element(player, element_name)
    -- player.gui.top.mod_gui_top_frame.mod_gui_inner_frame
	return mod_gui.get_button_flow(player)[element_name]
end

---@param player LuaPlayer
---@param frame LuaGuiElement|table
---@param style_name string
---@return LuaGuiElement
function Gui.add_top_element(player, frame, style_name)
    local element = mod_gui.get_button_flow(player)[frame.name]
	if element and element.valid then
        return element
	end
	if (frame.type == 'button' or frame.type == 'sprite-button') and frame.style == nil then
        frame.style = style_name or gui_themes[1].type
	end
	element = mod_gui.get_button_flow(player).add(frame)
    if element.type == 'button' or element.type == 'sprite-button' then
        gui_style(element, top_button_style())
    end
    return element
end

local backup_attributes = { 'minimal_width', 'maximal_width', 'font_color', 'font' }
---@param player LuaPlayer
---@param new_style string
function Gui.restyle_top_elements(player, new_style)
    for _, ele in pairs(mod_gui.get_button_flow(player).children) do
        if ele.type == 'button' or ele.type == 'sprite-button' then
            local custom_styles = {}
            for _, attr in pairs(backup_attributes) do
                custom_styles[attr] = ele.style[attr]
            end
            ele.style = new_style
            gui_style(ele, top_button_style())
            gui_style(ele, custom_styles)
        end
    end
end

---@param player LuaPlayer
---@param element_name string
---@return LuaGuiElement|nil
function Gui.get_left_element(player, element_name)
    return mod_gui.get_frame_flow(player)[element_name]
end

---@param player LuaPlayer
---@param frame LuaGuiElement|table
---@return LuaGuiElement
function Gui.add_left_element(player, frame)
    local element = mod_gui.get_frame_flow(player)[frame.name]
    if element and element.valid then
        return element
    end
    element = mod_gui.get_frame_flow(player).add(frame)
    if element.type == 'frame' then
        gui_style(element, left_frame_style())
    end
    return element
end

---@param parent LuaGuiElement
---@param direction? string, default: horizontal
---@return LuaGuiElement
function Gui.add_pusher(parent, direction)
    if not (parent and parent.valid) then
        return
    end
    local pusher = parent.add { type = 'empty-widget' }
    pusher.ignored_by_interaction = true
    gui_style(pusher, { 
        top_margin = 0,
        bottom_margin = 0,
        left_margin = 0,
        right_margin = 0,
    })
    if direction == 'vertical' then
        pusher.style.vertically_stretchable = true
    else
        pusher.style.horizontally_stretchable = true
    end
    return pusher
end

function Gui.get_child_recursively(element, child_name)
    if element.name == child_name then
        return element
    end

    for _, e in pairs(element.children) do
        if e.name == child_name then
            return element[child_name]
        end
    end

    local res
    for _, e in pairs(element.children) do
        local c = Gui.get_child_recursively(e, child_name)
        if c then
            res = c
            break
        end
    end
    return res
end

local function clear_invalid_data()
    for _, player in pairs(game.connected_players) do
        local player_index = player.index
        local values = data[player_index]
        if values then
            for _, element in next, values do
                if type(element) == 'table' then
                    for key, obj in next, element do
                        if type(obj) == 'table' and obj.valid ~= nil then
                            if not obj.valid then
                                element[key] = nil
                            end
                        end
                    end
                end
            end
        end
    end
end
Event.on_nth_tick(300, clear_invalid_data)

local function handler_factory(event_id)
    local handlers

    local function on_event(event)
        local element = event.element
        if not element or not element.valid then
            return
        end

        local handler = handlers[element.name]
        if not handler then
            return
        end

        local player = game.get_player(event.player_index)
        if not player or not player.valid then
            return
        end
        event.player = player

        handler(event)
    end

    return function(element_name, handler)
        if not handlers then
            handlers = {}
            Event.add(event_id, on_event)
        end

        handlers[element_name] = handler
    end
end

local function custom_handler_factory(handlers)
    return function(element_name, handler)
        handlers[element_name] = handler
    end
end

local function custom_raise(handlers, element, player)
    local handler = handlers[element.name]
    if not handler then
        return
    end

    handler({element = element, player = player})
end

-- Register a handler for the on_gui_checked_state_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_checked_state_changed = handler_factory(defines.events.on_gui_checked_state_changed)

-- Register a handler for the on_gui_click event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_click = handler_factory(defines.events.on_gui_click)

-- Register a handler for the on_gui_closed event for a custom LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_custom_close = handler_factory(defines.events.on_gui_closed)

-- Register a handler for the on_gui_elem_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_elem_changed = handler_factory(defines.events.on_gui_elem_changed)

-- Register a handler for the on_gui_selection_state_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_selection_state_changed = handler_factory(defines.events.on_gui_selection_state_changed)

-- Register a handler for the on_gui_text_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_text_changed = handler_factory(defines.events.on_gui_text_changed)

-- Register a handler for the on_gui_value_changed event for LuaGuiElements with element_name.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_value_changed = handler_factory(defines.events.on_gui_value_changed)

-- Register a handler for when the player shows the top LuaGuiElements with element_name.
-- Assuming the element_name has been added with Gui.allow_player_to_toggle_top_element_visibility.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_player_show_top = custom_handler_factory(on_visible_handlers)

-- Register a handler for when the player hides the top LuaGuiElements with element_name.
-- Assuming the element_name has been added with Gui.allow_player_to_toggle_top_element_visibility.
-- Can only have one handler per element name.
-- Guarantees that the element and the player are valid when calling the handler.
-- Adds a player field to the event table.
Gui.on_pre_player_hide_top = custom_handler_factory(on_pre_hidden_handlers)

return Gui
