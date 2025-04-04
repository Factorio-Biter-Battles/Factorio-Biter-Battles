--Adds a small gui to quick select an icon tag for your character - mewmew

local Event = require('utils.event')
local Gui = require('utils.gui')
local gui_style = require('utils.utils').gui_style
local mod_gui = require('__core__/lualib/mod-gui')

local Public = {}

local icons = {
    { '[img=item/electric-mining-drill]', 'item/electric-mining-drill', 'Miner' },
    { '[img=item/stone-furnace]', 'item/stone-furnace', 'Smeltery' },
    { '[img=item/big-electric-pole]', 'item/big-electric-pole', 'Power' },
    { '[img=item/assembling-machine-1]', 'item/assembling-machine-1', 'Production' },
    { '[img=item/chemical-science-pack]', 'item/chemical-science-pack', 'Science' },
    { '[img=item/locomotive]', 'item/locomotive', 'Trainman' },
    { '[img=fluid/crude-oil]', 'fluid/crude-oil', 'Oil processing' },
    { '[img=item/submachine-gun]', 'item/submachine-gun', 'Trooper' },
    { '[img=item/stone-wall]', 'item/stone-wall', 'Fortifications' },
    { '[img=item/repair-pack]', 'item/repair-pack', 'Support' },
}

local checks = {
    'minimal_width',
    'left_margin',
    'right_margin',
}

local function get_x_offset(player)
    local x = 24
    for _, element in pairs(mod_gui.get_button_flow(player).children) do
        if element.name == 'simple_tag' then
            break
        end
        local style = element.style
        for _, v in pairs(checks) do
            if style[v] then
                x = x + style[v]
            end
        end
    end
    return x
end

function Public.create_simple_tags_button(player)
    local button = Gui.add_top_element(player, {
        type = 'sprite-button',
        name = 'simple_tag',
        sprite = 'utility/bookmark',
        tooltip = '[font=default-bold]Tags[/font] - Assign yourself to a group tag',
    })
end

local function draw_screen_gui(player)
    local frame = player.gui.screen.simple_tag_frame
    if player.gui.screen.simple_tag_frame then
        frame.destroy()
        return
    end

    local frame = player.gui.screen.add({
        type = 'frame',
        name = 'simple_tag_frame',
        direction = 'vertical',
    })
    frame.location = { x = get_x_offset(player) * player.display_scale - 2, y = 54 * player.display_scale }
    frame.style.padding = -2
    frame.style.maximal_width = 42

    for _, v in pairs(icons) do
        local button = frame.add({ type = 'sprite-button', name = v[1], sprite = v[2], tooltip = v[3] })
        gui_style(button, { width = 38, height = 38, padding = -2 })
    end

    local tag = player.tag
    if not tag then
        return
    end
    if string.len(tag) < 8 then
        return
    end
    local clear_tag_element = frame[tag]
    if not clear_tag_element then
        return
    end
    clear_tag_element.sprite = 'utility/close'
    clear_tag_element.tooltip = 'Clear Tag'
end

local function on_gui_click(event)
    local element = event.element
    if not element then
        return
    end
    if not element.valid then
        return
    end

    local name = element.name
    if name == 'simple_tag' then
        local player = game.get_player(event.player_index)
        draw_screen_gui(player)
        return
    end

    local parent = element.parent
    if not parent then
        return
    end
    if not parent.valid then
        return
    end
    if not parent.name then
        return
    end
    if parent.name ~= 'simple_tag_frame' then
        return
    end

    local player = game.get_player(event.player_index)
    local selected_tag = element.name

    if player.tag == selected_tag then
        selected_tag = ''
    end
    player.tag = selected_tag
    parent.destroy()
end

Event.add(defines.events.on_gui_click, on_gui_click)

return Public
