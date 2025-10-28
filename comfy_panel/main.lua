--[[
Comfy Panel

To add a tab, insert into the "comfy_panel_tabs" table.

Example: comfy_panel_tabs["mapscores"] = {gui = draw_map_scores, admin = false}
if admin = true, then tab is visible only for admins (usable for map-specific settings)

draw_map_scores would be a function with the player and the frame as arguments

]]
require('utils.profiler')
local event = require('utils.event')
local Gui = require('utils.gui')
local gui_style = require('utils.utils').gui_style
local closable_frame = require('utils.ui.closable_frame')
comfy_panel_tabs = {}

local Public = {}

function Public.get_tabs(data)
    return comfy_panel_tabs
end

function Public.comfy_panel_get_active_frame(player)
    if not player.gui.screen.comfy_panel then
        return false
    end
    local tabbed_pane = player.gui.screen.comfy_panel.comfy_panel_inside.tabbed_pane
    if not tabbed_pane.selected_tab_index then
        return tabbed_pane.tabs[1].content
    end
    return tabbed_pane.tabs[tabbed_pane.selected_tab_index].content
end

function Public.comfy_panel_refresh_active_tab(player)
    local frame = Public.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end
    comfy_panel_tabs[frame.name].gui(player, frame)
end

---@param player LuaPlayer
function Public.comfy_panel_add_top_element(player)
    if Gui.get_top_element(player, 'comfy_panel_top_button') then
        return
    end

    Gui.init_gui_style(player)

    local toggle = Gui.add_top_element(player, {
        type = 'sprite-button',
        name = 'main_toggle_button_name',
        sprite = 'utility/preset',
        tooltip = 'Click to hide top buttons!',
        index = 1,
    })
    gui_style(toggle, { minimal_width = 15, maximal_width = 15 })

    local button = Gui.add_top_element(player, {
        type = 'sprite-button',
        name = 'comfy_panel_top_button',
        sprite = 'utility/change_recipe',
        tooltip = { 'gui.comfy_panel_top_button' },
    })
end

local gui_toggle_blacklist = {
    ['reroll_frame'] = true,
    ['bb_frame_statistics'] = true,
    ['suspend_frame'] = true,
    ['main_toggle_button_name'] = true,
}

Gui.on_click('main_toggle_button_name', function(event)
    local button = event.element
    local player = event.player
    local mod_gui_inner_frame = Gui.get_top_element(player, 'main_toggle_button_name').parent

    local default = button.sprite == 'utility/preset'
    button.sprite = default and 'utility/expand_dots' or 'utility/preset'
    button.tooltip = default and 'Click to show top buttons!' or 'Click to hide top buttons!'

    for _, ele in pairs(mod_gui_inner_frame.children) do
        if ele and ele.valid and not gui_toggle_blacklist[ele.name] then
            ele.visible = not default
        end
    end
    for _, position in pairs({ 'screen', 'left', 'center' }) do
        for _, ele in pairs(player.gui[position].children) do
            if ele and ele.valid and ele.name ~= 'bb_floating_shortcuts' then
                ele.visible = not default
            end
        end
    end
end)

local function main_frame(player)
    local tabs = comfy_panel_tabs

    local frame_ = closable_frame.create_main_closable_frame(player, 'comfy_panel', { 'gui.comfy_panel_top_button' })
    local frame = frame_.add({ type = 'frame', name = 'comfy_panel_inside', style = 'inside_deep_frame' })

    local tabbed_pane = frame.add({ type = 'tabbed-pane', name = 'tabbed_pane' })

    for name, func in pairs(tabs) do
        if func.admin == true then
            if is_admin(player) then
                local tab = tabbed_pane.add({ type = 'tab', caption = name })
                local flow = tabbed_pane.add({ type = 'flow', name = name, direction = 'vertical' })
                flow.style.horizontally_stretchable = true
                flow.style.width = 863
                flow.style.height = 480
                tabbed_pane.add_tab(tab, flow)
            end
        else
            local tab = tabbed_pane.add({ type = 'tab', caption = name })
            local flow = tabbed_pane.add({ type = 'flow', name = name, direction = 'vertical' })
            flow.style.horizontally_stretchable = true
            flow.style.width = 863
            flow.style.height = 480
            tabbed_pane.add_tab(tab, flow)
        end
    end

    for _, child in pairs(tabbed_pane.children) do
        child.style.padding = 8
        child.style.left_padding = 2
        child.style.right_padding = 2
    end

    Public.comfy_panel_refresh_active_tab(player)
end

local function on_gui_click(event)
    if not event.element then
        return
    end
    if not event.element.valid then
        return
    end
    local player = game.get_player(event.player_index)

    if event.element.name == 'comfy_panel_top_button' then
        if player.gui.screen.comfy_panel then
            player.gui.screen.comfy_panel.destroy()
            return
        else
            main_frame(player)
            return
        end
    end

    if not event.element.caption then
        return
    end
    if event.element.type ~= 'tab' then
        return
    end
    Public.comfy_panel_refresh_active_tab(player)
end

event.add(defines.events.on_gui_click, on_gui_click)

return Public
