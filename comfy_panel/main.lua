--[[
Comfy Panel

To add a tab, insert into the "comfy_panel_tabs" table.

Example: comfy_panel_tabs["mapscores"] = {gui = draw_map_scores, admin = false}
if admin = true, then tab is visible only for admins (usable for map-specific settings)

draw_map_scores would be a function with the player and the frame as arguments

]]
require "utils.profiler"
local event = require 'utils.event'
local gui_style = require 'utils.utils'.gui_style
local closable_frame = require "utils.ui.closable_frame"
comfy_panel_tabs = {}

local Public = {}

function Public.get_tabs(data)
    return comfy_panel_tabs
end

function Public.comfy_panel_get_active_frame(player)
    if not player.gui.screen.comfy_panel then
        return false
    end
    if not player.gui.screen.comfy_panel.comfy_panel_inside.tabbed_pane.selected_tab_index then
        return player.gui.screen.comfy_panel.comfy_panel_inside.tabbed_pane.tabs[1].content
    end
    return player.gui.screen.comfy_panel.comfy_panel_inside.tabbed_pane.tabs[player.gui.screen.comfy_panel.comfy_panel_inside.tabbed_pane.selected_tab_index].content
end

function Public.comfy_panel_refresh_active_tab(player)
    local frame = Public.comfy_panel_get_active_frame(player)
    if not frame then
        return
    end
    comfy_panel_tabs[frame.name].gui(player, frame)
end

local function top_button(player)
    if player.gui.top['comfy_panel_top_button'] then
        return
    end
    local button = player.gui.top.add({type = 'sprite-button', name = 'comfy_panel_top_button', sprite = 'item/raw-fish'})
    gui_style(button, {width = 38, height = 38, padding = -2})
end

local function main_frame(player)
    local tabs = comfy_panel_tabs

    local frame_ = closable_frame.create_main_closable_frame(player, 'comfy_panel', "Comfy Panel")
    local frame = frame_.add({type = "frame", name = "comfy_panel_inside", style = "inside_deep_frame_for_tabs"})

    local tabbed_pane = frame.add({type = 'tabbed-pane', name = 'tabbed_pane'})

    for name, func in pairs(tabs) do
        if func.admin == true then
            if player.admin then
                local tab = tabbed_pane.add({type = 'tab', caption = name})
                local flow = tabbed_pane.add({type = 'flow', name = name, direction = 'vertical'})
                flow.style.horizontally_stretchable = true
                flow.style.width = 863
                flow.style.height = 480
                tabbed_pane.add_tab(tab, flow)
            end
        else
            local tab = tabbed_pane.add({type = 'tab', caption = name})
            local flow = tabbed_pane.add({type = 'flow', name = name, direction = 'vertical'})
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

function Public.comfy_panel_call_tab(player, name)
    main_frame(player)
    local tabbed_pane = player.gui.screen.comfy_panel.tabbed_pane
    for key, v in pairs(tabbed_pane.tabs) do
        if v.tab.caption == name then
            tabbed_pane.selected_tab_index = key
            Public.comfy_panel_refresh_active_tab(player)
        end
    end
end

local function on_player_joined_game(event)
    top_button(game.get_player(event.player_index))
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

event.add(defines.events.on_player_joined_game, on_player_joined_game)
event.add(defines.events.on_gui_click, on_gui_click)

return Public
