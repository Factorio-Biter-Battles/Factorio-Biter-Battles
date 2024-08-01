local gui_style = require 'utils.utils'.gui_style
local Functions = require 'maps.biter_battles_v2.functions'
local Tables = require 'maps.biter_battles_v2.tables'
local closable_frame = require "utils.ui.closable_frame"
local TeamStatsCollect = require 'maps.biter_battles_v2.team_stats_collect'
local safe_wrap_with_player_print = require 'utils.utils'.safe_wrap_with_player_print
local Event = require 'utils.event'

local math_floor = math.floor
local math_max = math.max
local string_format = string.format

local TeamStatsCompare = {}

---@param parent LuaGuiElement
---@param a LuaGuiElement.add_param
---@return LuaGuiElement
local function add_small_label(parent, a)
    a.type = "label"
    local l = parent.add(a)
    l.style.font = "default-small"
    return l
end

local function ticks_to_hh_mm(ticks)
    local total_minutes = math_floor(ticks / (60 * 60))
    local total_hours = math_floor(total_minutes / 60)
    local minutes = total_minutes - (total_hours * 60)
    return string_format("%02d:%02d", total_hours, minutes)
end

---@param num number?
---@return string
local function format_with_thousands_sep(num)
    num = math_floor(num or 0)
    local str = tostring(num)
    local reversed = str:reverse()
    local formatted_reversed = reversed:gsub("(%d%d%d)", "%1,")
    return (formatted_reversed:reverse():gsub("^,", ""))
end

---@param num number
---@return string
local function format_one_sig_fig(num)
    if num < 0.1 then
        return string_format("%.2f", num)
    elseif num < 1 then
        return string_format("%.1f", num)
    else
        return format_with_thousands_sep(num)
    end
end

---@param player LuaPlayer
---@param stats TeamStats
function TeamStatsCompare.show_stats(player, stats)
    if stats == nil then
        stats = TeamStatsCollect.compute_stats()
    end
    local show_hidden = global.teamstats_preferences[player.name] and global.teamstats_preferences[player.name].show_hidden or false
    ---@type LuaGuiElement
    local frame = player.gui.screen["teamstats_frame"]
    if frame then
        frame.destroy()
    end
    frame = closable_frame.create_main_closable_frame(player, "teamstats_frame", "Team statistics")
    gui_style(frame, { padding = 8 })
    local scrollpanel = frame.add { type = "scroll-pane", name = "scroll_pane", direction = "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto" }

    ---@param force_name string
    ---@param top_table LuaGuiElement
    local function add_simple_force_stats(force_name, top_table)
        --- @type ForceStats
        local force_stats = stats.forces[force_name]
        local team_frame = top_table.add { type = "frame", name = "summary_" .. force_name, direction = "vertical" }
        gui_style(team_frame, { padding = 8 })
        local team_label = team_frame.add { type = "label", caption = Functions.team_name_with_color(force_name) }
        gui_style(team_label, { font = "heading-2", single_line = false, maximal_width = 150})
        local simple_stats = {
            {"Final evo:", string_format("%d%%", (force_stats.final_evo or 0) * 100)},
            {"Peak threat:", threat_to_pretty_string(force_stats.peak_threat or 0)},
            {"Lowest threat:", threat_to_pretty_string(force_stats.lowest_threat or 0)},
        }
        if stats.ticks and stats.ticks > 0 then
            table.insert(simple_stats, {"Average players:", string_format("%.1f [img=info]", (force_stats.player_ticks or 0) / (stats.ticks or 1)), string_format("Total players: %d, Max players: %d", force_stats.total_players, force_stats.max_players)})
        end
        local top_simple_table = team_frame.add { type = "table", name = "top_simple_table", column_count = 2 }
        for _, stat in ipairs(simple_stats) do
            top_simple_table.add { type = "label", caption = stat[1] }
            top_simple_table.add { type = "label", caption = stat[2], tooltip = stat[3] }
        end
    end
    local top_centering_table = scrollpanel.add { type = "table", name = "top_centering_table", column_count = 1 }
    top_centering_table.style.column_alignments[1] = "center"
    local top_table = top_centering_table.add { type = "table", name = "top_table", column_count = 3, vertical_centering = true }
    top_table.style.column_alignments[1] = "right"
    top_table.style.column_alignments[2] = "center"
    top_table.style.column_alignments[3] = "left"
    add_simple_force_stats("north", top_table)
    local space_sci_mutagen = Tables.food_values["space-science-pack"].value
    if true then
        local shared_frame = top_table.add { type = "frame", name = "summary_shared", direction = "vertical" }
        local centering_table = shared_frame.add { type = "table", name = "centering_table", column_count = 1 }
        centering_table.style.column_alignments[1] = "center"
        add_small_label(centering_table, { caption = string_format("Difficulty: %s (%d%%)", (stats.difficulty or ""), (stats.difficulty_value or 0) * 100) })
        add_small_label(centering_table, { caption = string_format("Duration: %s", ticks_to_hh_mm(stats.ticks or 0)) })
        if stats.won_by_team then
            add_small_label(centering_table, { caption = string_format("Winner: %s", stats.won_by_team == "north" and "North" or "South") })
        end
    end
    add_simple_force_stats("south", top_table)

    local two_table = top_centering_table.add { type = "table", name = "two_table", column_count = 2, vertical_centering = true }
    two_table.style.column_alignments[1] = "right"
    two_table.style.left_cell_padding = 4
    two_table.style.right_cell_padding = 4
    for _, force_name in ipairs({"north", "south"}) do
        local science_flow = two_table.add { type = "flow", name = "science_flow_" .. force_name, direction = "vertical" }
        gui_style(science_flow, { horizontal_align = "center" })
        local cols = {
            {""},
            {"First [img=info]", "The time that the first item was produced."},
            {"Produced"},
            {"Consumed"},
            {"Sent"},
        }
        local science_table = science_flow.add { type = "table", name = "science_table", column_count = #cols }
        gui_style(science_table, { left_cell_padding = 3, right_cell_padding = 3, vertical_spacing = 0 })
        for idx, col_info in ipairs(cols) do
            science_table.style.column_alignments[idx] = "right"
            add_small_label(science_table, { caption = col_info[1], tooltip = col_info[2] })
        end
        local total_sent_mutagen = 0
        local total_produced_mutagen = 0
        for _, food in ipairs(Tables.food_long_and_short) do
            local force_stats = stats.forces[force_name]
            local food_stats = force_stats.food[food.long_name] or {}
            local food_mutagen = Tables.food_values[food.long_name].value
            local produced = food_stats.produced or 0
            local consumed = food_stats.consumed or 0
            local sent = food_stats.sent or 0
            add_small_label(science_table, { caption = string_format("[item=%s]", food.long_name) })
            add_small_label(science_table, { caption = (food_stats.first_at and ticks_to_hh_mm(food_stats.first_at) or "") })
            add_small_label(science_table, { caption = format_with_thousands_sep(produced), tooltip = "[item=space-science-pack] equivalent: " .. format_one_sig_fig(produced * food_mutagen / space_sci_mutagen) })
            add_small_label(science_table, { caption = format_with_thousands_sep(consumed), tooltip = "[item=space-science-pack] equivalent: " .. format_one_sig_fig(consumed * food_mutagen / space_sci_mutagen) })
            add_small_label(science_table, { caption = format_with_thousands_sep(sent), tooltip = "[item=space-science-pack] equivalent: " .. format_one_sig_fig(sent * food_mutagen / space_sci_mutagen) })
            total_sent_mutagen = total_sent_mutagen + (food_stats.sent or 0) * food_mutagen
            total_produced_mutagen = total_produced_mutagen + (food_stats.produced or 0) * food_mutagen
        end
        add_small_label(science_flow, { caption = string_format("[item=space-science-pack] equivalent produced: %s sent: %s", format_one_sig_fig(total_produced_mutagen/space_sci_mutagen), format_one_sig_fig(total_sent_mutagen / space_sci_mutagen)) })
    end

    two_table.add { type = "line" }
    two_table.add { type = "line" }
    for _, force_name in ipairs({"north", "south"}) do
        local force_stats = stats.forces[force_name]
        local cols = {
            {"[img=info]", "Hover over icons for full details"},
            {"First [img=info]", "The time that the first item was produced."},
            {"Produced"},
            {"Placed [img=info]", "The highest value of (constructed-deconstructed) over time."},
            {"Lost"},
        }
        if show_hidden then
            table.insert(cols, 4, {"Buffered [img=info]", "Produced - Consumed - Placed - Lost. This can double-count placed+lost, so might be too low."})
        end
        local item_table = two_table.add { type = "table", name = "item_table_" .. force_name, column_count = #cols, vertical_centering = false }
        gui_style(item_table, { left_cell_padding = 3, right_cell_padding = 3, vertical_spacing = 0})
        for idx, col_info in ipairs(cols) do
            item_table.style.column_alignments[idx] = "right"
            add_small_label(item_table, { caption = col_info[1], tooltip = col_info[2] })
        end

        for _, item_info in ipairs(TeamStatsCollect.items_to_show_summaries_of) do
            if show_hidden or not item_info.hide_by_default then
                local item_stats = force_stats.items[item_info.item] or {}
                ---@type number?
                local killed_or_lost = (item_stats.kill_count or 0) + (item_stats.lost or 0)
                if killed_or_lost == 0 then killed_or_lost = nil end
                local buffered = math_max(0, (item_stats.produced or 0) - (item_stats.consumed or 0) - (item_stats.placed or 0) - (item_stats.lost or 0))
                local tooltip = string_format("Produced: %s, Consumed: %s, Lost: %s, Buffered: %s",
                    format_with_thousands_sep(item_stats.produced or 0),
                    format_with_thousands_sep(item_stats.consumed or 0),
                    format_with_thousands_sep(item_stats.lost or 0),
                    format_with_thousands_sep(buffered))
                local l = add_small_label(item_table, { caption = string_format("[item=%s]", item_info.item), tooltip = tooltip})
                if item_info.space_after then
                    l.style.bottom_padding = 12
                end
                add_small_label(item_table, { caption = (item_stats.first_at and ticks_to_hh_mm(item_stats.first_at) or "") })
                add_small_label(item_table, { caption = format_with_thousands_sep(item_stats.produced or 0) })
                if show_hidden then
                    add_small_label(item_table, { caption = format_with_thousands_sep(buffered) })
                end
                add_small_label(item_table, { caption = item_stats.placed and format_with_thousands_sep(item_stats.placed) or "" })
                add_small_label(item_table, { caption = killed_or_lost and format_with_thousands_sep(killed_or_lost) or "" })
            end
        end
    end

    local damage_types_to_render = {}
    local show_damage_table = false
    for _, force_name in ipairs({"north", "south"}) do
        local force_stats = stats.forces[force_name]
        for damage_name, damage_info in pairs(force_stats.damage_types) do
            if (damage_info.damage or 0) > 0 then
                damage_types_to_render[damage_name] = true
                show_damage_table = true
            end
        end
    end

    if show_damage_table then
        two_table.add { type = "line" }
        two_table.add { type = "line" }
        for _, force_name in ipairs({"north", "south"}) do
            local cols = {
                {""},
                {"Kills"},
                {"Damage [img=info]", "Approximate total damage."},
            }
            local damage_table = two_table.add { type = "table", name = "damage_table_" .. force_name, column_count = #cols }
            gui_style(damage_table, { left_cell_padding = 3, right_cell_padding = 3, vertical_spacing = 0})
            for idx, col_info in ipairs(cols) do
                if idx > 1 then
                    damage_table.style.column_alignments[idx] = "right"
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
            add_small_label(damage_table, { caption = "Total" })
            add_small_label(damage_table, { caption = format_with_thousands_sep(total_kills) })
            add_small_label(damage_table, { caption = format_with_thousands_sep(total_damage) })
        end
    end
    top_centering_table.add { type = "line" }
    top_centering_table.add { type = "checkbox", name = "teamstats_show_hidden", caption = "Show more items", state = show_hidden }
end

function TeamStatsCompare.game_over()
    for _, player in pairs(game.connected_players) do
        safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player)
    end
    global.prev_game_team_stats = global.team_stats
end

function TeamStatsCompare.toggle_team_stats(player, stats)
    local frame = player.gui.screen.teamstats_frame

    if frame and frame.valid then
        frame.destroy()
        return
    end

    local deny_reason = false
    -- allow it always in single player, or if the game is over
    if not stats and not global.bb_game_won_by_team and game.is_multiplayer() then
        if global.allow_teamstats == 'spectators' then
            if player.force.name ~= 'spectator' then
                deny_reason = 'spectators only'
            end
        elseif global.allow_teamstats == 'pure-spectators' then
            if global.chosen_team[player.name] then
                deny_reason = 'pure spectators only (you have joined a team)'
            end
        else
            if global.allow_teamstats ~= 'always' then
                deny_reason = 'only allowed at end of game'
            end
        end
    end
    if deny_reason then
        player.print('Team stats for current game is unavailable: ' .. deny_reason)
        Sounds.notify_player(player, 'utility/cannot_build')
        return
    end
    TeamStatsCompare.show_stats(player, stats)
end

commands.add_command("teamstats", "Show team stats", function (cmd)
    if not cmd.player_index then return end
    local player = game.get_player(cmd.player_index)
    if not player then return end
    local deny_reason
    local stats
    if cmd.parameter == "prev" then
        stats = global.prev_game_team_stats
        if not stats then
            player.print("No previous game stats available.")
            return
        end
    elseif cmd.parameter and cmd.parameter ~= "" then
        player.print("Unsupported argument to /teamstats. Run either just '/teamstats' or '/teamstats prev'")
        return
    end
    TeamStatsCompare.toggle_team_stats(player, stats)
end)

---@param event EventData.on_gui_checked_state_changed
local function on_gui_checked_state_changed(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    if not event.element.valid then return end
    if event.element.name == "teamstats_show_hidden" then
        global.teamstats_preferences[player.name] = global.teamstats_preferences[player.name] or {}
        global.teamstats_preferences[player.name].show_hidden = event.element.state
        safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player)
    end
end

Event.add(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)

return TeamStatsCompare
