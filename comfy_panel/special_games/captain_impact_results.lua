local Seed = require('comfy_panel.special_games.captain_impact_seed')
local ImpactData = require('comfy_panel.special_games.captain_impact_data')
local Score = require('comfy_panel.score')
local gui_style = require('utils.utils').gui_style

local Public = {}
local FRAME_NAME = 'captain_impact_results_ui'
local role_captions = {}
for _, role in ipairs(Seed.roles or {}) do
    role_captions[role.key] = role.caption
end

local function text(value)
    return value == nil and '—' or tostring(value)
end

local function score_row(force_name, player_name)
    local score = Score.get_table()
    local force = score and score.score_table and score.score_table[force_name]
    local row = force and force.players and force.players[player_name]
    if not row then
        return nil
    end
    return { build = row.built_entities, defense = row.killscore }
end

local function role_row(match, force_name, player_name)
    for _, row in ipairs((match.starting_roster and match.starting_roster[force_name]) or {}) do
        if row.player_name == player_name then
            return row
        end
    end
    return nil
end

local function rows_for(match, force_name)
    local names, seen = {}, {}
    for _, row in ipairs((match.starting_roster and match.starting_roster[force_name]) or {}) do
        if row.player_name and not seen[row.player_name] then
            seen[row.player_name] = true
            names[#names + 1] = row.player_name
        end
    end
    for _, player_name in ipairs((match.final_roster and match.final_roster[force_name]) or {}) do
        if player_name and not seen[player_name] then
            seen[player_name] = true
            names[#names + 1] = player_name
        end
    end
    local rows = {}
    for _, player_name in ipairs(names) do
        local locked = role_row(match, force_name, player_name)
        local score = score_row(force_name, player_name) or {}
        rows[#rows + 1] = {
            player_name = player_name,
            primary_role = locked and role_captions[locked.primary_role] or nil,
            secondary_role = locked and role_captions[locked.secondary_role] or nil,
            effort_percent = locked and locked.effort_percent or nil,
            build = score.build,
            defense = score.defense,
        }
    end
    table.sort(rows, function(a, b)
        local ae = tonumber(a.effort_percent) or -1
        local be = tonumber(b.effort_percent) or -1
        if ae ~= be then
            return ae > be
        end
        return a.player_name:lower() < b.player_name:lower()
    end)
    return rows
end

local function add_cell(parent, caption, style, tooltip)
    local label = parent.add({ type = 'label', caption = caption, tooltip = tooltip })
    if style then
        gui_style(label, style)
    end
    return label
end

local function draw_contents(frame, match)
    local source = match.test_mode and 'manual test data is local and non-authoritative' or 'authoritative recorded game'
    frame.status.caption = string.format(
        'Completed Impact Dynamic game %s · winner: %s · %s',
        tostring(match.match_id or '?'),
        tostring(match.winner or '?'),
        source
    )
    if frame.result_summary then
        frame.result_summary.caption = string.format('Prediction: %s · draft balance: %s · model: %s', text(match.prediction), text(match.draft_balance_probability), text(match.model_version))
    end
    frame.body.clear()
    for _, force_name in ipairs({ 'north', 'south' }) do
        local section = frame.body.add({ type = 'flow', direction = 'vertical' })
        local section_title = section.add({ type = 'label', caption = string.upper(force_name), style = 'semibold_label' })
        section_title.style.font = 'heading-2'
        local table_gui = section.add({ type = 'table', column_count = 6, style = 'mods_explore_results_table' })
        local header_style = { font = 'heading-2', minimal_width = 90, top_margin = 3, bottom_margin = 3 }
        add_cell(table_gui, 'Player', header_style)
        add_cell(table_gui, 'Primary role', header_style)
        add_cell(table_gui, 'Secondary role', header_style)
        add_cell(table_gui, 'Effort', header_style)
        add_cell(table_gui, 'Build score', header_style, 'Existing BB score counter: built_entities / Built structures.')
        add_cell(table_gui, 'Defense score', header_style, 'Existing BB score counter: killscore, also used by the BB Defender MVP display.')
        local rows = rows_for(match, force_name)
        for _, row in ipairs(rows) do
            add_cell(table_gui, row.player_name, { minimal_width = 150 })
            add_cell(table_gui, text(row.primary_role), { minimal_width = 110 })
            add_cell(table_gui, text(row.secondary_role), { minimal_width = 110 })
            add_cell(table_gui, row.effort_percent and (tostring(row.effort_percent) .. '%') or '—', { minimal_width = 65, horizontal_align = 'right' })
            add_cell(table_gui, text(row.build), { minimal_width = 80, horizontal_align = 'right' })
            add_cell(table_gui, text(row.defense), { minimal_width = 90, horizontal_align = 'right' })
        end
        if #rows == 0 then
            local empty = section.add({ type = 'label', caption = 'No roster rows were recorded for this side. This test result is local and may have no live score counters.', style = 'semibold_label' })
            gui_style(empty, { single_line = false })
        end
        frame.body.add({ type = 'line' })
    end
end

function Public.close(player)
    if player and player.valid and player.gui.screen[FRAME_NAME] then
        player.gui.screen[FRAME_NAME].destroy()
    end
end

function Public.open(player)
    if not (player and player.valid and player.gui) then
        return false
    end
    local match = ImpactData.get_last_finished_match()
    if not match or match.draft_regime ~= 'impact_dynamic' then
        player.print('No completed Impact Dynamic game results are available yet.')
        return false
    end
    if player.gui.screen[FRAME_NAME] then
        Public.close(player)
        return true
    end
    local frame = player.gui.screen.add({ type = 'frame', name = FRAME_NAME, direction = 'vertical' })
    frame.auto_center = true
    gui_style(frame, { minimal_width = 900, maximal_width = 1200, minimal_height = 500, maximal_height = 800 })
    local title_flow = frame.add({ type = 'flow', direction = 'horizontal' })
    local title = title_flow.add({ type = 'label', caption = 'Captain Game — Effort & Performance', style = 'frame_title' })
    title.drag_target = frame
    local dragger = title_flow.add({ type = 'empty-widget', style = 'draggable_space_header' })
    dragger.drag_target = frame
    gui_style(dragger, { horizontally_stretchable = true, height = 24 })
    title_flow.add({ type = 'sprite-button', name = 'captain_impact_results_close', sprite = 'utility/close', style = 'frame_action_button' })
    frame.add({ type = 'label', name = 'status', caption = '' })
    frame.add({ type = 'label', name = 'result_summary', caption = '' })
    local body = frame.add({ type = 'scroll-pane', name = 'body', direction = 'vertical' })
    gui_style(body, { horizontally_stretchable = true, vertically_stretchable = true, padding = 8 })
    draw_contents(frame, match)
    return true
end

function Public.open_all()
    if not game or not game.connected_players then
        return
    end
    for _, player in pairs(game.connected_players) do
        if player.valid then
            -- Game-over should make the result panel visible. `open` is a
            -- user-facing toggle, so calling it on an already-open panel
            -- would otherwise close the panel at the exact moment results
            -- become available.
            if player.gui.screen[FRAME_NAME] then
                Public.refresh(player)
            else
                Public.open(player)
            end
        end
    end
end

function Public.refresh(player)
    if not (player and player.valid and player.gui.screen[FRAME_NAME]) then
        return
    end
    local match = ImpactData.get_last_finished_match()
    if match and match.draft_regime == 'impact_dynamic' then
        draw_contents(player.gui.screen[FRAME_NAME], match)
    end
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
    if element.name == 'captain_impact_results_open' then
        Public.open(player)
        return true
    elseif element.name == 'captain_impact_results_close' then
        Public.close(player)
        return true
    end
    return false
end

return Public
