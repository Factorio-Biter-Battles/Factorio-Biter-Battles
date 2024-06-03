local Event = require 'utils.event'

local closable_frame = {}

---@param player LuaPlayer
---@param name string
---@param caption LocalisedString
---@param close_tooltip LocalisedString? @Additional string that will be showed before "gui.close-instruction" in the close button tooltip.
---@param no_dragger boolean? @If true, the dragger will not be added. Useful for really thin frames. Defaults to false.
---@return LuaGuiElement
function closable_frame.create_closable_frame(player, name, caption, close_tooltip, no_dragger)
	local frame = player.gui.screen.add({type = "frame", name = name, direction = "vertical"})
    frame.auto_center = true
	player.opened = frame

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

---@param event EventData.on_gui_closed
local function on_gui_closed(event)
	local element = event.element
	if event.gui_type ~= defines.gui_type.custom or not element or element.type ~= "frame" then return end
	element.destroy()
end

---@param event EventData.on_gui_click
local function on_gui_click(event)
    if event.element.name ~= "closable_frame_close" then return end
    event.element.parent.parent.destroy()
end

Event.add(defines.events.on_gui_closed, on_gui_closed)
Event.add(defines.events.on_gui_click, on_gui_click)

return closable_frame