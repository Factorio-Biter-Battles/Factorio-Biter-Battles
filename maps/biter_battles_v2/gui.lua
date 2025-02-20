local _DEBUG = false

local bb_config = require('maps.biter_battles_v2.config')
local Captain_event = require('comfy_panel.special_games.captain')
local Color = require('utils.color_presets')
local DifficultyVote = require('maps.biter_battles_v2.difficulty_vote')
local Event = require('utils.event')
local Feeding = require('maps.biter_battles_v2.feeding')
local Functions = require('maps.biter_battles_v2.functions')
local Gui = require('utils.gui')
local PlayerUtils = require('utils.player')
local ResearchInfo = require('maps.biter_battles_v2.research_info')
local Server = require('utils.server')
local Shortcuts = require('maps.biter_battles_v2.shortcuts')
local Tables = require('maps.biter_battles_v2.tables')
local TeamStatsCompare = require('maps.biter_battles_v2.team_stats_compare')
local gui_style = require('utils.utils').gui_style
local has_life = require('comfy_panel.special_games.limited_lives').has_life

local wait_messages = Tables.wait_messages
local food_names = Tables.gui_foods
local automation_feed = Tables.food_values['automation-science-pack'].value * 75

local math_random = math.random
local math_abs = math.abs
local math_ceil = math.ceil
local math_floor = math.floor
local string_format = string.format

local Public = {}
storage.player_data_afk = {}

local gui_values = {
    ['north'] = {
        biter_force = 'north_biters',
        n1 = 'join_north_button',
        t1 = 'Evolution of north side biters.',
        t2 = 'Threat causes biters to attack. \nReduces when biters are slain.',
        color1 = { r = 0.55, g = 0.55, b = 0.99 },
        color2 = { r = 0.66, g = 0.66, b = 0.99 },
        cpt_idx = 1,
    },
    ['south'] = {
        biter_force = 'south_biters',
        n1 = 'join_south_button',
        t1 = 'Evolution of south side biters.',
        t2 = 'Threat causes biters to attack. \nReduces when biters are slain.',
        color1 = { r = 0.99, g = 0.33, b = 0.33 },
        color2 = { r = 0.99, g = 0.44, b = 0.44 },
        cpt_idx = 2,
    },
}

local style = {
    bold = function(str)
        return '[font=default-bold]' .. str .. '[/font]'
    end,
    listbox = function(str)
        return '[font=default-listbox]' .. str .. '[/font]'
    end,
    stat = function(str)
        return '[font=count-font]' .. str .. '[/font]'
    end,
    green = function(str)
        return '[color=green]' .. str .. '[/color]'
    end,
    yellow = function(str)
        return '[color=yellow]' .. str .. '[/color]'
    end,
    red = function(str)
        return '[color=red]' .. str .. '[/color]'
    end,
    blue = function(str)
        return '[color=blue]' .. str .. '[/color]'
    end,
}

local TEST_1 =
    '[color=acid]Zyphorix[/color] [color=red]NibbleWorm[/color] [color=white]Velocisphere[/color] [color=pink]Currygeist[/color] [color=blue]QuarkBlaster[/color] [color=red]Drogoat[/color] [color=acid]Froozowizzle[/color] [color=gray]Tinkershadow[/color] [color=red]Axtorm[/color] [color=yellow]Vexonalux[/color] [color=green]Glimwiggle[/color] [color=cyan]Borqee[/color] [color=cyan]Zyglot[/color] [color=orange]Crimboxnattle[/color] [color=pink]TwinklePuff[/color] [color=green]Jumboborax[/color] [color=red]Fizzywerp[/color] [color=cyan]MocachinoBeast[/color]'

-- The on_player_joined_team event is raised only once when a player joins a team for the first time
-- at this stage, the player already has a character and starting items
-- @usage
-- local Gui = require "maps.biter_battles_v2.gui"
-- local Event = require 'utils.event'
--
-- Event.add(Gui.events.on_player_joined_team,
-- function(event)
--      local player = game.get_player(event.player_index)
-- end)
Public.events = { on_player_joined_team = Event.generate_event_name() }

local function get_format_time()
    local time_caption = 'Not started'
    local total_ticks = Functions.get_ticks_since_game_start()
    if total_ticks > 0 then
        local total_minutes = math_floor(total_ticks / (60 * 60))
        local total_hours = math_floor(total_minutes / 60)
        local minutes = total_minutes - (total_hours * 60)
        time_caption = string_format('%02d:%02d', total_hours, minutes)
    end
    return time_caption
end

local function get_player_data(player, remove)
    if remove and storage.player_data_afk[player.name] then
        storage.player_data_afk[player.name] = nil
        return
    end
    if not storage.player_data_afk[player.name] then
        storage.player_data_afk[player.name] = {}
    end
    return storage.player_data_afk[player.name]
end

local function drop_burners(player, forced_join)
    if forced_join then
        storage.got_burners[player.name] = nil
        return
    end
    if storage.training_mode or not storage.bb_settings.burners_balance then
        return
    end
    local burners_to_drop = player.get_item_count('burner-mining-drill')
    if burners_to_drop ~= 0 then
        local items = player.physical_surface.spill_item_stack({
            position = player.physical_position,
            stack = { name = 'burner-mining-drill', count = burners_to_drop },
            enable_looted = false,
            force = nil,
            allow_belts = false,
        })
        player.remove_item({ name = 'burner-mining-drill', count = burners_to_drop })
    end
end

---@param force string
---@return string
local function get_player_list_caption(force)
    if _DEBUG then
        return TEST_1
    end
    local players_with_colors = PlayerUtils.get_sorted_colored_player_list(game.forces[force].connected_players)
    return table.concat(players_with_colors, '    ')
end

---@param threat_value number
---@return string
function threat_to_pretty_string(threat_value)
    if math_abs(threat_value) >= 1e12 then
        return string_format('%.1fT', threat_value / 1e12)
    elseif math_abs(threat_value) >= 1e9 then
        return string_format('%.1fG', threat_value / 1e9)
    elseif math_abs(threat_value) >= 1e6 then
        return string_format('%.2fM', threat_value / 1e6)
    elseif math_abs(threat_value) >= 1e5 then
        return string_format('%.0fk', threat_value / 1e3)
    else
        return string_format('%.0f', threat_value)
    end
end

---@param evolution number
---@return string
local function get_evo_sprite(evolution)
    if evolution < 20 then
        return 'entity/small-biter'
    elseif evolution < 50 then
        return 'entity/medium-biter'
    elseif evolution < 90 then
        return 'entity/big-biter'
    end
    return 'entity/behemoth-biter'
end

---@param force string
---@param verbose boolean
---@return string
local function get_evo_tooltip(force, verbose)
    local prefix = ''
    if verbose then
        prefix = style.bold('Evolution') .. ' - ' .. gui_values[force].t1 .. '\n'
    end
    local biter_force = game.forces[gui_values[force].biter_force]
    local damage = (biter_force.get_ammo_damage_modifier('melee') + 1) * 100
    return prefix
        .. style.listbox('Evolution: ')
        .. style.yellow(style.stat(string_format('%.2f', (storage.bb_evolution[biter_force.name] * 100))))
        .. style.listbox('%\nDamage: ')
        .. style.yellow(style.stat(damage))
        .. style.listbox('%\nHealth: ')
        .. style.yellow(style.stat(string_format('%.0f', (storage.biter_health_factor[biter_force.index] * 100))))
        .. style.listbox('%')
end

---@param force string
---@param verbose boolean
---@return string
local function get_threat_tooltip(force, verbose)
    local prefix = ''
    if verbose then
        prefix = style.bold('Threat') .. ' - ' .. gui_values[force].t2 .. '\n'
    end
    local threat_income = storage.bb_threat_income[force .. '_biters'] * 60
    -- technically we could also include the threat-income-from-passive-feed here, but it is
    -- generally much much lower than bb_threat_income's contribution
    return prefix
        .. style.listbox('Passive feed:')
        .. style.yellow(style.stat(' +' .. math_ceil(threat_income)))
        .. style.listbox(' threat/min')
end

---@param force string
---@return string
local function get_captain_caption(force)
    local is_cpt = storage.active_special_games.captain_mode
    if is_cpt then
        local cpt_name = '---'
        local p_name = storage.special_games_variables.captain_mode.captainList[gui_values[force].cpt_idx]
        if p_name and storage.chosen_team[p_name] then
            local p = game.players[p_name]
            cpt_name = string_format(
                '[color=%.2f,%.2f,%.2f]%s[/color]',
                p.color.r * 0.6 + 0.4,
                p.color.g * 0.6 + 0.4,
                p.color.b * 0.6 + 0.4,
                p.name
            )
        end
        return style.listbox('[color=0.9,0.9,0.9]CAPTAIN:[/color] ') .. style.bold(cpt_name) .. '\n'
    end
    return ''
end

---@param player LuaPlayer
function Public.clear_copy_history(player)
    if player and player.valid and player.cursor_stack then
        for i = 1, 21 do
            -- Imports blueprint of single burner miner into the cursor stack
            stack = player.cursor_stack.import_stack(
                '0eNp9jkEKgzAURO8y67jQhsbmKqUUrR/5kHwliVKR3L3GbrrqcoaZN7OjdwvNgSXB7uDXJBH2viPyKJ0rXtpmggUn8lCQzhfVL0EoVJ6FZayGwM4hK7AM9Iat80OBJHFi+uJOsT1l8T2FI/AXpDBP8ehOUvYPnjYKG2x1bXMhn1fsz3OFlUI8801ba3NrzEVroxud8wdvA0sn'
            )
            player.add_to_clipboard(player.cursor_stack)
            player.clear_cursor()
        end
    end
end

function Public.reset_tables_gui()
    storage.player_data_afk = {}
end

---@param player LuaPlayer
function Public.create_biter_gui_button(player)
    local button = Gui.add_top_element(player, {
        type = 'sprite-button',
        name = 'bb_toggle_main_gui',
        sprite = 'entity/big-biter',
        tooltip = { 'gui.main_gui_top_button' },
    })
end

---@class RefreshStatisticsData
---@field clock_caption string
---@field clock_tooltip string
---@field team_frame table<"north"|"south",{team_caption:string, players_caption:string, players_tooltip:string, evolution_caption:string, evolution_tooltip:string, threat_caption:string, threat_tooltip:string}>

---@return RefreshStatisticsData
local function get_data_for_refresh_statistics()
    local color = DifficultyVote.difficulty_chat_color()
    return {
        clock_caption = get_format_time(),
        clock_tooltip = style.listbox('Difficulty: ') .. style.stat(
            string_format(
                '[color=%.2f,%.2f,%.2f]%s[/color]',
                color.r,
                color.g,
                color.b,
                DifficultyVote.difficulty_name()
            )
        ) .. string_format(style.listbox('\nGame speed: ') .. style.yellow(style.stat('%.2f')), game.speed),
        team_frame = {
            ['north'] = {
                team_caption = style.bold(Functions.team_name('north')),
                players_caption = '(' .. style.green(#game.forces['north'].connected_players) .. ')',
                players_tooltip = get_captain_caption('north') .. get_player_list_caption('north'),
                evolution_caption = (math_floor(1000 * storage.bb_evolution['north_biters']) * 0.1) .. '%',
                evolution_tooltip = get_evo_tooltip('north', false),
                threat_caption = threat_to_pretty_string(math_floor(storage.bb_threat['north_biters'])),
                threat_tooltip = get_threat_tooltip('north', false),
            },
            ['south'] = {
                team_caption = style.bold(Functions.team_name('south')),
                players_caption = '(' .. style.green(#game.forces['south'].connected_players) .. ')',
                players_tooltip = get_captain_caption('south') .. get_player_list_caption('south'),
                evolution_caption = (math_floor(1000 * storage.bb_evolution['south_biters']) * 0.1) .. '%',
                evolution_tooltip = get_evo_tooltip('south', false),
                threat_caption = threat_to_pretty_string(math_floor(storage.bb_threat['south_biters'])),
                threat_tooltip = get_threat_tooltip('south', false),
            },
        },
    }
end
---@param player LuaPlayer
function Public.create_statistics_gui_button(player)
    if Gui.get_top_element(player, 'bb_toggle_statistics') then
        return
    end

    local summary = Gui.add_top_element(player, {
        type = 'sprite-button',
        name = 'bb_toggle_statistics',
        sprite = 'utility/expand',
        -- hovered_sprite = 'utility/expand_dark',
        tooltip = 'Show game status!',
    })

    local frame = summary.parent.add({ type = 'frame', name = 'bb_frame_statistics', style = 'subheader_frame' })
    frame.location = { x = 1, y = 38 }
    gui_style(frame, { minimal_height = 36, maximal_height = 36 })

    local label, line

    do -- North
        label = frame.add({ type = 'label', caption = 'North', name = 'north_name' })
        gui_style(
            label,
            { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.north.color1 }
        )

        label = frame.add({ type = 'label', caption = ' ', name = 'north_players' })
        gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = { 225, 225, 225 } })

        line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line' })

        label = frame.add({ type = 'label', caption = ' ', name = 'north_evolution', font_color = { 225, 225, 225 } })
        gui_style(
            label,
            { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.north.color1 }
        )

        line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line' })

        label = frame.add({ type = 'label', caption = ' ', name = 'north_threat' })
        gui_style(
            label,
            { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.north.color1 }
        )
    end

    line = frame.add({ type = 'line', direction = 'vertical' })

    label = frame.add({ type = 'label', caption = '00:00', name = 'clock' })
    gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = { 225, 225, 225 } })

    line = frame.add({ type = 'line', direction = 'vertical' })

    do -- South
        label = frame.add({ type = 'label', caption = ' ', name = 'south_threat' })
        gui_style(
            label,
            { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.south.color1 }
        )

        line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line', font_color = { 225, 225, 225 } })

        label = frame.add({ type = 'label', caption = ' ', name = 'south_evolution' })
        gui_style(
            label,
            { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.south.color1 }
        )

        line = frame.add({ type = 'line', direction = 'vertical', style = 'dark_line' })

        label = frame.add({ type = 'label', caption = ' ', name = 'south_players' })
        gui_style(label, { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = { 225, 225, 225 } })

        label = frame.add({ type = 'label', caption = 'South', name = 'south_name' })
        gui_style(
            label,
            { font = 'heading-2', right_padding = 4, left_padding = 4, font_color = gui_values.south.color1 }
        )
    end

    Public.refresh_statistics(player, get_data_for_refresh_statistics())
    frame.visible = false
end

---@class RefreshMainGuiData
---@field clock_caption string
---@field game_speed_caption string
---@field is_cpt boolean
---@field main_frame table<"north"|"south", {teamname:string, playerlist_number:integer, evolution_number:integer, evolution_sprite:string, evolution_tooltip:string, threat_number:integer, threat_tooltip:string, captain:string, members:string}>

---@return RefreshMainGuiData
local function get_data_for_refresh_main_gui()
    return {
        clock_caption = string_format('Time: %s', get_format_time()),
        game_speed_caption = string_format('Speed: %.2f', game.speed),
        is_cpt = storage.active_special_games.captain_mode,
        main_frame = {
            ['north'] = {
                teamname = Functions.team_name('north'),
                playerlist_number = #game.forces['north'].connected_players,
                evolution_number = math_floor(1000 * storage.bb_evolution['north_biters']) * 0.1,
                evolution_sprite = get_evo_sprite(math_floor(1000 * storage.bb_evolution['north_biters']) * 0.1),
                evolution_tooltip = get_evo_tooltip('north', true),
                threat_number = math_floor(storage.bb_threat['north_biters']),
                threat_tooltip = get_threat_tooltip('north', true),
                captain = get_captain_caption('north'),
                members = get_player_list_caption('north'),
            },
            ['south'] = {
                teamname = Functions.team_name('south'),
                playerlist_number = #game.forces['south'].connected_players,
                evolution_number = math_floor(1000 * storage.bb_evolution['south_biters']) * 0.1,
                evolution_sprite = get_evo_sprite(math_floor(1000 * storage.bb_evolution['south_biters']) * 0.1),
                evolution_tooltip = get_evo_tooltip('south', true),
                threat_number = math_floor(storage.bb_threat['south_biters']),
                threat_tooltip = get_threat_tooltip('south', true),
                captain = get_captain_caption('south'),
                members = get_player_list_caption('south'),
            },
        },
    }
end
---@param player LuaPlayer
function Public.create_main_gui(player)
    local is_spec = player.force.name == 'spectator' or not storage.chosen_team[player.name]

    local main_frame = Gui.get_left_element(player, 'bb_main_gui')
    if main_frame and main_frame.valid then
        main_frame.destroy()
    end

    local main_frame =
        Gui.add_left_element(player, { type = 'frame', name = 'bb_main_gui', direction = 'vertical', index = 1 })
    gui_style(main_frame, { maximal_width = 325 })

    local flow = main_frame.add({ type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' })
    local inner_frame = flow.add({
        type = 'frame',
        name = 'inner_frame',
        style = 'inside_shallow_frame_packed',
        direction = 'vertical',
    })

    -- == SUBHEADER =================================================================
    do
        local subheader = inner_frame.add({ type = 'frame', name = 'subheader', style = 'subheader_frame' })
        gui_style(subheader, { horizontally_squashable = true, maximal_height = 40 })

        local label = subheader.add({ type = 'label', name = 'clock' })
        gui_style(label, { font = 'default-semibold', font_color = { 225, 225, 225 }, left_margin = 4 })

        Gui.add_pusher(subheader)
        local line = subheader.add({ type = 'line', direction = 'vertical' })
        Gui.add_pusher(subheader)

        local label = subheader.add({ type = 'label', name = 'game_speed' })
        gui_style(label, { font = 'default-semibold', font_color = { 225, 225, 225 }, right_margin = 4 })
    end

    -- == MAIN FRAME ================================================================
    local sp = inner_frame.add({
        type = 'scroll-pane',
        name = 'scroll_pane',
        style = 'scroll_pane_under_subheader',
        direction = 'vertical',
    })

    do -- North & South overview
        for force_name, gui_value in pairs(gui_values) do
            local team_frame =
                sp.add({ type = 'frame', name = force_name, style = 'bordered_frame', direction = 'vertical' })

            local flow = team_frame.add({ type = 'flow', name = 'flow', direction = 'horizontal' })
            gui_style(flow, { horizontal_align = 'center' })

            local caption_flow = flow.add({ type = 'flow', name = 'caption_flow', direction = 'vertical' })

            local label = caption_flow.add({ type = 'label', name = 'team_name', style = 'caption_label' })
            gui_style(label, { font_color = gui_value.color1, single_line = false, maximal_width = 125 })

            Gui.add_pusher(flow)

            local t = flow.add({ type = 'table', name = 'table', column_count = 3, style = 'compact_slot_table' })

            local players_button = t.add({
                type = 'sprite-button',
                style = 'slot_button_in_shallow_frame',
                sprite = 'entity/character',
                name = 'bb_toggle_player_list',
                auto_toggle = true,
                tooltip = style.bold('Player list') .. ' - Show player list',
            })

            local evolution_button = t.add({
                type = 'sprite-button',
                style = 'slot_button_in_shallow_frame',
                sprite = 'entity/small-biter',
                name = 'evolution',
                tooltip = style.bold('Evolution') .. ' - ' .. gui_value.t1,
            })

            local threat_button = t.add({
                type = 'sprite-button',
                style = 'slot_button_in_shallow_frame',
                sprite = 'utility/enemy_force_icon',
                name = 'threat',
                tooltip = style.bold('Threat') .. ' - ' .. gui_value.t2,
            })

            local size = 36
            for _, b in pairs({ players_button, evolution_button, threat_button }) do
                gui_style(
                    b,
                    { minimal_height = size, minimal_width = size, maximal_height = size, maximal_width = size }
                )
            end

            local players_frame = team_frame.add({
                type = 'frame',
                name = 'players',
                direction = 'vertical',
                style = 'deep_frame_in_shallow_frame',
            }) --quick_bar_window_frame
            gui_style(
                players_frame,
                { horizontal_align = 'center', maximal_width = 285, padding = 5, horizontally_stretchable = true }
            )

            local label = players_frame.add({ type = 'label', name = 'captain', caption = 'Captain: ---' })
            local label = players_frame.add({ type = 'label', name = 'members', caption = TEST_1 })
            gui_style(label, { single_line = false, font = 'default-small', horizontal_align = 'center' })

            players_frame.visible = players_button.toggled
        end
    end

    do -- Science sending GUI
        local science_frame = sp.add({
            type = 'frame',
            name = 'science_frame',
            style = 'bordered_frame',
            direction = 'vertical',
            caption = 'Feeding',
        })
        gui_style(science_frame, { horizontal_align = 'center' })

        local flow = science_frame.add({ type = 'flow', name = 'flow', direction = 'vertical' })
        gui_style(flow, { horizontal_align = 'center' })

        local table_frame = flow.add({
            type = 'frame',
            name = 'table_frame',
            direction = 'horizontal',
            style = 'quick_bar_inner_panel',
        }) --slot_button_deep_frame, quick_bar_window_frame, quick_bar_inner_panel
        gui_style(table_frame, { minimal_height = 40 })

        local t =
            table_frame.add({ type = 'table', name = 'send_table', column_count = 5, style = 'filter_slot_table' })
        gui_style(t, { horizontally_stretchable = true })

        for food_name, tooltip in pairs(food_names) do
            local f = t.add({
                type = 'sprite-button',
                name = food_name,
                sprite = 'item/' .. food_name,
                style = 'slot_button',
                tooltip = tooltip,
            })
            gui_style(f, { padding = 0 })
        end
        local f = t.add({
            type = 'sprite-button',
            name = 'send_all',
            caption = 'All',
            style = 'slot_button',
            tooltip = 'LMB - low to high, RMB - high to low',
        })
        gui_style(f, { padding = 0, font_color = { r = 0.9, g = 0.9, b = 0.9 } })
        local f = t.add({
            type = 'sprite-button',
            name = 'info',
            style = 'slot_button',
            sprite = 'utility/warning_white',
            tooltip = "If you don't see a food, it may have been disabled by special game mode, or you have not been authorized by your captain.",
        })
        gui_style(f, { padding = 0 })
    end

    do -- Join/Resume
        local join_frame =
            sp.add({ type = 'frame', name = 'join_frame', style = 'bordered_frame', direction = 'vertical' })
        gui_style(join_frame, { vertical_align = 'center' })

        local flow = join_frame.add({ type = 'flow', name = 'assign', direction = 'horizontal' })
        gui_style(flow, { vertical_align = 'center', horizontal_spacing = 4 })

        local label = flow.add({ type = 'label', caption = 'Join', style = 'caption_label' })
        Gui.add_pusher(flow)

        local button = flow.add({
            type = 'sprite-button',
            name = 'join_north',
            sprite = 'utility/speed_up',
            tooltip = style.bold('Join North team'),
            style = 'tool_button',
        })
        gui_style(button, { size = 28, padding = 1 })

        local button = flow.add({
            type = 'sprite-button',
            name = 'join_random',
            sprite = 'utility/shuffle',
            tooltip = style.bold('Join random team'),
            style = 'tool_button',
        })
        gui_style(button, { size = 28, padding = 3 })

        local button = flow.add({
            type = 'sprite-button',
            name = 'join_south',
            sprite = 'utility/speed_down',
            tooltip = style.bold('Join South team'),
            style = 'tool_button',
        })
        gui_style(button, { size = 28, padding = 1 })

        local flow = join_frame.add({ type = 'flow', name = 'resume', direction = 'horizontal' })
        gui_style(flow, { vertical_align = 'center', horizontal_spacing = 4 })

        local label = flow.add({ type = 'label', caption = 'Options', style = 'caption_label' })
        Gui.add_pusher(flow)

        local button = flow.add({
            type = 'sprite-button',
            name = 'bb_resume',
            sprite = 'utility/reset',
            tooltip = style.bold('Rejoin team'),
            style = 'back_button',
        })
        gui_style(button, { padding = 2, maximal_width = 38, maximal_height = 28 })

        local button = flow.add({
            type = 'sprite-button',
            name = 'bb_spectate',
            sprite = 'utility/create_ghost_on_entity_death_modifier_icon',
            tooltip = style.bold('Spectate'),
            style = 'forward_button',
        })
        gui_style(button, { padding = 2, maximal_width = 38, maximal_height = 28 })
    end

    -- == SUBFOOTER ===============================================================
    do
        local subfooter =
            inner_frame.add({ type = 'frame', name = 'subfooter', style = 'subfooter_frame', direction = 'horizontal' })
        gui_style(subfooter, { horizontally_squashable = true, vertical_align = 'center' })

        Gui.add_pusher(subfooter)

        local button = subfooter.add({
            type = 'sprite-button',
            name = 'bb_floating_shortcut_button',
            style = 'transparent_slot', -- 'quick_bar_slot_button', 'frame_action_button',
            sprite = 'utility/empty_module_slot',
            tooltip = { 'gui.floating_shortcuts' },
        })
        gui_style(button, { size = 26 })

        local button = ResearchInfo.create_research_info_button(subfooter)
        button.tooltip = { 'gui.research_info' }
        gui_style(button, { size = 26, left_margin = 4 })

        local button = subfooter.add({
            type = 'sprite-button',
            name = 'bb_floating_shortcuts_team_statistics',
            style = 'transparent_slot', -- 'quick_bar_slot_button', 'frame_action_button',
            sprite = 'utility/side_menu_production_icon',
            tooltip = { 'gui.team_statistics' },
        })
        gui_style(button, { size = 26, left_margin = 4 })

        local button = subfooter.add({
            type = 'sprite-button',
            name = 'bb_floating_shortcuts_clear_corpses',
            style = 'transparent_slot',
            sprite = 'utility/trash_white',
            tooltip = { 'gui.clear_corpses' },
        })
        gui_style(button, { size = 26, left_margin = 4, padding = 6 })

        Gui.add_pusher(subfooter)
    end

    -- ============================================================================

    Public.refresh_main_gui(player, get_data_for_refresh_main_gui())
end

---@param player LuaPlayer
---@param data RefreshStatisticsData
function Public.refresh_statistics(player, data)
    local frame = Gui.get_top_element(player, 'bb_frame_statistics')
    if not frame or not frame.visible then
        return
    end

    frame.clock.caption = data.clock_caption
    frame.clock.tooltip = data.clock_tooltip

    for force_name, _ in pairs(gui_values) do
        local local_data = data.team_frame[force_name]
        frame[force_name .. '_name'].tooltip = local_data.team_caption

        frame[force_name .. '_players'].caption = local_data.players_caption
        frame[force_name .. '_players'].tooltip = local_data.players_tooltip

        frame[force_name .. '_evolution'].caption = local_data.evolution_caption
        frame[force_name .. '_evolution'].tooltip = local_data.evolution_tooltip

        frame[force_name .. '_threat'].caption = local_data.threat_caption
        frame[force_name .. '_threat'].tooltip = local_data.threat_tooltip
    end
end

---@param player LuaPlayer
---@param data RefreshMainGuiData
function Public.refresh_main_gui(player, data)
    local frame = Gui.get_left_element(player, 'bb_main_gui')
    if not frame or not frame.visible then
        return
    end

    frame = frame.flow.inner_frame
    local header, main, footer = frame.subheader, frame.scroll_pane, frame.subfooter
    local is_spec = player.force.name == 'spectator' or not storage.chosen_team[player.name]

    -- == SUBHEADER =================================================================
    header.clock.caption = data.clock_caption
    header.game_speed.caption = data.game_speed_caption

    -- == MAIN FRAME ================================================================
    do -- North & South overview
        local is_cpt = data.is_cpt
        for force_name, _ in pairs(gui_values) do
            local local_data = data.main_frame[force_name]
            local team = main[force_name]
            team.flow.caption_flow.team_name.caption = local_data.teamname

            local team_info = team.flow.table

            team_info.bb_toggle_player_list.number = local_data.playerlist_number
            team_info.bb_toggle_player_list.tooltip = style.bold('Player list')
                .. (team_info.bb_toggle_player_list.toggled and ' - Hide player list' or ' - Show player list')

            team_info.evolution.number = local_data.evolution_number
            team_info.evolution.sprite = local_data.evolution_sprite
            team_info.evolution.tooltip = local_data.evolution_tooltip

            team_info.threat.number = local_data.threat_number
            team_info.threat.tooltip = local_data.threat_tooltip

            if team.players.visible then
                team.players.captain.visible = is_cpt ~= nil
                team.players.captain.caption = local_data.captain
                team.players.members.caption = local_data.members
            end
        end
    end

    do -- Science sending
        if is_spec or storage.bb_game_won_by_team then
            main.science_frame.visible = _DEBUG or false
        else
            main.science_frame.visible = true
            local table = main.science_frame.flow.table_frame.send_table
            local all_enabled = true
            local button
            for food_name, tooltip in pairs(food_names) do
                button = table[food_name]
                button.visible = true
                button.tooltip = tooltip
                if
                    storage.active_special_games.disable_sciences
                    and storage.special_games_variables.disabled_food[food_name]
                then
                    button.visible = false
                end
                if Captain_event.captain_is_player_prohibited_to_throw(player) and food_name ~= 'raw-fish' then
                    button.visible = false
                end
                all_enabled = all_enabled and button.visible
            end
            button = table.send_all
            button.visible = true
            if storage.active_special_games.disable_sciences then
                button.visible = false
            end
            if Captain_event.captain_is_player_prohibited_to_throw(player) then
                button.visible = false
            end
            all_enabled = all_enabled and button.visible
            table.info.visible = not all_enabled
        end
    end

    do -- Join/Resume
        local assign, resume = main.join_frame.assign, main.join_frame.resume
        assign.visible = _DEBUG or (storage.bb_game_won_by_team == nil and storage.chosen_team[player.name] == nil)
        resume.visible = _DEBUG or (storage.bb_game_won_by_team == nil and storage.chosen_team[player.name] ~= nil)
        resume.bb_resume.visible = _DEBUG or is_spec
        resume.bb_spectate.visible = _DEBUG or not is_spec
        main.join_frame.visible = assign.visible or resume.visible
    end

    -- == SUBFOOTER ===============================================================
    do
        footer.research_info_button.visible = _DEBUG
            or storage.bb_show_research_info == 'always'
            or (storage.bb_show_research_info == 'spec' and player.force.name == 'spectator')
            or (storage.bb_show_research_info == 'pure-spec' and not storage.chosen_team[player.name])
    end
end

function Public.refresh()
    local main_data = get_data_for_refresh_main_gui()
    local statistics_data = get_data_for_refresh_statistics()
    for _, player in pairs(game.connected_players) do
        Public.refresh_statistics(player, statistics_data)
        Public.refresh_main_gui(player, main_data)
        DifficultyVote.difficulty_gui(player)
    end
    storage.gui_refresh_delay = game.tick + 30
end

function Public.refresh_threat()
    if storage.gui_refresh_delay > game.tick then
        return
    end
    local updates = {
        north = {
            number = storage.bb_threat.north_biters,
            tooltip = get_threat_tooltip('north', true),
        },
        south = {
            number = storage.bb_threat.south_biters,
            tooltip = get_threat_tooltip('south', true),
        },
    }
    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_left_element(player, 'bb_main_gui')
        if frame and frame.visible then
            local teams = frame.flow.inner_frame.scroll_pane
            for k, v in pairs(updates) do
                local info = teams[k].flow.table
                info.threat.number = v.number
                info.threat.tooltip = v.tooltip
            end
        end
    end
    storage.gui_refresh_delay = game.tick + 30
end

---@param player LuaPlayer
function Public.burners_balance(player)
    if player.force.name == 'spectator' then
        return
    end
    if storage.got_burners[player.name] then
        return
    end
    if storage.training_mode or not storage.bb_settings.burners_balance then
        storage.got_burners[player.name] = true
        player.insert({ name = 'burner-mining-drill', count = 10 })
        return
    end
    local enemy_force = 'north'
    if player.force.name == 'north' then
        enemy_force = 'south'
    end
    local player2
    -- factorio Lua promises that pairs() iterates in insertion order
    for enemy_player_name, _ in pairs(storage.got_burners) do
        if
            not storage.got_burners[enemy_player_name]
            and (game.get_player(enemy_player_name).force.name == enemy_force)
            and game.get_player(enemy_player_name).connected
        then
            player2 = game.get_player(enemy_player_name)
            break
        end
    end
    if not player2 then
        storage.got_burners[player.name] = false
        return
    end
    local burners_to_insert = 10
    for i = 1, 0, -1 do
        local inserted
        storage.got_burners[player.name] = true
        inserted = player.insert({ name = 'burner-mining-drill', count = burners_to_insert })
        if inserted < burners_to_insert then
            player.physical_surface.spill_item_stack({
                position = player.physical_position,
                stack = { name = 'burner-mining-drill', count = burners_to_insert - inserted },
                enable_looted = false,
                force = nil,
                allow_belts = false,
            })
        end
        player.print({ 'info.burner_balance', burners_to_insert }, { r = 1, g = 1, b = 0 })
        player.create_local_flying_text({
            text = { 'info.burner_balance', burners_to_insert },
            position = player.position,
        })
        player = player2
    end
end

local function on_player_left_game(event)
    local player = game.get_player(event.player_index)
    drop_burners(player)
end

function join_team(player, force_name, forced_join, auto_join)
    if not player.character then
        return
    end
    if not player.spectator then
        return
    end
    if not forced_join and storage.reroll_time_left and storage.reroll_time_left > 0 then
        player.print(' Wait until reroll ends. ', { color = { r = 0.98, g = 0.66, b = 0.22 } })
        return
    end
    if not forced_join then
        if
            (storage.tournament_mode and not storage.active_special_games.captain_mode)
            or (storage.active_special_games.captain_mode and not storage.chosen_team[player.name])
        then
            player.print(
                'The game is set to tournament mode. Teams can only be changed via team manager.',
                { color = { r = 0.98, g = 0.66, b = 0.22 } }
            )
            return
        end
    end
    if not force_name then
        return
    end
    local surface = player.physical_surface
    local enemy_team = 'south'
    if force_name == 'south' then
        enemy_team = 'north'
    end

    if not storage.training_mode and storage.bb_settings.team_balancing then
        if not forced_join then
            if #game.forces[force_name].connected_players > #game.forces[enemy_team].connected_players then
                if not storage.chosen_team[player.name] then
                    player.print(
                        Functions.team_name_with_color(force_name) .. ' has too many players currently.',
                        { color = { r = 0.98, g = 0.66, b = 0.22 } }
                    )
                    return
                end
            end
        end
    end

    if storage.chosen_team[player.name] then
        if not forced_join then
            if storage.active_special_games.limited_lives and not has_life(player.name) then
                player.print(
                    'Special game in progress. You have no lives left until the end of the game.',
                    { color = { r = 0.98, g = 0.66, b = 0.22 } }
                )
                return
            end
            if
                storage.suspended_players[player.name]
                and (game.ticks_played - storage.suspended_players[player.name]) < storage.suspended_time
            then
                player.print(
                    'Not ready to return to your team yet as you are still suspended. Please wait '
                        .. math_ceil(
                            (
                                storage.suspended_time
                                - (math_floor((game.ticks_played - storage.suspended_players[player.name])))
                            ) / 60
                        )
                        .. ' seconds.',
                    { color = { r = 0.98, g = 0.66, b = 0.22 } }
                )
                return
            end
            if
                storage.spectator_rejoin_delay[player.name]
                and game.tick - storage.spectator_rejoin_delay[player.name] < 3600
            then
                player.print(
                    'Not ready to return to your team yet. Please wait '
                        .. 60 - (math_floor((game.tick - storage.spectator_rejoin_delay[player.name]) / 60))
                        .. ' seconds.',
                    { color = { r = 0.98, g = 0.66, b = 0.22 } }
                )
                return
            end
        end
        local p = nil
        local p_data = get_player_data(player)
        if p_data and p_data.position then
            p = surface.find_non_colliding_position('character', p_data.position, 16, 0.5)
            get_player_data(player, true)
        else
            p = surface.find_non_colliding_position(
                'character',
                game.forces[force_name].get_spawn_position(surface),
                16,
                0.5
            )
        end
        if not p then
            game.print('No spawn position found for ' .. player.name .. '!', { color = { 255, 0, 0 } })
            return
        end
        player.character.teleport(p, surface)
        player.force = game.forces[force_name]
        player.character.destructible = true
        Public.refresh()
        game.permissions.get_group('Default').add_player(player)
        local msg = table.concat({ 'Team ', player.force.name, ' player ', player.name, ' is no longer spectating.' })
        game.print(msg, { color = { r = 0.98, g = 0.66, b = 0.22 } })
        Sounds.notify_allies(player.force, 'utility/build_blueprint_large')
        Server.to_discord_bold(msg)
        storage.spectator_rejoin_delay[player.name] = game.tick
        player.spectator = false
        player.show_on_map = true
        Public.burners_balance(player)
        return
    end
    local pos =
        surface.find_non_colliding_position('character', game.forces[force_name].get_spawn_position(surface), 8, 1)
    if not pos then
        pos = game.forces[force_name].get_spawn_position(surface)
    end
    player.character.teleport(pos)
    player.force = game.forces[force_name]
    player.character.destructible = true
    game.permissions.get_group('Default').add_player(player)
    if not forced_join then
        -- In case bots are parsing discord messages, we always refer to teams as 'north' or 'south'
        Server.to_discord_bold(table.concat({ player.name, ' has joined team ', player.force.name, '!' }))
        local join_text = 'has joined'
        if auto_join then
            join_text = 'was automatically assigned to'
        end
        local message =
            table.concat({ player.name, ' ', join_text, ' ', Functions.team_name_with_color(player.force.name), '!' })
        game.print(message, { color = { r = 0.98, g = 0.66, b = 0.22 } })
    end

    local i = player.character.get_inventory(defines.inventory.character_main)
    i.clear()
    player.insert({ name = 'pistol', count = 1 })
    player.insert({ name = 'raw-fish', count = 3 })
    player.insert({ name = 'firearm-magazine', count = 32 })
    player.insert({ name = 'iron-gear-wheel', count = 8 })
    player.insert({ name = 'iron-plate', count = 16 })
    player.insert({ name = 'wood', count = 2 })
    storage.chosen_team[player.name] = force_name
    storage.spectator_rejoin_delay[player.name] = game.tick
    player.spectator = false
    player.show_on_map = true
    Public.burners_balance(player)
    Public.clear_copy_history(player)
    Public.refresh()

    script.raise_event(Public.events.on_player_joined_team, {
        player_index = player.index,
    })
end

function spectate(player, forced_join, stored_position)
    -- Player might not have a body if captain ejected them, was waiting
    -- for a respawn or has alternative controller set.
    if not player.character then
        -- Reposition camera to chunk which is guaranteed to exists to avoid
        -- any issue with character positioning. Repositioning is performed
        -- only for cases where character is to be created.
        local origin = { 0, 0 }
        if player.ticks_to_respawn then
            -- Character cannot be created while dead, we can only speed up
            -- respawn and pray it doesn't race.
            player.teleport(origin)
            player.ticks_to_respawn = nil
            if not player.character then
                log('WARN: spectate: player ' .. player.name .. ' still without a character')
                log('WARN: spectate: fallback to old behavior')
                return
            end
        else
            -- Is player missing a body due to unrelated bug/accidental removal?
            -- Maybe admin tries to recover situation.
            if player.physical_controller_type ~= defines.controllers.editor then
                log('INFO: spectate: player ' .. player.name .. ' was without a character')
                -- We cannot trust LuaPlayer::physical_surface as they might be trapped
                -- on another surface.
                local s = game.surfaces[storage.bb_surface_name]
                player.teleport(origin, s)
                local ch = s.create_entity({
                    name = 'character',
                    position = origin,
                })
                player.set_controller({
                    type = defines.controllers.character,
                    character = ch,
                })
            else
                -- Non-admin player should never reach this state.
                -- If it's an admin, best to not interfere (leave old behavior).
                log('WARN: spectate: player ' .. player.name .. " doesn't have associated character")
                log('WARN: spectate: fallback to old behavior')
                return
            end
        end
    end

    if not forced_join then
        if storage.tournament_mode and not storage.active_special_games.captain_mode then
            player.print(
                'The game is set to tournament mode. Teams can only be changed via team manager.',
                { color = { r = 0.98, g = 0.66, b = 0.22 } }
            )
            return
        end
        if storage.active_special_games.captain_mode and storage.special_games_variables.captain_mode.prepaPhase then
            player.print(
                'The game is in preparation phase of captain event, no spectating allowed until the captain game started',
                { color = { r = 0.98, g = 0.66, b = 0.22 } }
            )
            return
        end
    end

    while player.crafting_queue_size > 0 do
        player.cancel_crafting(player.crafting_queue[1])
    end

    player.driving = false
    player.character.driving = false
    player.clear_cursor()
    drop_burners(player, forced_join)

    if stored_position then
        local p_data = get_player_data(player)
        p_data.position = player.physical_position
    end
    player.character.teleport(player.physical_surface.find_non_colliding_position('character', { 0, 0 }, 4, 1))
    Sounds.notify_player(player, 'utility/build_blueprint_large')
    player.force = game.forces.spectator
    player.character.destructible = false
    if not forced_join then
        local msg = player.name .. ' is spectating.'
        game.print(msg, { color = { r = 0.98, g = 0.66, b = 0.22 } })
        Server.to_discord_bold(msg)
    end
    game.permissions.get_group('spectator').add_player(player)
    storage.spectator_rejoin_delay[player.name] = game.tick
    Public.create_main_gui(player)
    player.spectator = true
    player.show_on_map = false
end

local function join_gui_click(name, player, auto_join)
    if not name then
        return
    end

    join_team(player, name, false, auto_join)
end

local spy_forces = { { 'north', 'south' }, { 'south', 'north' } }
function Public.spy_fish()
    for _, f in pairs(spy_forces) do
        if storage.spy_fish_timeout[f[1]] - game.tick > 0 then
            local r = 96
            local surface = game.surfaces[storage.bb_surface_name]
            for _, player in pairs(game.forces[f[2]].connected_players) do
                game.forces[f[1]].chart(surface, {
                    { player.physical_position.x - r, player.physical_position.y - r },
                    { player.physical_position.x + r, player.physical_position.y + r },
                })
            end
        else
            storage.spy_fish_timeout[f[1]] = 0
        end
    end
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end

    local player = game.get_player(event.player_index)
    if not (player and player.valid) then
        return
    end

    local name = element.name

    if name == 'bb_toggle_main_gui' then
        local main_frame = Gui.get_left_element(player, 'bb_main_gui')
        if main_frame then
            main_frame.destroy()
        else
            Public.create_main_gui(player)
        end
        return
    end

    if name == 'bb_toggle_statistics' then
        local default = element.sprite == 'utility/expand'
        element.sprite = default and 'utility/collapse' or 'utility/expand'
        -- element.hovered_sprite = default and 'utility/collapse_dark' or 'utility/expand_dark'
        element.tooltip = default and 'Hide game status!' or 'Show game status!'

        local frame = Gui.get_top_element(player, 'bb_frame_statistics')
        if frame then
            frame.visible = not frame.visible
            Public.refresh_statistics(player, get_data_for_refresh_statistics())
        end
        return
    end

    if name == 'bb_toggle_player_list' then
        local team_frame = element.parent.parent.parent
        team_frame.players.visible = element.toggled
        Public.refresh_main_gui(player, get_data_for_refresh_main_gui())
        return
    end

    if name == 'raw-fish' then
        Functions.spy_fish(player, event)
        return
    end

    if food_names[name] then
        if not Captain_event.captain_is_player_prohibited_to_throw(player) then
            Feeding.feed_biters_from_inventory(player, name)
        end
        return
    end

    if name == 'send_all' then
        if not Captain_event.captain_is_player_prohibited_to_throw(player) then
            Feeding.feed_biters_mixed_from_inventory(player, event.button)
        end
        return
    end

    if name == 'join_north' then
        join_gui_click('north', player)
        return
    end

    if name == 'join_south' then
        join_gui_click('south', player)
        return
    end

    if name == 'join_random' then
        local north_connected_players = #game.forces.north.connected_players
        local south_connected_players = #game.forces.south.connected_players

        -- choosing a team at random if teams are equal
        if north_connected_players == south_connected_players then
            local teams = { 'north', 'south' }
            join_gui_click(teams[math_random(#teams)], player, true)
        else -- checking which team is smaller and joining it
            local smallest_team = north_connected_players < south_connected_players and 'north' or 'south'
            join_gui_click(smallest_team, player, true)
        end
        return
    end

    if name == 'bb_resume' then
        join_team(player, storage.chosen_team[player.name])
        return
    end

    if name == 'bb_spectate' then
        if player.physical_position.y ^ 2 + player.physical_position.x ^ 2 < 12000 then
            spectate(player)
        else
            player.print('You are too far away from spawn to spectate.', { color = { r = 0.98, g = 0.66, b = 0.22 } })
        end
        return
    end

    if name == 'bb_floating_shortcut_button' then
        local shortcuts_frame = Shortcuts.get_main_frame(player)
        if shortcuts_frame and shortcuts_frame.valid then
            shortcuts_frame.visible = not shortcuts_frame.visible
            shortcuts_frame.bring_to_front()
        end
        return
    end

    if name == 'suspend_yes' then
        local suspend_info = storage.suspend_target_info
        if suspend_info then
            if player.force.name == suspend_info.target_force_name then
                if suspend_info.suspend_votes_by_player[player.name] ~= 1 then
                    suspend_info.suspend_votes_by_player[player.name] = 1
                    game.print(
                        player.name .. ' wants to suspend ' .. suspend_info.suspendee_player_name,
                        { color = { r = 0.1, g = 0.9, b = 0.0 } }
                    )
                end
            else
                player.print('You cannot vote from a different force!', { color = { r = 0.9, g = 0.1, b = 0.1 } })
            end
        end
    end

    if name == 'suspend_no' then
        local suspend_info = storage.suspend_target_info
        if suspend_info then
            if player.force.name == suspend_info.target_force_name then
                if suspend_info.suspend_votes_by_player[player.name] ~= 0 then
                    suspend_info.suspend_votes_by_player[player.name] = 0
                    game.print(
                        player.name .. " doesn't want to suspend " .. suspend_info.suspendee_player_name,
                        { color = { r = 0.9, g = 0.1, b = 0.1 } }
                    )
                end
            else
                player.print('You cannot vote from a different force!', { color = { r = 0.9, g = 0.1, b = 0.1 } })
            end
        end
    end

    if name == 'reroll_yes' then
        if storage.reroll_map_voting[player.name] ~= 1 then
            storage.reroll_map_voting[player.name] = 1
            game.print(player.name .. ' wants to reroll map ', { color = { r = 0.1, g = 0.9, b = 0.0 } })
        end
    end

    if name == 'reroll_no' then
        if storage.reroll_map_voting[player.name] ~= 0 then
            storage.reroll_map_voting[player.name] = 0
            game.print(player.name .. ' wants to keep this map', { color = { r = 0.9, g = 0.1, b = 0.1 } })
        end
    end

    if name == 'automatic_captain_yes' then
        if storage.automatic_captain_voting[player.name] ~= 1 then
            storage.automatic_captain_voting[player.name] = 1
            game.print(player.name .. ' wants to play a captain game', { color = { r = 0.1, g = 0.9, b = 0.0 } })
        end
    end

    if name == 'automatic_captain_no' then
        if storage.automatic_captain_voting[player.name] ~= 0 then
            storage.automatic_captain_voting[player.name] = 0
            game.print(
                player.name .. ' does not want to play a captain game',
                { color = { r = 0.9, g = 0.1, b = 0.1 } }
            )
        end
    end
end

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    if player.online_time == 0 then
        Functions.show_intro(player)
    end

    Public.create_main_gui(player)
end

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game, on_player_left_game)

return Public
