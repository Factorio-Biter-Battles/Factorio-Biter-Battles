local Captain_event = require('comfy_panel.special_games.captain')
local Event = require('utils.event')
local Feeding = require('maps.biter_battles_v2.feeding')
local Functions = require('maps.biter_battles_v2.functions')
local Gui = require('utils.gui')
local ResearchInfo = require('maps.biter_battles_v2.research_info')
local Tables = require('maps.biter_battles_v2.tables')
local TeamStatsCompare = require('maps.biter_battles_v2.team_stats_compare')
local Color = require('utils.color_presets')

local math_floor = math.floor
local gui_style = require('utils.utils').gui_style
local safe_wrap_with_player_print = require('utils.utils').safe_wrap_with_player_print

local Public = {}

-- Saves the preferences for each players, i.e. storage.shortcuts_ui['Alice'] = { ['send-fish'] = true, ['research_info'] = false }
---@type table<string, table<string, boolean>>
storage.shortcuts_ui = storage.shortcuts_ui or {}

Public.main_frame_name = 'bb_floating_shortcuts'
local main_frame_name = Public.main_frame_name

local function handle_spectator(player)
    local is_spectator = player.force.name == 'spectator'
    if is_spectator then
        player.print('This shortcut cannot be used while spectating')
        Sounds.notify_player(player, 'utility/cannot_build')
    end
    return is_spectator
end

local function get_player_preferences(player)
    local player_preferences = storage.shortcuts_ui[player.name]
    if not player_preferences then
        player_preferences = { enabled = false }
        storage.shortcuts_ui[player.name] = player_preferences
    end
    return player_preferences
end

local function add_shortcut_selection_row(player, parent, child)
    local row = parent.add({ type = 'frame', style = 'shortcut_selection_row' })
    gui_style(row, { horizontally_stretchable = true, vertically_stretchable = false })

    local icon = row.add({
        type = 'sprite-button',
        style = 'transparent_slot',
        sprite = child.sprite,
        tooltip = child.tooltip,
    })
    gui_style(icon, { width = 20, height = 20 })

    local player_preferences = get_player_preferences(player)
    if player_preferences[child.name] == nil then
        player_preferences[child.name] = true
    end

    local checkbox = row.add({
        type = 'checkbox',
        caption = child.caption,
        state = player_preferences[child.name],
        tags = { action = main_frame_name .. '_checkbox', name = child.name },
    })
    gui_style(checkbox, { horizontally_stretchable = true })
end

local function toggle_shortcuts_settings(player)
    local frame = Public.get_main_frame(player)
    frame.qbip.qbsp.visible = not frame.qbip.qbsp.visible
end

local main_frame_actions = {
    [main_frame_name .. '_send_fish'] = function(player, event)
        if handle_spectator(player) or storage.bb_game_won_by_team then
            return
        end
        Functions.spy_fish(player, event)
    end,
    [main_frame_name .. '_send_science'] = function(player, event)
        if handle_spectator(player) or storage.bb_game_won_by_team then
            return
        end
        if storage.active_special_games.disable_sciences then
            player.print('Disabled by special game', { color = Color.red })
        elseif Captain_event.captain_is_player_prohibited_to_throw(player) then
            player.print('You are not allowed to send science, ask your captain', { color = Color.red })
        else
            Feeding.feed_biters_mixed_from_inventory(player, event.button)
        end
    end,
    [main_frame_name .. '_research_info'] = function(player, event)
        ResearchInfo.show_research_info_handler(event)
    end,
    [main_frame_name .. '_team_statistics'] = function(player, event)
        TeamStatsCompare.toggle_team_stats(player)
    end,
    [main_frame_name .. '_clear_corpses'] = function(player, event)
        if handle_spectator(player) then
            return
        end
        Functions.clear_corpses(player)
    end,
    [main_frame_name .. '_settings'] = function(player, event)
        toggle_shortcuts_settings(player)
    end,
}

local shortcut_buttons = {
    {
        name = main_frame_name .. '_send_fish',
        caption = 'Send fish',
        sprite = 'item/raw-fish',
        tooltip = '[font=default-bold]Send fish[/font] - ' .. Tables.gui_foods['raw-fish'],
    },
    {
        name = main_frame_name .. '_send_science',
        caption = 'Send science',
        sprite = 'item/automation-science-pack',
        tooltip = { 'gui.send_all_science' },
    },
    {
        name = main_frame_name .. '_research_info',
        caption = 'Research info',
        sprite = 'item/lab',
        tooltip = { 'gui.research_info' },
    },
    {
        name = main_frame_name .. '_team_statistics',
        caption = 'Team statistics',
        sprite = 'utility/side_menu_production_icon',
        -- hovered_sprite = 'utility/side_menu_production_hover_icon',
        tooltip = { 'gui.team_statistics' },
    },
    {
        name = main_frame_name .. '_clear_corpses',
        caption = 'Clear corpses',
        sprite = 'entity/behemoth-biter',
        tooltip = { 'gui.clear_corpses' },
    },
}

function Public.get_main_frame(player)
    local main_frame = player.gui.screen[main_frame_name]
    if not main_frame or not main_frame.valid then
        main_frame = player.gui.screen.add({
            type = 'frame',
            name = main_frame_name,
            direction = 'vertical',
            style = 'quick_bar_slot_window_frame',
        })
        main_frame.auto_center = true
        main_frame.visible = false
        gui_style(main_frame, { minimal_width = 20 })

        local title_bar = main_frame.add({
            type = 'flow',
            name = 'titlebar',
            direction = 'horizontal',
            style = 'horizontal_flow',
        })
        gui_style(title_bar, { vertical_align = 'center' })
        title_bar.drag_target = main_frame

        local title = title_bar.add({
            type = 'label',
            caption = 'Shortcuts',
            style = 'frame_title',
            ignored_by_interaction = true,
        })
        gui_style(title, { top_padding = 2, font = 'default-semibold', font_color = { 165, 165, 165 } })

        local widget =
            title_bar.add({ type = 'empty-widget', style = 'draggable_space', ignored_by_interaction = true })
        gui_style(widget, { left_margin = 4, right_margin = 4, height = 20, horizontally_stretchable = true })

        local settings = title_bar.add({
            type = 'sprite-button',
            name = main_frame_name .. '_settings',
            style = 'shortcut_bar_expand_button',
            sprite = 'utility/expand_dots',
            hovered_sprite = 'utility/expand_dots',
            clicked_sprite = 'utility/expand_dots',
            tooltip = { 'gui.shortcut_settings' },
            mouse_button_filter = { 'left' },
            auto_toggle = true,
        })
        gui_style(settings, { width = 8, height = 16 })

        local settings_scroll_pane =
            main_frame.add({ type = 'frame', name = 'qbip', style = 'quick_bar_inner_panel' }).add({
                type = 'scroll-pane',
                name = 'qbsp',
                style = 'shortcut_bar_selection_scroll_pane',
            })
        gui_style(settings_scroll_pane, { minimal_width = 40 * #shortcut_buttons })

        for _, s in pairs(shortcut_buttons) do
            add_shortcut_selection_row(player, settings_scroll_pane, s)
        end
        add_shortcut_selection_row(player, settings_scroll_pane, {
            caption = 'Rocket silo health',
            sprite = 'utility/short_indication_line_green',
            tooltip = { 'gui.rocket_silo_health' },
            name = 'silo_health',
        })
        settings_scroll_pane.visible = false

        local table_frame = main_frame.add({
            type = 'frame',
            name = 'table_frame',
            direction = 'horizontal',
            style = 'quick_bar_inner_panel',
        })
        gui_style(table_frame, { horizontally_stretchable = true, margin = 0 })

        local table = table_frame.add({
            type = 'table',
            name = 'table',
            column_count = #shortcut_buttons,
            style = 'filter_slot_table',
        })
        gui_style(table, { horizontally_stretchable = true })

        local button
        local player_preferences = get_player_preferences(player)
        for _, s in pairs(shortcut_buttons) do
            button = table.add({
                type = 'sprite-button',
                style = 'slot_button',
                sprite = s.sprite,
                hovered_sprite = s.hovered_sprite,
                name = s.name,
                tooltip = s.tooltip,
            })
            gui_style(button, { font_color = { 165, 165, 165 } })
            button.visible = player_preferences[s.name]
        end

        -- Silo progress bar
        local progress_bar = main_frame.add({
            type = 'progressbar',
            name = 'silo_health',
            tooltip = { 'gui.rocket_silo_health' },
            value = 1,
        })
        gui_style(progress_bar, { horizontally_stretchable = true, color = { 165, 165, 165 } })
        progress_bar.style.natural_width = nil
        progress_bar.visible = get_player_preferences(player)['silo_health']
    end
    return main_frame
end

Event.add(defines.events.on_gui_click, function(event)
    local ele = event.element
    if not (ele and ele.valid) then
        return
    end
    local player = game.get_player(event.player_index)
    local action = main_frame_actions[ele.name]
    if action then
        action(player, event)
    end
end)

Event.add(defines.events.on_gui_checked_state_changed, function(event)
    local ele = event.element
    if not (ele and ele.valid) then
        return
    end
    local player = game.get_player(event.player_index)
    if ele.tags.action == main_frame_name .. '_checkbox' then
        local name = ele.tags.name
        local frame = Public.get_main_frame(player)
        local button
        if name == 'silo_health' then
            button = frame.silo_health
        else
            button = frame.table_frame.table[name]
        end
        if button then
            button.visible = ele.state
            local player_preferences = get_player_preferences(player)
            player_preferences[name] = button.visible
        end
    end
end)

function Public.refresh()
    for _, force in pairs(game.forces) do
        local list = storage.rocket_silo[force.name]
        if list == nil then
            goto refresh_loop_1
        end

        -- Only one primary silo is supported.
        local rocket_silo = list[1]
        if rocket_silo and rocket_silo.valid then
            local health = rocket_silo.get_health_ratio()
            local HP = math_floor(rocket_silo.health)
            local HP_percent = math_floor(1000 * health) * 0.1
            for _, player in pairs(force.connected_players) do
                local frame = Public.get_main_frame(player)
                if frame.visible then
                    frame.silo_health.value = health
                    frame.silo_health.style.color = { r = 1 - health, g = health, b = 0 }
                    frame.silo_health.tooltip = { 'gui.rocket_silo_health_stats', HP, HP_percent }
                end
            end
        else
            for _, player in pairs(force.connected_players) do
                local frame = Public.get_main_frame(player)
                if frame.visible then
                    frame.silo_health.value = 1
                    frame.silo_health.style.color = { 165, 165, 165 }
                    frame.silo_health.tooltip = { 'gui.rocket_silo_health' }
                end
            end
        end

        ::refresh_loop_1::
    end
end

return Public
