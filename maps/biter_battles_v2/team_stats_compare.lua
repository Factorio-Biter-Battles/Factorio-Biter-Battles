local gui_style = require 'utils.utils'.gui_style
local Functions = require 'maps.biter_battles_v2.functions'
local Tables = require 'maps.biter_battles_v2.tables'
local closable_frame = require "utils.ui.closable_frame"
local TeamStatsCollect = require 'maps.biter_battles_v2.team_stats_collect'
local safe_wrap_with_player_print = require 'utils.utils'.safe_wrap_with_player_print
local ItemCosts = require 'maps.biter_battles_v2.item_costs'
local PlayerUtil = require 'utils.player'

local math_floor = math.floor
local math_max = math.max
local string_format = string.format

local TeamStatsCompare = {}

local function ticks_to_hh_mm(ticks)
    local total_minutes = math_floor(ticks / (60 * 60))
    local total_hours = math_floor(total_minutes / 60)
    local minutes = total_minutes - (total_hours * 60)
    return string_format("%02d:%02d", total_hours, minutes)
end

---@param num number
---@return string
local function format_with_thousands_sep(num)
    num = math_floor(num)
    local str = tostring(num)
    local reversed = str:reverse()
    local formatted_reversed = reversed:gsub("(%d%d%d)", "%1,")
    return (formatted_reversed:reverse():gsub("^,", ""))
end

---@param stats TeamStats
---@param frame LuaGuiElement
function populate_player_stats(stats, frame)
    local scrollpanel = frame.add { type = "scroll-pane", name = "scroll_pane_player_stats", direction = "vertical", horizontal_scroll_policy = "never", vertical_scroll_policy = "auto" }
    local top_centering_table = scrollpanel.add { type = "table", name = "top_centering_table", column_count = 1 }
    top_centering_table.style.column_alignments[1] = "center"
    local top_label = top_centering_table.add { type = "label", caption = "Player stats for first hour of game" }
    top_label.style.font = "heading-2"
    local cols = {
        {"Force"},
        {"Player"},
        {"Playtime"},
        {"Craft%", "Approximate percentage of time that this player was crafting."},
        {"Avg Inv Value", "Approximate average value of the player's inventory."},
        {"Placed value/min", "Value of placed items per minute."},
        {"Placed"},
    }
    local player_table = top_centering_table.add { type = "table", name = "player_table", column_count = #cols, vertical_centering = false, draw_horizontal_line_after_headers = true }
    player_table.style.cell_padding = 4
    for idx, col_info in ipairs(cols) do
        if idx == 3 or idx == 4 or idx == 5 or idx == 6 then
            player_table.style.column_alignments[idx] = "right"
        end
        local l = player_table.add { type = "label", caption = col_info[1], tooltip = col_info[2] }
        l.style.font = "default-small"
    end
    ---@alias PlayerTableEntry {force_name: string, player_name: string, craft_frac: number, avg_inv_value: number, placed_val_per_min: number, total_placed_cost: number, playtime_ticks: number, placed: table<string, {built: number, mined: number}>}
    ---@type PlayerTableEntry[]
    local player_table_entries = {}
    ---@type table<string, number>
    local max_placed_per_item = {}
    for _, force_name in ipairs({"north", "south"}) do
        local force_stats_players = stats.forces[force_name].players
        for player_name, info in pairs(force_stats_players) do
            local player_ticks = info.player_ticks
            if player_ticks and player_ticks >= 1 then
                -- eventually maybe skip players who have played less than 10 minutes
                local total_cost = 0
                for item, item_info in pairs(info.built_entities) do
                    local placed = math_max((item_info.built or 0) - (item_info.mined or 0), 0)
                    total_cost = total_cost + ItemCosts.get_cost(item) * placed
                    max_placed_per_item[item] = math_max(max_placed_per_item[item] or 0, placed)
                end
                local entry = {
                    force_name = force_name,
                    player_name = player_name,
                    craft_frac = (info.crafting_ticks or 0) / player_ticks,
                    avg_inv_value = (info.inventory_value_cumulative or 0) / player_ticks,
                    placed_val_per_min = total_cost * 3600.0 / player_ticks,
                    total_placed_cost = total_cost,
                    playtime_ticks = player_ticks,
                    placed = info.built_entities,
                }
                table.insert(player_table_entries, entry)
            end
        end
    end
    local sort_order = {{"force_name", 1}, {"placed_val_per_min", -1}}
    table.sort(player_table_entries,
        function(a, b)
            for _, order in ipairs(sort_order) do
                local col = order[1]
                local dir = order[2]
                local a_val = a[col]
                local b_val = b[col]
                if a_val ~= b_val then
                    if dir == 1 then
                        return a_val < b_val
                    else
                        return a_val > b_val
                    end
                end
            end
            return a.player_name < b.player_name
        end)
    for _, entry in ipairs(player_table_entries) do
        local player_name = entry.player_name
        local l = player_table.add { type = "label", caption = Functions.short_team_name_with_color(entry.force_name) }
        l.style.font = "default-small"
        local player = game.get_player(player_name)
        l = player_table.add { type = "label", caption = (player and PlayerUtil.player_name_with_color(player) or player_name) }
        l.style.font = "default-small"
        l = player_table.add { type = "label", caption = ticks_to_hh_mm(entry.playtime_ticks) }
        l.style.font = "default-small"
        l = player_table.add { type = "label", caption = string_format("%.1f%%", entry.craft_frac * 100) }
        l.style.font = "default-small"
        l = player_table.add { type = "label", caption = string_format("%d", entry.avg_inv_value) }
        l.style.font = "default-small"
        l = player_table.add { type = "label", caption = string_format("%d", entry.placed_val_per_min) }
        l.style.font = "default-small"
        -- add horizontal flow, with each of per_player_build_items_to_display as a sprite with number
        local player_flow = player_table.add { type = "flow", name = "player_flow_" .. entry.force_name .. "_" .. player_name, direction = "horizontal" }
        for _, item_name in ipairs(TeamStatsCollect.per_player_build_items_to_display) do
            local item_info = entry.placed[item_name]
            local built = item_info and item_info.built or 0
            local mined = item_info and item_info.mined or 0
            local net_built = math_max(0, built - mined)
            local style = "slot"
            if net_built > 0.5 * (max_placed_per_item[item_name] or 0) then
                style = "green_slot"
            elseif net_built > 0.1 * (max_placed_per_item[item_name] or 0) then
                style = "yellow_slot"
            end
            local b = player_flow.add { type = "sprite-button", style = style, sprite = "item/" .. item_name, number = net_built, tooltip = string_format("Built %d, Mined %d", built, mined) }
            --b.enabled = false
            gui_style(b, {width = 30, height = 30, padding = -2})
        end
        local tooltip_items = {}
        local total_built = 0
        for item, item_info in pairs(entry.placed) do
            if item_info.built - item_info.mined > 0 then
                table.insert(tooltip_items, { item_info.built - item_info.mined, item })
                total_built = total_built + item_info.built - item_info.mined
            end
        end
        table.sort(tooltip_items, function(a, b) return a[1] > b[1] end)
        local tooltips = {}
        for _, item_info in ipairs(tooltip_items) do
            table.insert(tooltips, string_format("[item=%s]: %d", item_info[2], item_info[1]))
        end
        local b = player_flow.add { type = "sprite-button", style = "slot", sprite = "info", number = total_built, tooltip = table.concat(tooltips, "\n") }
        b.enabled = false
        gui_style(b, {width = 30, height = 30, padding = -2})
    end
end

---@param player LuaPlayer
---@param stats TeamStats
---@param show_playerstats boolean
function TeamStatsCompare.show_stats(player, stats, show_playerstats)
    if stats == nil then
        stats = TeamStatsCollect.compute_stats()
    end
    ---@type LuaGuiElement
    local frame = player.gui.screen["teamstats_frame"]
    if frame then
        frame.destroy()
    end
    frame = closable_frame.create_main_closable_frame(player, "teamstats_frame", "Team statistics")
    gui_style(frame, { padding = 8 })
    if show_playerstats then
        populate_player_stats(stats, frame)
        return
    end
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
    if true then
        local shared_frame = top_table.add { type = "frame", name = "summary_shared", direction = "vertical" }
        local centering_table = shared_frame.add { type = "table", name = "centering_table", column_count = 1 }
        centering_table.style.column_alignments[1] = "center"
        local l
        l = centering_table.add { type = "label", caption = string_format("Difficulty: %s (%d%%)", (stats.difficulty or ""), (stats.difficulty_value or 0) * 100) }
        l.style.font = "default-small"
        l = centering_table.add { type = "label", caption = string_format("Duration: %s", ticks_to_hh_mm(stats.ticks or 0)) }
        l.style.font = "default-small"
        if stats.won_by_team then
            l = centering_table.add { type = "label", caption = string_format("Winner: %s", stats.won_by_team == "north" and "North" or "South") }
            l.style.font = "default-small"
        end
    end
    add_simple_force_stats("south", top_table)

    local two_table = top_centering_table.add { type = "table", name = "two_table", column_count = 2, vertical_centering = true }
    local font = "default-small"
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
            local l = science_table.add { type = "label", caption = col_info[1], tooltip = col_info[2] }
            l.style.font = font
        end
        local total_sent_mutagen = 0
        for _, food in ipairs(Tables.food_long_and_short) do
            local force_stats = stats.forces[force_name]
            local food_stats = force_stats.food[food.long_name] or {}
            local l
            l = science_table.add { type = "label", caption = string_format("[item=%s]", food.long_name) }
            l.style.font = font
            l = science_table.add { type = "label", caption = (food_stats.first_at and ticks_to_hh_mm(food_stats.first_at) or "") }
            l.style.font = font
            l = science_table.add { type = "label", caption = format_with_thousands_sep(food_stats.produced or 0) }
            l.style.font = font
            l = science_table.add { type = "label", caption = format_with_thousands_sep(food_stats.consumed or 0) }
            l.style.font = font
            l = science_table.add { type = "label", caption = food_stats.sent and format_with_thousands_sep(food_stats.sent) or "0" }
            l.style.font = font
            total_sent_mutagen = total_sent_mutagen + (food_stats.sent or 0) * Tables.food_values[food.long_name].value
        end
        local l = science_flow.add { type = "label", caption = string_format("[item=space-science-pack] equivalent %d", total_sent_mutagen / Tables.food_values["space-science-pack"].value) }
        l.style.font = font
    end

    two_table.add { type = "line" }
    two_table.add { type = "line" }
    for _, force_name in ipairs({"north", "south"}) do
        local item_table = two_table.add { type = "table", name = "item_table_" .. force_name, column_count = 5, vertical_centering = false }
        gui_style(item_table, { left_cell_padding = 3, right_cell_padding = 3, vertical_spacing = 0})
        local cols = {
            {""},
            {"First [img=info]", "The time that the first item was produced."},
            {"Produced"},
            {"Placed [img=info]", "The highest value of (constructed-deconstructed) over time."},
            {"Lost"},
        }
        for idx, col_info in ipairs(cols) do
            item_table.style.column_alignments[idx] = "right"
            local l = item_table.add { type = "label", caption = col_info[1], tooltip = col_info[2] }
            l.style.font = font
        end

        for _, item_info in ipairs(TeamStatsCollect.items_to_show_summaries_of) do
            local force_stats = stats.forces[force_name]
            local item_stats = force_stats.items[item_info.item] or {}
            local killed_or_lost = (item_stats.kill_count or 0) + (item_stats.lost or 0)
            if killed_or_lost == 0 then killed_or_lost = nil end
            local l
            l = item_table.add { type = "label", caption = string_format("[item=%s]", item_info.item) }
            l.style.font = font
            if item_info.space_after then
                l.style.bottom_padding = 12
            end
            l = item_table.add { type = "label", caption = (item_stats.first_at and ticks_to_hh_mm(item_stats.first_at) or "") }
            l.style.font = font
            l = item_table.add { type = "label", caption = format_with_thousands_sep(item_stats.produced or 0) }
            l.style.font = font
            l = item_table.add { type = "label", caption = item_stats.placed and format_with_thousands_sep(item_stats.placed) or "" }
            l.style.font = font
            l = item_table.add { type = "label", caption = killed_or_lost and format_with_thousands_sep(killed_or_lost) or "" }
            l.style.font = font
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
                local l = damage_table.add { type = "label", caption = col_info[1], tooltip = col_info[2] }
                l.style.font = font
            end

            local force_stats = stats.forces[force_name]
            local total_kills = 0
            local total_damage = 0
            for _, damage_render_info in ipairs(TeamStatsCollect.damage_render_info) do
                if damage_types_to_render[damage_render_info[1]] then
                    local damage_info = force_stats.damage_types[damage_render_info[1]] or {}
                    total_kills = total_kills + (damage_info.kills or 0)
                    total_damage = total_damage + (damage_info.damage or 0)
                    local l
                    l = damage_table.add { type = "label", caption = damage_render_info[2], tooltip = damage_render_info[3] }
                    l.style.font = font
                    l = damage_table.add { type = "label", caption = format_with_thousands_sep(damage_info.kills or 0) }
                    l.style.font = font
                    l = damage_table.add { type = "label", caption = format_with_thousands_sep(damage_info.damage or 0) }
                    l.style.font = font
                end
            end
            local l
            l = damage_table.add { type = "label", caption = "Total" }
            l.style.font = font
            l = damage_table.add { type = "label", caption = format_with_thousands_sep(total_kills) }
            l.style.font = font
            l = damage_table.add { type = "label", caption = format_with_thousands_sep(total_damage) }
            l.style.font = font
        end
    end
end

function TeamStatsCompare.game_over()
    for _, player in pairs(game.connected_players) do
        safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player)
    end
    global.prev_game_team_stats = global.team_stats
end

commands.add_command("teamstats", "Show team stats", function (cmd)
    if not cmd.player_index then return end
    local player = game.get_player(cmd.player_index)
    if not player then return end
    local prev = false
    local show_playerstats = false
    local deny_reason
    for word in string.gmatch(cmd.parameter or "", "%S+") do
        if word == "prev" then
            prev = true
        elseif word == "alpha_playerstats" then
            show_playerstats = true
        else
            player.print("Unsupported argument to /teamstats. Run either just '/teamstats' or '/teamstats prev'")
            return
        end
    end
    local stats
    if prev then
        stats = global.prev_game_team_stats
        if not stats then
            player.print("No previous game stats available.")
            return
        end
    end
    -- allow it always in singleplayer, or if the game is over
    if not stats and not global.bb_game_won_by_team and game.is_multiplayer() then
        if global.allow_teamstats == "spectators" then
            if player.force.name ~= "spectator" then deny_reason = "spectators only" end
        elseif global.allow_teamstats == "pure-spectators" then
            if global.chosen_team[player.name] then deny_reason = "pure spectators only (you have joined a team)" end
        else
            if global.allow_teamstats ~= "always" then deny_reason = "only allowed at end of game" end
        end
    end
    if deny_reason then
        player.print("/teamstats for current game is unavailable: " .. deny_reason .. "\nYou can use '/teamstats prev' to see stats for the previous game.")
        return
    end
    safe_wrap_with_player_print(player, TeamStatsCompare.show_stats, player, stats, show_playerstats)
end)

return TeamStatsCompare
