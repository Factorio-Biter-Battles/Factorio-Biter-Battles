local Event = require 'utils.event'

local closable_frame = {}

---Returns true if a main_closable_frame is opened.
---@param player LuaPlayer
---@return boolean
function closable_frame.any_main_closable_frame(player)
	if global.closable_frame.closable_frames and
        global.closable_frame.closable_frames[player.index] and
        global.closable_frame.closable_frames[player.index].main
    then
        return true
    end
    return false
end

---Returns the main_closable_frame if one is opened, otherwise nil.
---@param player LuaPlayer
---@return LuaGuiElement?
function closable_frame.get_main_closable_frame(player)
    if closable_frame.any_main_closable_frame(player) then
        return global.closable_frame.closable_frames[player.index].main
    end
    return nil
end

---@param player LuaPlayer
function closable_frame.close_all(player)
    local frames = global.closable_frame.closable_frames[player.index]

    if not frames then return end
    if frames.main then
        frames.main.destroy()
        frames.main = nil
    end
    if frames.secondary then
        frames.secondary.destroy()
        frames.secondary = nil
    end
end

---@param player LuaPlayer
function closable_frame.close_secondary(player)
    local frames = global.closable_frame.closable_frames[player.index]

    if not frames then return end
    if frames.secondary then
        frames.secondary.destroy()
        frames.secondary = nil
    end
end

---@param player LuaPlayer
---@param name string
---@param caption LocalisedString
---@param close_tooltip LocalisedString? Additional string that will be showed before "gui.close-instruction" in the close button tooltip.
---@param no_dragger boolean? If true, the dragger will not be added. Useful for really thin frames. Defaults to false.
---@return LuaGuiElement
local function create_draggable_frame(player, name, caption, close_tooltip, no_dragger)
	local frame = player.gui.screen.add({type = "frame", name = name, direction = "vertical"})
    frame.auto_center = true

	local flow = frame.add({ type = "flow", direction = "horizontal" })

	local title = flow.add({ type = "label", caption = caption, style = "frame_title" })
	title.drag_target = frame

    local dragger = flow.add({ type = "empty-widget", style = "draggable_space_header" })
	dragger.drag_target = frame
    dragger.style.horizontally_stretchable = true
    dragger.style.height = 24
    if no_dragger then
        dragger.style.height = 0 -- Actually we need to keep the dragger, to push the button to the right
    end

	flow.add({
        type = "sprite-button", name = "closable_frame_close",
        sprite = "utility/close_white", clicked_sprite = "utility/close_black",
        style = "close_button", tooltip = {"", close_tooltip and close_tooltip .. " " or "", {"gui.close-instruction"}}
    })

	return frame
end

---Only works if a main_closable_frame is currently exists. This should be used to things like, for example, the quick-bar filter selector,
---where you have a main GUI (the quick-bar) and when you click on something in that GUI, another GUI open up (the filter selector).
---Creates a frame in the gui.screen that can be closed with the esc and E keys and closes the previously opened secondary closable frame, if any.
---If the main closable frame is closed, the secondary will also be closed if the main_closable_frame is closed.
---@param player LuaPlayer
---@param name string
---@param caption LocalisedString
---@param close_tooltip LocalisedString? Additional string that will be showed before "gui.close-instruction" in the close button tooltip.
---@param no_dragger boolean? If true, the dragger will not be added. Useful for really thin frames. Defaults to false.
---@return LuaGuiElement?
function closable_frame.create_secondary_closable_frame(player, name, caption, close_tooltip, no_dragger)
    if not closable_frame.any_main_closable_frame(player) then return nil end
    closable_frame.close_secondary(player)

    local frame = create_draggable_frame(player, name, caption, close_tooltip, no_dragger)

    global.closable_frame.dont_close = true
    player.opened = frame
    global.closable_frame.dont_close = false
    global.closable_frame.closable_frames[player.index].secondary = frame

    return frame
end

---Creates a frame in the gui.screen that can be closed with the esc and E keys and closes the previously opened main closable frame, if any.
---@param player LuaPlayer
---@param name string
---@param caption LocalisedString
---@param close_tooltip LocalisedString? Additional string that will be showed before "gui.close-instruction" in the close button tooltip.
---@param no_dragger boolean? If true, the dragger will not be added. Useful for really thin frames. Defaults to false.
---@return LuaGuiElement
function closable_frame.create_main_closable_frame(player, name, caption, close_tooltip, no_dragger)
    local frame = create_draggable_frame(player, name, caption, close_tooltip, no_dragger)

	player.opened = frame
    global.closable_frame.closable_frames[player.index].main = frame

    return frame
end

---@param event EventData.on_gui_closed
local function on_gui_closed(event)
    if global.closable_frame.dont_close == true then return end

    local player = game.get_player(event.player_index)
    if not player or not closable_frame.any_main_closable_frame(player) then return end

    local element = event.element
    local frames = global.closable_frame.closable_frames[event.player_index]
    if element == frames.main then
        closable_frame.close_all(player)
        return
    end

    if element == frames.secondary then
        closable_frame.close_secondary(player)
        player.opened = frames.main
    end
end

---@param event EventData.on_gui_click
local function on_gui_click(event)
    if event.element.name == "closable_frame_close" then
        game.get_player(event.player_index).opened = nil

        --- this is not absolutely needed, it's a security 
        if event.element.valid then
            event.element.parent.parent.destroy()
        end
    end
end

---@param event EventData.on_player_joined_game
local function on_player_joined_game(event)
    global.closable_frame.closable_frames[event.player_index] = {}
end

---@param event EventData.on_player_left_game
local function on_player_left_game(event)
    ---@diagnostic disable-next-line: param-type-mismatch
    closable_frame.close_all(game.get_player(event.player_index))
    global.closable_frame.closable_frames[event.player_index] = nil
end

local function on_init()
    global.closable_frame = {}

    ---If set to true, the next on_gui_closed will set it back to true and do nothing.
    ---@type boolean
    global.closable_frame.dont_close = false

    ---@type { [int]: { main: LuaGuiElement?, secondary: LuaGuiElement? } }
    global.closable_frame.closable_frames = {}
end

Event.add(defines.events.on_gui_closed, on_gui_closed)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game, on_player_left_game)
Event.on_init(on_init)

return closable_frame