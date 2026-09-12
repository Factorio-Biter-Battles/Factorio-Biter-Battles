local CurrentSeed = require('comfy_panel.special_games.captain_impact_current_seed')
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local Store = require('comfy_panel.special_games.captain_impact_store')
local gui_style = require('utils.utils').gui_style

local Public = {}
local FRAME_NAME = 'captain_impact_leaderboard_ui'

local function snapshot_rows()
    local snapshot = Store.get_snapshot()
    if snapshot and snapshot.live_leaderboard and snapshot.leaderboard then
        return snapshot.leaderboard, snapshot.games or 0, true
    end
    if snapshot and snapshot.provisional_leaderboard then
        return snapshot.provisional_leaderboard, snapshot.games or 0, false
    end
    local rows = {}
    for name, current in pairs(CurrentSeed.players or {}) do
        local historical = Seed.impact_players and Seed.impact_players[name]
        rows[#rows + 1] = {
            rank = current.experimental_rank,
            player_name = name,
            games = historical and historical.games or 0,
            amwi_pp = current.adjusted_amwi_50_50_pp,
            pick_score = current.pick_score,
            idle_matches = current.idle_matches,
            freshness_factor = current.freshness_factor,
        }
    end
    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then
            return (a.rank or math.huge) < (b.rank or math.huge)
        end
        return a.player_name < b.player_name
    end)
    return rows, snapshot and snapshot.games or 0, false
end

local function text(value, fallback)
    if value == nil then
        return fallback or '-'
    end
    return tostring(value)
end

local function add_cell(parent, caption, style, tooltip)
    local label = parent.add({ type = 'label', caption = caption, tooltip = tooltip })
    if style then
        gui_style(label, style)
    end
    return label
end

local function draw_contents(frame)
    local rows, games, live = snapshot_rows()
    frame.status.caption = live
            and string.format('Live Impact Dynamic leaderboard · %d eligible games', games)
        or string.format(
            'Provisional Impact Dynamic leaderboard · 609-game prior · confidence gate at 20 eligible games (currently %d)',
            games
        )
    frame.body.clear()
    local tab = frame.body.add({ type = 'table', column_count = 6, style = 'mods_explore_results_table' })
    local header_style = { font = 'heading-2', minimal_width = 90, top_margin = 3, bottom_margin = 3 }
    add_cell(tab, 'Rank', header_style)
    add_cell(tab, 'Player', header_style)
    add_cell(tab, 'AMWI', header_style)
    add_cell(tab, 'Games', header_style)
    add_cell(tab, 'Pick signal', header_style)
    add_cell(tab, 'Freshness', header_style)
    for index, row in ipairs(rows) do
        if index > 100 then
            break
        end
        add_cell(tab, text(live and row.rank or (row.provisional_rank or row.rank)), { minimal_width = 55, horizontal_align = 'right' })
        add_cell(tab, text(row.player_name), { minimal_width = 160 })
        add_cell(
            tab,
            (live and row.amwi_pp or row.provisional_amwi_pp or row.amwi_pp)
                and string.format('%+.2f pp', live and row.amwi_pp or row.provisional_amwi_pp or row.amwi_pp)
                or '-',
            { minimal_width = 90, horizontal_align = 'right' },
            'Average Marginal Win Impact versus the established-player reference.'
        )
        add_cell(tab, text(row.games), { minimal_width = 65, horizontal_align = 'right' })
        add_cell(
            tab,
            row.pick_score and string.format('%.3f', row.pick_score) or '-',
            { minimal_width = 90, horizontal_align = 'right' },
            'Recency-weighted captain pick-position score. 1.000 is consistently early; 0.000 is consistently late.'
        )
        add_cell(
            tab,
            row.freshness_factor and string.format('%.3f', row.freshness_factor) or '-',
            { minimal_width = 90, horizontal_align = 'right' },
            row.idle_matches and string.format('%d historical matches since last appearance', row.idle_matches) or nil
        )
    end
end

function Public.close(player)
    if player and player.valid and player.gui.screen[FRAME_NAME] then
        player.gui.screen[FRAME_NAME].destroy()
    end
end

function Public.open(player)
    if not (player and player.valid and player.gui) then
        return
    end
    if player.gui.screen[FRAME_NAME] then
        Public.close(player)
        return
    end
    local frame = player.gui.screen.add({ type = 'frame', name = FRAME_NAME, direction = 'vertical' })
    frame.auto_center = true
    gui_style(frame, { minimal_width = 700, maximal_width = 900, minimal_height = 520, maximal_height = 760 })
    local title_flow = frame.add({ type = 'flow', direction = 'horizontal' })
    local title = title_flow.add({ type = 'label', caption = 'Captain Impact leaderboard', style = 'frame_title' })
    title.drag_target = frame
    local dragger = title_flow.add({ type = 'empty-widget', style = 'draggable_space_header' })
    dragger.drag_target = frame
    gui_style(dragger, { horizontally_stretchable = true, height = 24 })
    title_flow.add({ type = 'sprite-button', name = 'captain_impact_leaderboard_close', sprite = 'utility/close', style = 'frame_action_button' })
    local status = frame.add({ type = 'label', name = 'status', caption = '' })
    gui_style(status, { single_line = false, bottom_margin = 6 })
    local body = frame.add({ type = 'scroll-pane', name = 'body', direction = 'vertical' })
    gui_style(body, { horizontally_stretchable = true, vertically_stretchable = true, padding = 8 })
    draw_contents(frame)
end

function Public.refresh(player)
    if not (player and player.valid and player.gui and player.gui.screen[FRAME_NAME]) then
        return
    end
    draw_contents(player.gui.screen[FRAME_NAME])
end

function Public.refresh_all()
    if not game or not game.connected_players then
        return
    end
    for _, player in pairs(game.connected_players) do
        Public.refresh(player)
    end
end

function Public.handle_gui_click(event)
    local element = event.element
    if not (element and element.valid) then
        return false
    end
    local player = game.get_player(event.player_index)
    if not player then
        return false
    end
    if element.name == 'captain_impact_leaderboard_open' then
        Public.open(player)
        return true
    elseif element.name == 'captain_impact_leaderboard_close' then
        Public.close(player)
        return true
    end
    return false
end

return Public
