local Event = require('utils.event')
local Global = require('utils.global')
local Gui = require('utils.gui')
local Token = require('utils.token')
local _utils = require('utils.utils')

local Public = {}

-- == SETUP ===================================================================

local SECOND = 60
local MINUTE = 60 * SECOND
local HOUR = 60 * MINUTE
local DEFAULT_STARTING_TIME = 4 * MINUTE
local DEFAULT_INCREMENT = 10 * SECOND
local DEFAULT_FIRST = 'north'
local max = math.max
local floor = math.floor
local f = string.format
local gui_style = _utils.gui_style
local colors = {
    north = { r = 0.55, g = 0.55, b = 0.99 },
    south = { r = 0.99, g = 0.33, b = 0.33 },
}

local frame_name = Gui.uid_name()

local this = {
    enabled = false,
    paused = false,
    starting_time = DEFAULT_STARTING_TIME,
    increment = DEFAULT_INCREMENT,
    turn = DEFAULT_FIRST,
    north = {
        start = 0,
        remaining = 0,
    },
    south = {
        start = 0,
        remaining = 0,
    },
}
Global.register(this, function(tbl)
    this = tbl
end)

-- == CLOCK ===================================================================

---@param params
---@field starting_time? number, in ticks
---@field increment? number, in ticks
---@field first? string 'north'|'south', first team to start picking
Public.enable = function(params)
    params = params or {}

    this.starting_time = params.starting_time or DEFAULT_STARTING_TIME
    this.increment = params.increment or DEFAULT_INCREMENT
    this.turn = params.first or DEFAULT_FIRST
    this.north.start = game.tick
    this.south.start = game.tick
    this.north.remaining = this.starting_time
    this.south.remaining = this.starting_time

    assert(this.increment >= 0, 'Time increments can only be a positive time interval')
    assert(this.turn == 'north' or this.turn == 'south', 'Picking turns can only belong to either north or south side.')

    if not this.enabled then
        this.enabled = true
        Event.add_removable_nth_tick(SECOND, Public.on_nth_tick_token)
    end

    Public.draw_all()
end

Public.disable = function()
    this.north.start = 0
    this.south.start = 0
    this.north.remaining = 0
    this.south.remaining = 0

    if this.enabled then
        this.enabled = false
        Event.remove_removable_nth_tick(SECOND, Public.on_nth_tick_token)
    end

    Public.destroy_all()
end

Public.pause = function()
    this.paused = true
end

Public.unpause = function()
    this.paused = false
end

---@param side? string 'north'|'south', if not ptovided, it will automatically switch to next force
Public.switch_turn = function(side)
    this.turn = side or (this.side == 'north' and 'south' or 'north')

    assert(this.turn == 'north' or this.turn == 'south', 'Picking turns can only belong to either north or south side.')

    this[this.turn].remaining = this[this.turn].remaining + this.increment
end

local on_nth_tick = function()
    if not this.enabled or this.paused then
        return
    end

    this[this.turn].remaining = max(0, this[this.turn].remaining - SECOND)
    Public.update_all()
end

Public.on_nth_tick_token = Token.register(on_nth_tick)

-- == GUI =====================================================================

---@param player LuaPlayer
Public.draw = function(player)
    if not (player and player.valid) then
        return
    end

    local frame = player.gui.screen[frame_name]
    if frame and frame.valid then
        return frame
    end

    local data = {}
    frame = player.gui.screen.add({
        type = 'frame',
        name = frame_name,
        style = 'slot_window_frame',
        direction = 'vertical',
    })
    gui_style(frame, { padding = 2 })
    frame.location = { x = 244, y = 314 }

    local flow = frame.add({ type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' })
    local inner_frame = flow.add({
        type = 'frame',
        name = 'inner_frame',
        style = 'inside_shallow_frame_packed',
        direction = 'vertical',
    })

    local subheader = inner_frame.add({ type = 'frame', name = 'subheader', style = 'subheader_frame' })
    gui_style(subheader, { horizontally_squashable = true, horizontally_stretchable = true, maximal_height = 40 })

    local subheader_flow = subheader.add({ type = 'flow', direction = 'horizontal' })
    gui_style(subheader_flow, { horizontal_align = 'center', horizontally_stretchable = true })

    local title = subheader_flow.add({ type = 'label', caption = 'Draft timer' })
    gui_style(title, { font = 'default-semibold', font_color = { 225, 225, 225 }, left_margin = 4 })
    data.title = title

    local canvas = inner_frame.add({ type = 'frame', direction = 'horizontal', style = 'mod_gui_inside_deep_frame' })

    local dragger = canvas.add({ type = 'empty-widget', style = 'draggable_space', ignored_by_interaction = false })
    dragger.drag_target = frame
    gui_style(dragger, { vertically_stretchable = true, width = 8, margin = 0 })

    local function render_side(parent, name)
        local side = canvas.add({ type = 'flow', direction = 'vertical' })
        gui_style(side, { horizontal_align = 'center', padding = 6 })

        local label =
            side.add({ type = 'label', caption = (name == 'north') and 'North' or 'South', style = 'caption_label' })
        gui_style(label, { font_color = colors[name] })

        local timer = side.add({ type = 'label', caption = '---' })
        gui_style(timer, { font = 'default-semibold' })

        return timer
    end

    data.north = render_side(canvas, 'north')
    canvas.add({ type = 'line', direction = 'vertical', style = 'dark_line' })
    data.south = render_side(canvas, 'south')

    Gui.set_data(frame, data)
    return frame
end

Public.draw_all = function()
    for _, player in pairs(game.connected_players) do
        Public.draw(player)
    end
end

---@param player LuaPlayer
Public.destroy = function(player)
    if not (player and player.valid) then
        return
    end

    local frame = player.gui.screen[frame_name]
    if frame then
        Gui.destroy(frame)
    end
end

Public.destroy_all = function()
    for _, player in pairs(game.players) do
        Public.destroy(player)
    end
end

Public.update_all = function()
    local tooltip = { 'gui.blitz_clock_tooltip', Public.format(this.starting_time), Public.format(this.increment) }
    local north_time = Public.format(Public.get_time('north'))
    local south_time = Public.format(Public.get_time('south'))

    for _, player in pairs(game.players) do
        local frame = Public.draw(player)
        local data = Gui.get_data(frame)
        data.north.caption = north_time
        data.south.caption = south_time
        data.title.tooltip = tooltip
    end
end

-- == UTILS ===================================================================

Public.get = function(key)
    if this[key] then
        return this[key]
    end
end

---@param side? string 'north'|'south', if not provided, the current turn force will be used instead
Public.get_time = function(side)
    side = side or this.turn
    return this[side].remaining
end

---@param ticks number
Public.format = function(ticks)
    local seconds = floor(ticks / SECOND)
    local mins = floor(seconds / SECOND)
    local secs = floor(seconds - mins * SECOND)

    return { 'gui.blitz_clock_caption', f('%02d', mins), f('%02d', secs) }
end

---@param ticks number
Public.change_time = function(ticks)
    this.north.remaining = max(0, this.north.remaining + ticks)
    this.south.remaining = max(0, this.south.remaining + ticks)
end

-- ============================================================================

return Public
