local gui_style = require('utils.utils').gui_style
local Functions = require('maps.biter_battles_v2.functions')
local Tables = require('maps.biter_battles_v2.tables')
local closable_frame = require('utils.ui.closable_frame')
local TeamStatsCollect = require('maps.biter_battles_v2.team_stats_collect')
local safe_wrap_with_player_print = require('utils.utils').safe_wrap_with_player_print
local safe_wrap_cmd = require('utils.utils').safe_wrap_cmd
local Quality = require('maps.biter_battles_v2.quality')
local Event = require('utils.event')

local math_floor = math.floor
local math_max = math.max
local string_format = string.format

local TeamStatsCompare = {}

---@alias TeamstatsPreferences {show_hidden: boolean?, show_prev: boolean?}

---@param player LuaPlayer
---@return TeamstatsPreferences
local function get_preferences(player)
    local res = storage.teamstats_preferences[player.name]
    if not res then
        res = {}
        storage.teamstats_preferences[player.name] = res
    end
    return res
end

---@param parent LuaGuiElement
---@param a LuaGuiElement.add_param
---@return LuaGuiElement
local function add_small_label(parent, a)
    a.type = 'label'
    local l = parent.add(a)
    l.style.font = 'default-small'
    return l
end

local function ticks_to_hh_mm(ticks)
    local total_minutes = math_floor(ticks / (60 * 60))
    local total_hours = math_floor(total_minutes / 60)
    local minutes = total_minutes - (total_hours * 60)
    return string_format('%02d:%02d', total_hours, minutes)
end

---@param num number?
---@return string
local function format_with_thousands_sep(num)
    num = math_floor(num or 0)
    local str = tostring(num)
    local reversed = str:reverse()
    local formatted_reversed = reversed:gsub('(%d%d%d)', '%1,')
    return (formatted_reversed:reverse():gsub('^,', ''))
end

---@param num number
---@return string
local function format_one_sig_fig(num)
    if num < 0.1 then
        return string_format('%.2f', num)
    elseif num < 1 then
        return string_format('%.1f', num)
    else
        return format_with_thousands_sep(num)
    end
end

local function simple_sum(vals)
    local total = 0
    for _, num in pairs(vals) do
        total = total + num
    end

    return total
end

local function format_total_caption(vals)
    local total = simple_sum(vals)
    return format_with_thousands_sep(total)
end

local function format_food_tooltip_with_quality(vals, reference)
    local total = 0
    local tooltip = ''
    if not vals then
        return tooltip
    end

    for tier, num in pairs(vals) do
        local q = Quality.TIERS[tier]
        if num ~= 0 then
            tooltip = tooltip
                .. '[img=quality/'
                .. q.name
                .. '] '
                .. format_with_thousands_sep(num)
                .. ' X '
                .. q.multiplier
                .. '\n'
            total = total + num * q.multiplier
        end
    end

    if total ~= 0 then
        if #vals > 1 then
            tooltip = tooltip .. '[img=utility/any_quality] ' .. format_with_thousands_sep(total) .. '\n'
        else
            tooltip = ''
        end

        tooltip = tooltip .. '[item=space-science-pack] equivalent: ' .. format_one_sig_fig(total * reference)
    end

    return tooltip
end

local function format_first_at(val)
    return (val and ticks_to_hh_mm(val)) or ''
end

local function format_first_at_caption(vals)
    if not vals then
        return ''
    end

    return format_first_at(vals[1])
end

local function format_first_at_tooltip_with_quality(vals)
    local tooltip = ''
    if not vals then
        return tooltip
    end

    if #vals == 1 then
        return tooltip
    end

    for tier, first_at in pairs(vals) do
        local q = Quality.TIERS[tier]
        tooltip = tooltip .. '[img=quality/' .. q.name .. '] ' .. format_first_at(first_at) .. '\n'
    end

    return tooltip:sub(1, -2)
end

local function format_generic_caption(vals)
    if vals and vals ~= {} then
        return format_total_caption(vals)
    end

    return ''
end

local function format_generic_tooltip_with_quality(vals)
    local tooltip = ''
    if not vals then
        return tooltip
    end

    if #vals == 1 then
        return tooltip
    end

    for tier, num in pairs(vals) do
        if num ~= 0 then
            local q = Quality.TIERS[tier]
            tooltip = tooltip .. '[img=quality/' .. q.name .. '] ' .. format_with_thousands_sep(num) .. '\n'
        end
    end

    return tooltip:sub(1, -2)
end

local function quality_sum(arrs)
    if not arrs then
        return {}
    end

    local total = {}
    local tiers = Quality.available_tiers()
    for t = 1, tiers do
        total[t] = 0
        for _, arr in ipairs(arrs) do
            if arr[t] then
                total[t] = total[t] + arr[t]
            end
        end
    end

    return total
end

local function get_killed_or_lost(killed, lost)
    return quality_sum({ killed, lost })
end

local function get_buffered(produced, consumed, placed, lost)
    return quality_sum({ produced, consumed, placed, lost })
end

local function total_with_quality(vals)
    if not vals then
        return 0
    end

    local total = 0
    for tier, num in pairs(vals) do
        local q = Quality.TIERS[tier]
        total = total + num * q.multiplier
    end

    return total
end

---@param player LuaPlayer
function TeamStatsCompare.show_stats(player)
    local preferences = get_preferences(player)
    local show_hidden = preferences.show_hidden and true or false
    local show_prev = preferences.show_prev and true or false
    ---@type table<string, boolean>
    local exclude_forces = {}
    ---@type TeamStats
    local stats
    if not storage.prev_game_team_stats then
        show_prev = false
    end
    if show_prev then
        stats = storage.prev_game_team_stats
    else
        stats = TeamStatsCollect.compute_stats()
        -- allow it always in single player, or if the game is over
        local other_force = nil
        if storage.chosen_team[player.name] == 'north' then
            other_force = 'south'
        elseif storage.chosen_team[player.name] == 'south' then
            other_force = 'north'
        end
        if not storage.bb_game_won_by_team then
            if storage.allow_teamstats == 'spectator' then
                if other_force and player.force.name ~= 'spectator' then
                    exclude_forces[other_force] = true
                end
            elseif storage.allow_teamstats == 'pure-spectator' then
                if other_force then
                    exclude_forces[other_force] = true
                end
            elseif storage.allow_teamstats ~= 'always' then
                if other_force then
                    exclude_forces[other_force] = true
                else
                    exclude_forces['north'] = true
                    exclude_forces['south'] = true
                end
            end
        end
    end

    ---@type LuaGuiElement
    local frame = player.gui.screen['teamstats_frame']
    if frame then
        frame.destroy()
    end
    frame = closable_frame.create_main_closable_frame(player, 'teamstats_frame', 'Team statistics')
    gui_style(frame, { padding = 8 })
    local scrollpanel = frame.add({
        type = 'scroll-pane',
        name = 'scroll_pane',
        direction = 'vertical',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'auto',
    })

    ---@param force_name string
    ---@param top_table LuaGuiElement
    local function add_simple_force_stats(force_name, top_table)
        --- @type ForceStats
        local force_stats = stats.forces[force_name]
        local team_frame = top_table.add({ type = 'frame', name = 'summary_' .. force_name, direction = 'vertical' })
        gui_style(team_frame, { padding = 8 })
        local team_label = team_frame.add({ type = 'label', caption = Functions.team_name_with_color(force_name) })
        gui_style(team_label, { font = 'heading-2', single_line = false, maximal_width = 150 })
        local simple_stats = {
            { 'Final evo:', string_format('%d%%', (force_stats.final_evo or 0) * 100) },
            { 'Peak threat:', threat_to_pretty_string(force_stats.peak_threat or 0) },
            { 'Lowest threat:', threat_to_pretty_string(force_stats.lowest_threat or 0) },
        }
        if stats.ticks and stats.ticks > 0 then
            table.insert(simple_stats, {
                'Average players:',
                string_format('%.1f [img=info]', (force_stats.player_ticks or 0) / (stats.ticks or 1)),
                string_format('Total players: %d, Max players: %d', force_stats.total_players, force_stats.max_players),
            })
        end
        local top_simple_table = team_frame.add({ type = 'table', name = 'top_simple_table', column_count = 2 })
        for _, stat in ipairs(simple_stats) do
            top_simple_table.add({ type = 'label', caption = stat[1] })
            top_simple_table.add({ type = 'label', caption = stat[2], tooltip = stat[3] })
        end
    end
    local top_centering_table = scrollpanel.add({ type = 'table', name = 'top_centering_table', column_count = 1 })
    top_centering_table.style.column_alignments[1] = 'center'
    local top_table =
        top_centering_table.add({ type = 'table', name = 'top_table', column_count = 3, vertical_centering = true })
    top_table.style.column_alignments[1] = 'right'
    top_table.style.column_alignments[2] = 'center'
    top_table.style.column_alignments[3] = 'left'
    add_simple_force_stats('north', top_table)
    local space_sci_mutagen = Tables.food_values['space-science-pack'].value
    if true then
        local shared_frame = top_table.add({ type = 'frame', name = 'summary_shared', direction = 'vertical' })
        local centering_table = shared_frame.add({ type = 'table', name = 'centering_table', column_count = 1 })
        centering_table.style.column_alignments[1] = 'center'
        add_small_label(centering_table, {
            caption = string_format(
                'Difficulty: %s (%d%%)',
                (stats.difficulty or ''),
                (stats.difficulty_value or 0) * 100
            ),
        })
        add_small_label(centering_table, { caption = string_format('Duration: %s', ticks_to_hh_mm(stats.ticks or 0)) })
        if stats.won_by_team then
            add_small_label(
                centering_table,
                { caption = string_format('Winner: %s', stats.won_by_team == 'north' and 'North' or 'South') }
            )
        end
    end
    add_simple_force_stats('south', top_table)

    local two_table =
        top_centering_table.add({ type = 'table', name = 'two_table', column_count = 2, vertical_centering = true })
    two_table.style.column_alignments[1] = 'right'
    two_table.style.left_cell_padding = 4
    two_table.style.right_cell_padding = 4
    for _, force_name in ipairs({ 'north', 'south' }) do
        local science_flow =
            two_table.add({ type = 'flow', name = 'science_flow_' .. force_name, direction = 'vertical' })
        gui_style(science_flow, { horizontal_align = 'center' })
        local cols = {
            { '' },
            { 'First [img=info]', 'The time that the first item was produced.' },
            { 'Produced' },
            { 'Consumed' },
            { 'Sent' },
        }
        local science_table = science_flow.add({ type = 'table', name = 'science_table', column_count = #cols })
        gui_style(science_table, { left_cell_padding = 3, right_cell_padding = 3, vertical_spacing = 0 })
        for idx, col_info in ipairs(cols) do
            science_table.style.column_alignments[idx] = 'right'
            add_small_label(science_table, { caption = col_info[1], tooltip = col_info[2] })
        end
        local total_sent_mutagen = 0
        local total_produced_mutagen = 0
        for _, food in ipairs(Tables.food_long_and_short) do
            local force_stats = stats.forces[force_name]
            local food_stats = force_stats.food[food.long_name] or {}
            local food_mutagen = Tables.food_values[food.long_name].value
            local reference = food_mutagen / space_sci_mutagen
            local produced = food_stats.produced or {}
            local consumed = food_stats.consumed or {}
            local sent = food_stats.sent or {}
            add_small_label(science_table, { caption = string_format('[item=%s]', food.long_name) })
            add_small_label(science_table, {
                caption = format_first_at_caption(food_stats.first_at),
                tooltip = format_first_at_tooltip_with_quality(food_stats.first_at),
            })
            if not exclude_forces[force_name] then
                add_small_label(science_table, {
                    caption = format_total_caption(produced),
                    tooltip = format_food_tooltip_with_quality(produced, reference),
                })
                add_small_label(science_table, {
                    caption = format_total_caption(consumed),
                    tooltip = format_food_tooltip_with_quality(consumed, reference),
                })
            else
                add_small_label(science_table, { caption = '' })
                add_small_label(science_table, { caption = '' })
            end
            add_small_label(science_table, {
                caption = format_total_caption(sent),
                tooltip = format_food_tooltip_with_quality(sent, reference),
            })
            total_sent_mutagen = total_sent_mutagen + total_with_quality(food_stats.sent) * food_mutagen
            total_produced_mutagen = total_produced_mutagen + total_with_quality(food_stats.produced) * food_mutagen
        end
        local produced_info = ''
        if not exclude_forces[force_name] then
            produced_info =
                string_format(' produced: %s', format_one_sig_fig(total_produced_mutagen / space_sci_mutagen))
        end
        add_small_label(science_flow, {
            caption = string_format(
                '[item=space-science-pack] equivalent%s sent: %s',
                produced_info,
                format_one_sig_fig(total_sent_mutagen / space_sci_mutagen)
            ),
        })
    end

    two_table.add({ type = 'line' })
    two_table.add({ type = 'line' })
    for _, force_name in ipairs({ 'north', 'south' }) do
        local force_stats = stats.forces[force_name]
        local cols = {
            { '[img=info]', 'Hover over icons for full details' },
            { 'First [img=info]', 'The time that the first item was produced.' },
            { 'Produced' },
            { 'Placed [img=info]', 'The highest value of (constructed-deconstructed) over time.' },
            { 'Lost' },
        }
        if show_hidden then
            table.insert(cols, 4, {
                'Buffered [img=info]',
                'Produced - Consumed - Placed - Lost. This can double-count placed+lost, so might be too low.',
            })
        end
        local item_table = two_table.add({
            type = 'table',
            name = 'item_table_' .. force_name,
            column_count = #cols,
            vertical_centering = false,
        })
        gui_style(item_table, { left_cell_padding = 3, right_cell_padding = 3, vertical_spacing = 0 })
        if not exclude_forces[force_name] then
            for idx, col_info in ipairs(cols) do
                item_table.style.column_alignments[idx] = 'right'
                add_small_label(item_table, { caption = col_info[1], tooltip = col_info[2] })
            end
        end

        for _, item_info in ipairs(TeamStatsCollect.items_to_show_summaries_of) do
            if not exclude_forces[force_name] and (show_hidden or not item_info.hide_by_default) then
                local item_stats = force_stats.items[item_info.item] or {}
                ---@type number?
                local killed_or_lost = get_killed_or_lost(item_stats.kill_count, item_stats.lost)
                local buffered =
                    get_buffered(item_stats.produced, item_stats.consumed, item_stats.placed, item_stats.lost)
                local tooltip = string_format(
                    'Produced: %s, Consumed: %s, Lost: %s, Buffered: %s',
                    format_generic_caption(item_stats.produced),
                    format_generic_caption(item_stats.consumed),
                    format_generic_caption(item_stats.lost),
                    format_generic_caption(buffered)
                )
                local l = add_small_label(
                    item_table,
                    { caption = string_format('[item=%s]', item_info.item), tooltip = tooltip }
                )
                if item_info.space_after then
                    l.style.bottom_padding = 12
                end
                add_small_label(item_table, {
                    caption = format_first_at_caption(item_stats.first_at),
                    tooltip = format_first_at_tooltip_with_quality(item_stats.first_at),
                })
                add_small_label(item_table, {
                    caption = format_generic_caption(item_stats.produced),
                    tooltip = format_generic_tooltip_with_quality(item_stats.produced),
                })
                if show_hidden then
                    add_small_label(item_table, {
                        caption = format_generic_caption(buffered),
                        tooltip = format_generic_tooltip_with_quality(buffered),
                    })
                end
                add_small_label(item_table, {
                    caption = format_generic_caption(item_stats.placed),
                    tooltip = format_generic_tooltip_with_quality(item_stats.placed),
                })
                add_small_label(item_table, {
                    caption = format_generic_caption(killed_or_lost),
                    tooltip = format_generic_tooltip_with_quality(killed_or_lost),
                })
            end
        end
    end

    local damage_types_to_render = {}
    local show_damage_table = false
    for _, force_name in ipairs({ 'north', 'south' }) do
        local force_stats = stats.forces[force_name]
        for damage_name, damage_info in pairs(force_stats.damage_types) do
            if (damage_info.damage or 0) > 0 then
                damage_types_to_render[damage_name] = true
                show_damage_table = true
            end
        end
    end

    if show_damage_table then
        two_table.add({ type = 'line' })
        two_table.add({ type = 'line' })
        for _, force_name in ipairs({ 'north', 'south' }) do
            local cols = {
                { '' },
                { 'Kills' },
                { 'Damage [img=info]', 'Approximate total damage.' },
            }
            local damage_table =
                two_table.add({ type = 'table', name = 'damage_table_' .. force_name, column_count = #cols })
            gui_style(damage_table, { left_cell_padding = 3, right_cell_padding = 3, vertical_spacing = 0 })
            for idx, col_info in ipairs(cols) do
                if idx > 1 then
                    damage_table.style.column_alignments[idx] = 'right'
                end
                add_small_label(damage_table, { caption = col_info[1], tooltip = col_info[2] })
            end

            local force_stats = stats.forces[force_name]
            local total_kills = 0
            local total_damage = 0
            for _, damage_render_info in ipairs(TeamStatsCollect.damage_render_info) do
                if damage_types_to_render[damage_render_info[1]] then
                    local damage_info = force_stats.damage_types[damage_render_info[1]] or {}
                    total_kills = total_kills + (damage_info.kills or 0)
                    total_damage = total_damage + (damage_info.damage or 0)
                    add_small_label(damage_table, { caption = damage_render_info[2], tooltip = damage_render_info[3] })
                    add_small_label(damage_table, { caption = format_with_thousands_sep(damage_info.kills or 0) })
                    add_small_label(damage_table, { caption = format_with_thousands_sep(damage_info.damage or 0) })
                end
            end
            add_small_label(damage_table, { caption = 'Total' })
            add_small_label(damage_table, { caption = format_with_thousands_sep(total_kills) })
            add_small_label(damage_table, { caption = format_with_thousands_sep(total_damage) })
        end
    end
    top_centering_table.add({ type = 'line' })
    local checkbox_flow = top_centering_table.add({ type = 'flow', name = 'checkbox_flow', direction = 'horizontal' })
    checkbox_flow.add({
        type = 'checkbox',
        name = 'teamstats_show_hidden',
        caption = 'Show more items',
        state = show_hidden,
    })
    checkbox_flow.add({
        type = 'checkbox',
        name = 'teamstats_show_prev',
        caption = 'Show previous game',
        state = show_prev,
    })
end

function TeamStatsCompare.game_over()
    for _, player in pairs(game.connected_players) do
        safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player)
    end
    storage.prev_game_team_stats = storage.team_stats
end

function TeamStatsCompare.toggle_team_stats(player)
    local frame = player.gui.screen.teamstats_frame

    if frame and frame.valid then
        frame.destroy()
        return
    end

    TeamStatsCompare.show_stats(player)
end

local function teamstats_cmd(cmd)
    if not cmd.player_index then
        return
    end
    local player = game.get_player(cmd.player_index)
    if not player then
        return
    end
    if cmd.parameter and cmd.parameter ~= '' then
        player.print("Unsupported argument to /teamstats. Run just '/teamstats'")
        return
    end
    TeamStatsCompare.toggle_team_stats(player)
end

commands.add_command('teamstats', 'Show team stats', function(cmd)
    safe_wrap_cmd(cmd, teamstats_cmd, cmd)
end)

---@param event EventData.on_gui_checked_state_changed
local function on_gui_checked_state_changed(event)
    local player = game.get_player(event.player_index)
    if not player then
        return
    end
    if not event.element.valid then
        return
    end
    if event.element.name == 'teamstats_show_hidden' then
        get_preferences(player).show_hidden = event.element.state
        safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player)
    elseif event.element.name == 'teamstats_show_prev' then
        get_preferences(player).show_prev = event.element.state
        safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player)
    end
end

Event.add(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)

return TeamStatsCompare
