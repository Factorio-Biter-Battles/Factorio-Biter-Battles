local flui = require "utils.ui.gui-lite"

local blocks = {}

---@class ui.IconSetPartial
---@field default SpritePath
---@field hovered? SpritePath
---@field clicked? SpritePath

---@class ui.IconSet
---@field default SpritePath
---@field hovered SpritePath
---@field clicked SpritePath


---Turn a partial IconSet into a completed IconSet.
---@param base ui.IconSetPartial | ui.IconSet
---@return ui.IconSet
local function fill_icon_set(base)
    ---@type ui.IconSet
    return {
        default = base.default,
        hovered = base.hovered or base.default,
        clicked = base.clicked or base.hovered or base.default
    }
end

---@param target GuiElemDef
---@param element GuiElemDef
local function add(target, element)
    if target[1] then
        -- array-mode children.
        target[#target + 1] = element
    else
        -- object-mode children. default.
        target.children = target.children or {}
        target.children[#target.children + 1] = element
    end
    return element
end

---Label element.
---@param text string
---@param style? string
---@param name? string
---@return GuiElemDef
function blocks.label(text, style, name)
    ---@type GuiElemDef
    return {
        type = "label",
        caption = text,
        style = style,
        name = name
    }
end

---Vertical orientation frame element with style.
---@param style_name string
---@param name? string
---@return GuiElemDef
function blocks.vframe(style_name, name)
    ---@type GuiElemDef
    return {
        type = "frame",
        style = style_name,
        direction = "vertical",
        name = name
    }
end

---Horizontal orientation frame element with style.
---@param style_name string
---@param name? string
---@return GuiElemDef
function blocks.hframe(style_name, name)
    ---@type GuiElemDef
    return {
        type = "frame",
        style = style_name,
        direction = "horizontal",
        name = name
    }
end

---Vertical orientation flow element.
---@param name? string
---@return GuiElemDef
function blocks.vflow(name)
    ---@type GuiElemDef
    return {
        type = "flow",
        direction = "vertical",
        name = name
    }
end

---Horizontal orientation flow element.
---@param name? string
---@return GuiElemDef
function blocks.hflow(name)
    ---@type GuiElemDef
    return {
        type = "flow",
        direction = "horizontal",
        name = name
    }
end

---Scroll pane.
---@param options { h?: ScrollPolicy, v?: ScrollPolicy, name?: string }
---@return GuiElemDef
function blocks.scroll(options)
    ---@type GuiElemDef
    return {
        type = "scroll-pane",
        name = options.name,
        horizontal_scroll_policy = options.h,
        vertical_scroll_policy = options.v
    }
end

---Table element.
---@param columns integer
---@param name? string
---@return GuiElemDef
function blocks.table(columns, name)
    ---@type GuiElemDef
    return {
        type = "table",
        column_count = columns,
        name = name
    }
end

---Frame action button. Goes in the titlebar of the window.
---@param name string
---@param icon SpritePath | ui.IconSetPartial
---@return GuiElemDef
function blocks.frame_action_button(name, icon)
    ---@type ui.IconSet
    local icon_set
    if type(icon) == "table" then
        icon_set = fill_icon_set(icon)
    else
        icon_set = {
            default = icon
        }
    end

    ---@type GuiElemDef
    return {
        type = "sprite-button",
        style = "frame_action_button",
        name = name,
        sprite = icon_set.default,
        hovered_sprite = icon_set.hovered,
        clicked_sprite = icon_set.clicked
    }
end

---Basic window with title and variable number of action buttons.
function blocks.GenericWindow(name, caption, fabs)
    ---@type GuiElemDef[]
    local titlebar = {
        {
            type = "label",
            style = "frame_title",
            caption = caption,
            ignored_by_interaction = true,
            style_mods = {
                vertically_stretchable = true,
                horizontally_squashable = true
            }
        },
        {
            type = "empty-widget",
            style = "draggable_space_header",
            ignored_by_interaction = true,
            style_mods = {
                horizontally_stretchable = true,
                vertically_stretchable = true,
                height = 24,
                natural_height = 24
            }
        }
    }
    for _, v in ipairs(fabs) do titlebar[#titlebar + 1] = v end

    ---@type GuiElemDef
    return {
        type = "frame",
        name = name,
        direction = "vertical",
        children = {
            {
                type = "flow",
                name = "titlebar",
                direction = "horizontal",
                style_mods = {
                    horizontally_stretchable = true,
                    horizontal_spacing = 8,
                    vertically_stretchable = true,
                },
                children = titlebar,
                -- drag_target is resolved by flib, not vanilla.
                drag_target = name
            }
        },
        extra = {
            auto_center = true,
        }
    }
end

---@param evt GuiEventData
local function close_button_handler(evt)
    local parent = evt.element and evt.element.parent and evt.element.parent.parent
    if parent and parent.valid then parent.destroy() end
end

flui.add_handlers {
    generic_close_button = close_button_handler
}

---Window with a close button.
---@param name string
---@param caption string
---@return GuiElemDef
function blocks.ClosableWindow(name, caption)
    local button = blocks.frame_action_button("close", {
        default = "utility/close_white",
        hovered = "utility/close_black"
    })
    button.handler = close_button_handler
    local base = blocks.GenericWindow(name, caption, { button })
    return base
end

---@class ui.fcomponents
return {
    blocks = blocks,
    add = add
}