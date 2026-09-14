local ClosableFrame = require('utils.ui.closable_frame')
local Event = require('utils.event')
local Functions = require('maps.biter_battles_v2.functions')
local Gui = require('utils.gui')
local Color = require('utils.color_presets')
local gui_style = require('utils.utils').gui_style
local TeamManager = require('maps.biter_battles_v2.team_manager')
local Seed = require('comfy_panel.special_games.captain_skill_seed')

local Public = {}

-- Reuse the established Captain UI screen slots so Skill Draft behaves like
-- the existing Captain mode instead of adding another lobby/picking window.
local FRAME_LOBBY = 'captain_player_gui'
local FRAME_DRAFT = 'captain_picking_ui'
local FRAME_LEADERBOARD = 'skill_draft_leaderboard_frame'
local FRAME_ROLE = 'skill_draft_role_frame'
local FRAME_RESULTS = 'skill_draft_results_frame'
local TOP_BUTTON = 'skill_draft_toggle_button'
local OLD_LOBBY_FRAME = 'skill_draft_lobby_frame'
local OLD_DRAFT_FRAME = 'skill_draft_draft_frame'

local roles = Seed.roles or {}
local role_captions = Seed.role_captions or {}
local role_importance = Seed.role_importance or {}
local role_importance_sum = Seed.role_importance_sum or 1
local scales = Seed.scales or {}
local published_count = (Seed.leaderboard and Seed.leaderboard.published_count) or #Seed.rows

local profiles = {}
local profiles_lower = {}
local fallback_profiles = {}

local function make_fallback_profile(name)
    local role_scores = {}
    for _, role in ipairs(roles) do
        role_scores[role] = 1
    end
    return {
        name = name,
        games = 0,
        wins = 0,
        win_rate = (Seed.defaults and Seed.defaults.win_rate) or 0.5,
        average_unweighted_role_score = (Seed.defaults and Seed.defaults.average_unweighted_role_score) or 1,
        weighted_role_score = role_importance_sum,
        skill = (Seed.defaults and Seed.defaults.skill) or role_importance_sum * 0.5,
        role_scores = role_scores,
        rank = nil,
        fallback = true,
    }
end

local function unpack_profile(row, rank)
    local scale_win = scales.win_rate or 1000000
    local scale_role = scales.role or 1000
    local scale_average = scales.average or 1000
    local scale_weighted = scales.weighted or 1000
    local scale_skill = scales.skill or 1000000
    local profile = {
        name = row[1],
        games = row[2] or 0,
        wins = row[3] or 0,
        win_rate = (row[4] or 0) / scale_win,
        last_match_index = row[5] and row[5] >= 0 and row[5] or nil,
        average_unweighted_role_score = (row[6] or 0) / scale_average,
        weighted_role_score = (row[7] or 0) / scale_weighted,
        skill = (row[8] or 0) / scale_skill,
        role_scores = {},
        rank = rank,
        fallback = false,
    }
    for role_index, role in ipairs(roles) do
        local value = row[8 + role_index]
        profile.role_scores[role] = value and value >= 0 and value / scale_role or nil
    end
    return profile
end

for row_index, row in ipairs(Seed.rows or {}) do
    if row_index <= published_count then
        local profile = unpack_profile(row, row_index)
        profiles[profile.name] = profile
        profiles_lower[string.lower(profile.name)] = profile
    end
end

local function get_profile(name)
    if profiles[name] then
        return profiles[name]
    end
    local lower_name = name and string.lower(name)
    if lower_name and profiles_lower[lower_name] then
        return profiles_lower[lower_name]
    end
    local fallback = fallback_profiles[name]
    if not fallback then
        fallback = make_fallback_profile(name)
        fallback_profiles[name] = fallback
    end
    return fallback
end

local function get_state()
    if not storage.active_special_games or not storage.active_special_games.captains_skill_draft then
        return nil
    end
    return storage.special_games_variables and storage.special_games_variables.captains_skill_draft
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function clamp_effort(value)
    return math.floor(clamp(tonumber(value) or 100, 0, 100) + 0.5)
end

local function effort_multiplier(effort)
    -- Effort maps directly to cost, with a hard 50% minimum.
    -- For example: 75 effort = 75% cost, 60 effort = 60% cost.
    return math.max(0.5, clamp_effort(effort) / 100)
end

local function draft_cost(name, state)
    return get_profile(name).skill * effort_multiplier(state.effort[name] or 100)
end

local function format_skill(value)
    return string.format('%.3f', value or 0)
end

local function format_percent(value)
    return string.format('%.1f%%', (value or 0) * 100)
end

local function role_tooltip(profile)
    local lines = { 'Role proficiency:' }
    for role_index, role in ipairs(roles) do
        local value = profile.role_scores[role]
        lines[#lines + 1] = role_captions[role_index] .. ': ' .. (value and string.format('%.2f / 10', value) or 'n/a')
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Draft cost at current effort: ' .. format_skill(profile.skill * effort_multiplier(100))
    return table.concat(lines, '\n')
end

local function is_captain(state, player_name)
    return state.captains.north == player_name or state.captains.south == player_name
end

local function can_control_draft(state, player)
    return
        player
        and player.valid
        and state.phase == 'draft'
        and state.current_force
        and state.captains[state.current_force] == player.name
end

local function is_operator(state, player)
    return player and player.valid and (player.admin or player.name == state.started_by or is_captain(state, player.name))
end

local function team_skill(state, force_name)
    local total = 0
    for _, name in ipairs(state.teams[force_name].members) do
        total = total + draft_cost(name, state)
    end
    return total
end

local function team_win_probability(state, force_name)
    local north = team_skill(state, 'north')
    local south = team_skill(state, 'south')
    if north + south <= 0 then
        return 0.5
    end
    if force_name == 'north' then
        return north / (north + south)
    end
    return south / (north + south)
end

local function next_force(state)
    local north = team_skill(state, 'north')
    local south = team_skill(state, 'south')
    if north < south - 0.000001 then
        return 'north'
    end
    if south < north - 0.000001 then
        return 'south'
    end

    local north_count = #state.teams.north.members
    local south_count = #state.teams.south.members
    if north_count < south_count then
        return 'north'
    end
    if south_count < north_count then
        return 'south'
    end
    if state.current_force == 'north' then
        return 'south'
    end
    return 'north'
end

local function destroy_frame(player, name)
    local frame = player.gui.screen[name]
    if frame and frame.valid then
        local main = ClosableFrame.get_main_closable_frame(player)
        if main == frame then
            ClosableFrame.close_all(player)
            return
        end
        if player.opened == frame then
            player.opened = nil
        end
        frame.destroy()
    end
end

local function close_skill_frames(player)
    local main = ClosableFrame.get_main_closable_frame(player)
    if main and main.valid and (main.name == FRAME_LOBBY or main.name == FRAME_DRAFT or main.name == FRAME_RESULTS) then
        ClosableFrame.close_all(player)
    end
    destroy_frame(player, FRAME_ROLE)
    destroy_frame(player, FRAME_LEADERBOARD)
    destroy_frame(player, FRAME_LOBBY)
    destroy_frame(player, FRAME_DRAFT)
    destroy_frame(player, FRAME_RESULTS)
    -- Clean up frames from the earlier prototype when a server updates in place.
    destroy_frame(player, OLD_LOBBY_FRAME)
    destroy_frame(player, OLD_DRAFT_FRAME)
end

local function ensure_top_button(player)
    if not player or not player.valid then
        return
    end
    Gui.add_top_element(player, {
        type = 'button',
        name = TOP_BUTTON,
        caption = 'Skill Draft',
        tooltip = 'Open the Captains Skill Draft window',
    })
end

local function add_explanation(frame, state)
    if not state.explanation_open then
        return
    end
    local explanation = frame.add({ type = 'frame', direction = 'vertical' })
    explanation.style.horizontally_stretchable = true
    local text = table.concat({
        'Ratings use the published seed leaderboard.',
        'Skill = win% × weighted role score.',
        'Weighted role score = the sum of each role proficiency × that role importance.',
        'Effort changes draft cost only: 75% effort costs 75% skill and 60% effort costs 60% skill.',
        'Below 50% effort the cost stays at the 50% floor, so the discount can never exceed 50%.',
        'After every pick, each team total includes its captain and all drafted players.',
        'The next pick goes to the team with the lower current win probability.',
        'Unseeded players use 50% win rate, 1.00 average role score, and the corresponding default skill.',
    }, '\n')
    local label = explanation.add({ type = 'label', caption = text })
    label.style.single_line = false
end

local function create_main(player, name, caption)
    close_skill_frames(player)
    local frame_caption = name == FRAME_LOBBY and 'Join Tournament' or caption
    local frame = ClosableFrame.create_main_closable_frame(player, name, frame_caption)
    if name == FRAME_LOBBY then
        frame.style.minimal_width = 600
        frame.style.maximal_width = 700
    else
        frame.style.minimal_width = 900
        frame.style.maximal_width = 1100
    end
    frame.style.minimal_height = 220
    return frame
end

local function sort_value(row, key)
    if key == 'player' or key == 'notes' then
        return string.lower(tostring(row[key] or ''))
    end
    if key == 'rank' and not row.rank then
        return 1000000
    end
    return row[key] or 0
end

local function projected_pick(state, player_name)
    local picking_force = state.current_force
    local north_skill = team_skill(state, 'north')
    local south_skill = team_skill(state, 'south')
    local added_skill = draft_cost(player_name, state)

    if picking_force == 'north' then
        north_skill = north_skill + added_skill
    else
        south_skill = south_skill + added_skill
    end

    local total_skill = north_skill + south_skill
    local north_probability = total_skill > 0 and north_skill / total_skill or 0.5
    local north_count = #state.teams.north.members + (picking_force == 'north' and 1 or 0)
    local south_count = #state.teams.south.members + (picking_force == 'south' and 1 or 0)
    local next_picking_force
    if north_skill < south_skill - 0.000001 then
        next_picking_force = 'north'
    elseif south_skill < north_skill - 0.000001 then
        next_picking_force = 'south'
    elseif north_count < south_count then
        next_picking_force = 'north'
    elseif south_count < north_count then
        next_picking_force = 'south'
    else
        next_picking_force = picking_force == 'north' and 'south' or 'north'
    end

    local keeps_next_pick = next_picking_force == picking_force
    return {
        north_probability = north_probability,
        south_probability = 1 - north_probability,
        next_picking_force = next_picking_force,
        keeps_next_pick = keeps_next_pick,
        caption = string.format(
            'N %.1f%% / S %.1f%% | %s',
            north_probability * 100,
            (1 - north_probability) * 100,
            keeps_next_pick and '2+ PICKS' or '1 PICK'
        ),
        tooltip = string.format(
            'If %s picks %s now: projected North win probability %.1f%%; South %.1f%%. Next pick: %s (%s).',
            string.upper(picking_force),
            player_name,
            north_probability * 100,
            (1 - north_probability) * 100,
            string.upper(next_picking_force),
            keeps_next_pick and 'the picking team keeps picking' or 'the turn passes'
        ),
    }
end

local function sorted_draft_rows(state)
    local rows = {}
    for _, name in ipairs(state.pool) do
        if not state.picked[name] then
            local profile = get_profile(name)
            local consequence = projected_pick(state, name)
            rows[#rows + 1] = {
                player = name,
                rank = profile.rank,
                games = profile.games,
                skill = profile.skill,
                effort = state.effort[name] or 100,
                notes = state.notes[name] or '',
                profile = profile,
                consequence = consequence.north_probability,
                consequence_caption = consequence.caption,
                consequence_tooltip = consequence.tooltip,
                consequence_keeps_next_pick = consequence.keeps_next_pick,
            }
        end
    end
    table.sort(rows, function(left, right)
        local left_value = sort_value(left, state.sort_key)
        local right_value = sort_value(right, state.sort_key)
        if left_value == right_value then
            return string.lower(left.player) < string.lower(right.player)
        end
        if state.sort_ascending then
            return left_value < right_value
        end
        return left_value > right_value
    end)
    return rows
end

local function add_header(table_element, caption, key, state, widths)
    local arrow = state.sort_key == key and (state.sort_ascending and ' ▲' or ' ▼') or ''
    local button = table_element.add({
        type = 'button',
        name = 'skill_draft_sort_' .. key,
        caption = caption .. arrow,
        tooltip = 'Sort ascending/descending',
    })
    gui_style(button, {
        font = 'heading-2',
        minimal_width = (widths or { player = 180, rank = 65, games = 75, skill = 90, effort = 80, consequence = 220, notes = 300 })[key],
        top_margin = 1,
        bottom_margin = 1,
        top_padding = 0,
        bottom_padding = 0,
        left_padding = 4,
        right_padding = 4,
    })
end

local function style_compact_draft_cell(element, width)
    element.style.minimal_width = width
    element.style.maximal_width = width
    element.style.top_margin = 0
    element.style.bottom_margin = 0
    element.style.top_padding = 0
    element.style.bottom_padding = 0
end

local function get_draft_layout(player)
    local width = 1250
    if player.display_resolution and player.display_scale then
        width = math.floor(player.display_resolution.width / player.display_scale) - 24
    end
    width = clamp(width, 1000, 1250)
    return {
        frame_width = width,
        list_width = width - 20,
        notes_width = clamp(width - 760, 260, 380),
        team_width = math.floor((width - 30) / 2),
    }
end

local function draw_leaderboard(player)
    local state = get_state()
    if not state then
        return
    end
    local main = ClosableFrame.get_main_closable_frame(player)
    if not main then
        return
    end
    if player.gui.screen[FRAME_LEADERBOARD] then
        ClosableFrame.close_secondary(player)
        return
    end

    local frame = ClosableFrame.create_secondary_closable_frame(player, FRAME_LEADERBOARD, 'Top 100 leaderboard')
    if not frame then
        return
    end
    frame.style.minimal_width = 1040
    frame.style.maximal_width = 1040
    local intro = frame.add({
        type = 'label',
        caption = 'Published seed leaderboard. Players outside this list use the unseeded defaults.',
    })
    intro.style.single_line = false

    local scroll = frame.add({ type = 'scroll-pane', horizontal_scroll_policy = 'never' })
    scroll.style.minimal_width = 1020
    scroll.style.maximal_width = 1020
    scroll.style.maximal_height = 680
    local table_element = scroll.add({ type = 'table', column_count = 7, draw_vertical_lines = true })
    local headers = { 'Rank', 'Player', 'Skill', 'Win%', 'Games', 'Avg role', 'Weighted role' }
    local widths = { 55, 180, 90, 80, 75, 135, 145 }
    for header_index, header in ipairs(headers) do
        local label = table_element.add({ type = 'label', caption = header })
        label.style.font = 'default-bold'
        label.style.minimal_width = widths[header_index]
    end
    local seed_scale = scales.skill or 1000000
    for row_index, row in ipairs(Seed.rows or {}) do
        if row_index > published_count then
            break
        end
        local profile = unpack_profile(row, row_index)
        local rank_label = table_element.add({ type = 'label', caption = tostring(row_index) })
        rank_label.style.minimal_width = widths[1]
        local name_label = table_element.add({ type = 'label', caption = profile.name })
        name_label.style.minimal_width = widths[2]
        local skill_label = table_element.add({ type = 'label', caption = format_skill(row[8] / seed_scale) })
        skill_label.tooltip = role_tooltip(profile)
        skill_label.style.minimal_width = widths[3]
        local win_label = table_element.add({ type = 'label', caption = format_percent(profile.win_rate) })
        win_label.style.minimal_width = widths[4]
        local games_label = table_element.add({ type = 'label', caption = tostring(profile.games) })
        games_label.style.minimal_width = widths[5]
        local average_label = table_element.add({ type = 'label', caption = string.format('%.3f', profile.average_unweighted_role_score) })
        average_label.style.minimal_width = widths[6]
        local weighted_label = table_element.add({ type = 'label', caption = string.format('%.3f', profile.weighted_role_score) })
        weighted_label.style.minimal_width = widths[7]
    end
end

local function add_shared_buttons(frame, state, player)
    local controls = frame.add({ type = 'flow', direction = 'horizontal' })
    controls.style.horizontal_align = 'center'
    controls.add({ type = 'button', name = 'skill_draft_explain', caption = state.explanation_open and 'Hide rating explanation' or 'How ratings work' })
    controls.add({ type = 'button', name = 'skill_draft_leaderboard', caption = 'Top 100 leaderboard' })
    if state.phase == 'lobby' and is_operator(state, player) then
        controls.add({ type = 'button', name = 'skill_draft_start', caption = state.test_mode and 'Start bot playtest' or 'Start draft' })
    end
end

local function draw_lobby(player)
    local state = get_state()
    if not state or state.phase ~= 'lobby' then
        return
    end
    local frame = create_main(player, FRAME_LOBBY, 'Captains Skill Draft — Lobby')
    -- Keep the established Captain lobby layout. Skill Draft adds its effort
    -- control inside the same Join Tournament frame and keeps the legacy
    -- button names so the two modes share the same lobby interaction points.
    local title_wrap = frame.add({ type = 'flow', name = 'title_flow', direction = 'vertical' })
    local title_flow = title_wrap.add({ type = 'flow', name = 'inner_flow', direction = 'horizontal' })
    gui_style(title_flow, {
        horizontally_stretchable = true,
        vertically_stretchable = true,
        vertical_align = 'center',
        horizontal_align = 'center',
    })
    Gui.add_pusher(title_flow)
    local title_icon = title_flow.add({ type = 'sprite-button', sprite = 'utility/side_menu_achievements_icon', style = 'transparent_slot' })
    title_icon.ignored_by_interaction = true
    gui_style(title_icon, { size = 40 })
    Gui.add_pusher(title_flow)
    local title = title_flow.add({ type = 'label', caption = 'A CAPTAINS GAME WILL START SOON!', style = 'frame_title' })
    title.style.single_line = false
    Gui.add_pusher(title_flow)
    local title_icon_right = title_flow.add({ type = 'sprite-button', sprite = 'utility/side_menu_achievements_icon', style = 'transparent_slot' })
    title_icon_right.ignored_by_interaction = true
    gui_style(title_icon_right, { size = 40 })
    Gui.add_pusher(title_flow)
    title_wrap.add({ type = 'line' })

    local participants = {}
    for name in pairs(state.participants) do
        participants[#participants + 1] = name
    end
    table.sort(participants, function(left, right)
        return string.lower(left) < string.lower(right)
    end)
    local volunteers = {}
    if state.captains.north then
        volunteers[#volunteers + 1] = 'North: ' .. state.captains.north
    end
    if state.captains.south then
        volunteers[#volunteers + 1] = 'South: ' .. state.captains.south
    end

    local prep_flow = frame.add({ type = 'flow', name = 'prepa_flow', direction = 'vertical' })
    gui_style(prep_flow, { horizontally_stretchable = true })
    local players_label = prep_flow.add({
        type = 'label',
        name = 'want_to_play_players_list',
        caption = 'Players (' .. #participants .. '): ' .. (#participants > 0 and table.concat(participants, ', ') or 'None'),
    })
    players_label.style.single_line = false
    local volunteers_label = prep_flow.add({
        type = 'label',
        name = 'captain_volunteers_list',
        caption = 'Captain volunteers (' .. #volunteers .. '): ' .. (#volunteers > 0 and table.concat(volunteers, ', ') or 'None'),
    })
    volunteers_label.style.single_line = false
    prep_flow.add({ type = 'label', caption = 'Skill Draft uses an open player pool; groups are not required.' })
    local captain_status = prep_flow.add({
        type = 'label',
        name = 'status_label',
        caption = 'Captains — North: ' .. (state.captains.north or 'Open') .. ' | South: ' .. (state.captains.south or 'Open'),
    })
    captain_status.style.single_line = false
    if state.test_mode then
        prep_flow.add({ type = 'label', caption = 'Bot playtest: 30 random players will be selected from the published seed.' })
    end
    prep_flow.add({ type = 'line' })

    local effort_flow = frame.add({ type = 'flow', name = 'effort_flow', direction = 'horizontal' })
    effort_flow.add({ type = 'label', caption = 'Effort: ' })
    local slider = effort_flow.add({
        type = 'slider',
        name = 'skill_draft_effort_slider',
        minimum_value = 0,
        maximum_value = 100,
        value = clamp_effort(state.effort[player.name] or 100),
        discrete_slider = true,
    })
    slider.style.minimal_width = 360
    local effort_label = effort_flow.add({ type = 'label', name = 'skill_draft_effort_value' })
    effort_label.caption = clamp_effort(state.effort[player.name] or 100) .. '% (cost multiplier ' .. string.format('%.2f', effort_multiplier(state.effort[player.name] or 100)) .. ')'

    local info_flow = frame.add({ type = 'flow', name = 'info_flow', direction = 'vertical' })
    gui_style(info_flow, { horizontally_stretchable = true })
    local info_label = info_flow.add({ type = 'label', name = 'captain_player_info_label', caption = 'Notes for the captains:' })
    info_label.style.single_line = false
    local textbox_flow = info_flow.add({ type = 'flow', name = 'insert', direction = 'horizontal' })
    gui_style(textbox_flow, { horizontal_spacing = 5 })
    Gui.add_pusher(textbox_flow)
    local notes = textbox_flow.add({ type = 'textfield', name = 'captain_player_info', text = state.notes[player.name] or '' })
    gui_style(notes, { horizontally_stretchable = true, width = 380 })
    textbox_flow.add({
        type = 'sprite-button',
        sprite = 'utility/close_black',
        name = 'captain_player_clear_player_info',
        style = 'tool_button_red',
        tooltip = 'Clear player notes',
    })
    textbox_flow.add({
        type = 'sprite-button',
        sprite = 'utility/check_mark',
        name = 'captain_player_confirm_player_info',
        style = 'tool_button_green',
        tooltip = 'Save player notes',
    })
    Gui.add_pusher(textbox_flow)
    info_flow.add({ type = 'line' })

    local join_flow = frame.add({ type = 'flow', name = 'join_flow', direction = 'horizontal' })
    gui_style(join_flow, { horizontal_align = 'center', margin = 8 })
    Gui.add_pusher(join_flow)
    local join_table = join_flow.add({ type = 'table', name = 'table', column_count = 2 })
    local leave_button = join_table.add({
        type = 'button',
        name = 'captain_player_do_not_want_to_play',
        caption = "Nevermind, I don't want to play",
        style = 'red_back_button',
        tooltip = 'Leave the Skill Draft player pool',
    })
    gui_style(leave_button, { natural_width = 240, height = 28, horizontal_align = 'center', font = 'default-semibold' })
    local join_button = join_table.add({
        type = 'button',
        name = 'captain_player_want_to_play',
        caption = 'I want to play!',
        style = 'confirm_button',
        tooltip = 'Join the Skill Draft player pool',
    })
    gui_style(join_button, { natural_width = 200, height = 28, horizontal_align = 'left', font = 'default-semibold' })
    local withdraw_button = join_table.add({
        type = 'button',
        name = 'captain_player_do_not_want_to_be_captain',
        caption = "Nevermind, I don't want to captain",
        style = 'red_back_button',
        tooltip = 'Withdraw as a captain volunteer',
    })
    gui_style(withdraw_button, { natural_width = 240, height = 28, horizontal_align = 'center', font = 'default-semibold' })
    local volunteer_button = join_table.add({
        type = 'button',
        name = 'captain_player_want_to_be_captain',
        caption = 'I want to be a CAPTAIN!',
        style = 'confirm_button',
        tooltip = 'Volunteer for an open captain slot',
    })
    gui_style(volunteer_button, { natural_width = 200, height = 28, horizontal_align = 'left', font = 'default-semibold' })
    Gui.add_pusher(join_flow)

    frame.add({ type = 'line' })
    add_shared_buttons(frame, state, player)
    add_explanation(frame, state)
end

local function draw_team_composition(parent, state, force_name, width)
    local team_frame = parent.add({
        type = 'frame',
        name = 'skill_draft_' .. force_name .. '_composition',
        style = 'inside_shallow_frame_packed',
        direction = 'vertical',
    })
    team_frame.style.minimal_width = width
    team_frame.style.maximal_width = width
    local title = team_frame.add({
        type = 'label',
        caption = string.format(
            '%s team — %.3f skill (%s)',
            string.upper(force_name),
            team_skill(state, force_name),
            format_percent(team_win_probability(state, force_name))
        ),
    })
    title.style.font = 'heading-2'
    local members = {}
    for _, name in ipairs(state.teams[force_name].members) do
        members[#members + 1] = name .. ' — ' .. format_skill(draft_cost(name, state))
    end
    -- Keep the full composition visible in the draft window.  A scroll pane
    -- made the team preview look as if it contained only a few players; a
    -- two-column table keeps the complete list compact without hiding rows.
    local member_table = team_frame.add({
        type = 'table',
        name = 'members',
        column_count = 2,
        draw_vertical_lines = true,
    })
    member_table.style.horizontally_stretchable = true
    if #members == 0 then
        local empty = member_table.add({ type = 'label', caption = 'No players picked yet.' })
        empty.style.single_line = false
        empty.style.minimal_width = width - 20
    else
        local cell_width = math.max(120, math.floor((width - 24) / 2))
        for _, member in ipairs(members) do
            local label = member_table.add({ type = 'label', caption = member })
            label.style.single_line = false
            label.style.minimal_width = cell_width
            label.style.maximal_width = cell_width
        end
        if #members % 2 == 1 then
            member_table.add({ type = 'label', caption = '' })
        end
    end
end

local function draw_draft(player)
    local state = get_state()
    if not state or state.phase ~= 'draft' then
        return
    end
    local layout = get_draft_layout(player)
    local frame = create_main(player, FRAME_DRAFT, 'Captains Skill Draft — Drafting')
    frame.style.minimal_width = layout.frame_width
    frame.style.maximal_width = layout.frame_width
    frame.style.minimal_height = 800
    frame.style.maximal_height = 920
    local north_skill = team_skill(state, 'north')
    local south_skill = team_skill(state, 'south')
    local summary = frame.add({
        type = 'label',
        caption = string.format(
            'North %.3f (%s)    |    South %.3f (%s)    |    Next pick: %s captain %s',
            north_skill,
            format_percent(team_win_probability(state, 'north')),
            south_skill,
            format_percent(team_win_probability(state, 'south')),
            string.upper(state.current_force),
            state.captains[state.current_force]
        ),
    })
    summary.style.single_line = false
    local help = frame.add({ type = 'label', caption = 'Only the current captain can execute a pick. Everyone else can observe, sort, inspect tooltips, or close and reopen this window.' })
    help.style.single_line = false
    add_shared_buttons(frame, state, player)
    add_explanation(frame, state)

    local composition_flow = frame.add({ type = 'flow', name = 'skill_draft_team_composition', direction = 'horizontal' })
    composition_flow.style.horizontally_stretchable = true
    draw_team_composition(composition_flow, state, 'north', layout.team_width)
    draw_team_composition(composition_flow, state, 'south', layout.team_width)

    local rows = sorted_draft_rows(state)
    frame.add({ type = 'label', caption = 'Candidates remaining: ' .. #rows .. ' — click a column header to sort.' })
    local list_flow = frame.add({ type = 'flow', name = 'skill_draft_pick_flow', style = 'vertical_flow', direction = 'vertical' })
    local padded_flow = list_flow.add({ type = 'flow', name = 'skill_draft_padded_flow', direction = 'horizontal' })
    Gui.add_pusher(padded_flow)
    local list_frame = padded_flow.add({
        type = 'frame',
        name = 'skill_draft_pick_frame',
        style = 'inside_shallow_frame_packed',
        direction = 'vertical',
    })
    list_frame.style.minimal_width = layout.list_width
    list_frame.style.maximal_width = layout.list_width
    list_frame.style.minimal_height = 540
    list_frame.style.maximal_height = 620
    local scroll = list_frame.add({
        type = 'scroll-pane',
        name = 'skill_draft_player_table_scroll',
        direction = 'vertical',
        style = 'scroll_pane_under_subheader',
        horizontal_scroll_policy = 'never',
        vertical_scroll_policy = 'always',
    })
    scroll.style.minimal_width = layout.list_width - 8
    scroll.style.maximal_width = layout.list_width - 8
    scroll.style.minimal_height = 520
    scroll.style.maximal_height = 580
    scroll.style.vertically_squashable = false
    scroll.style.horizontally_squashable = false
    scroll.style.padding = 0
    local table_element = scroll.add({
        type = 'table',
        name = 'skill_draft_picks_list',
        column_count = 7,
        style = 'mods_explore_results_table',
        draw_vertical_lines = true,
    })
    table_element.style.vertically_squashable = false
    local column_widths = {
        player = 180,
        rank = 65,
        games = 75,
        skill = 90,
        effort = 80,
        consequence = 220,
        notes = layout.notes_width,
    }
    add_header(table_element, 'Player', 'player', state, column_widths)
    add_header(table_element, 'Rank', 'rank', state, column_widths)
    add_header(table_element, 'Games', 'games', state, column_widths)
    add_header(table_element, 'Skill', 'skill', state, column_widths)
    add_header(table_element, 'Effort', 'effort', state, column_widths)
    add_header(table_element, 'If picked next', 'consequence', state, column_widths)
    add_header(table_element, 'Notes', 'notes', state, column_widths)

    for _, row in ipairs(rows) do
        local player_flow = table_element.add({ type = 'flow', direction = 'horizontal' })
        player_flow.style.horizontal_spacing = 4
        player_flow.style.top_margin = 0
        player_flow.style.bottom_margin = 0
        player_flow.style.top_padding = 0
        player_flow.style.bottom_padding = 0
        if can_control_draft(state, player) then
            local pick_button = player_flow.add({
                type = 'sprite-button',
                name = 'skill_draft_pick_player',
                sprite = 'utility/enter',
                style = 'green_button',
                tags = { player_name = row.player },
            })
            pick_button.style.top_padding = 0
            pick_button.style.bottom_padding = 0
            pick_button.tooltip = 'Pick ' .. row.player
        end
        local status_sprite = player_flow.add({
            type = 'sprite',
            sprite = 'utility/status_not_working',
            tooltip = 'This player is currently disconnected',
        })
        gui_style(status_sprite, { width = 12, height = 12 })
        local candidate = game.get_player(row.player)
        if candidate and candidate.connected then
            status_sprite.sprite = 'utility/status_working'
            status_sprite.tooltip = 'This player is currently connected'
        end
        local player_label = player_flow.add({ type = 'label', caption = row.player, style = 'tooltip_label' })
        style_compact_draft_cell(player_label, 145)
        local rank_label = table_element.add({ type = 'label', caption = row.rank and tostring(row.rank) or '-', style = 'tooltip_label' })
        style_compact_draft_cell(rank_label, 65)
        local games_label = table_element.add({ type = 'label', caption = tostring(row.games), style = 'tooltip_label' })
        style_compact_draft_cell(games_label, 75)
        local skill_label = table_element.add({ type = 'label', caption = format_skill(row.skill), style = 'tooltip_label' })
        skill_label.tooltip = role_tooltip(row.profile)
        style_compact_draft_cell(skill_label, 90)
        local effort_label = table_element.add({ type = 'label', caption = tostring(row.effort) .. '%', style = 'tooltip_label' })
        style_compact_draft_cell(effort_label, 80)
        local consequence_label = table_element.add({ type = 'label', caption = row.consequence_caption, style = 'tooltip_label' })
        consequence_label.tooltip = row.consequence_tooltip
        style_compact_draft_cell(consequence_label, 220)
        consequence_label.style.font_color = row.consequence_keeps_next_pick and Color.light_green or Color.yellow
        local notes_label = table_element.add({ type = 'label', caption = row.notes, style = 'tooltip_label' })
        style_compact_draft_cell(notes_label, layout.notes_width)
        notes_label.style.single_line = false
    end
    Gui.add_pusher(padded_flow)
end

local function auto_roles(profile)
    local role_values = {}
    for role_index, role in ipairs(roles) do
        role_values[#role_values + 1] = { role = role, value = profile.role_scores[role] or 1, index = role_index }
    end
    table.sort(role_values, function(left, right)
        if left.value == right.value then
            return left.index < right.index
        end
        return left.value > right.value
    end)
    return { primary = role_values[1] and role_values[1].role or roles[1], secondary = role_values[2] and role_values[2].role or nil }
end

local function selected_role(selection, index, allow_none)
    if allow_none and index == 1 then
        return nil
    end
    local role_index = allow_none and index - 1 or index
    return roles[role_index]
end

local function all_roles_confirmed(state)
    for _, confirmed in pairs(state.role_confirmed) do
        if not confirmed then
            return false
        end
    end
    return true
end

local finish_roles

local function role_members(state)
    local members = {}
    local seen = {}
    for _, force_name in ipairs({ 'north', 'south' }) do
        for _, name in ipairs(state.teams[force_name].members) do
            if not seen[name] then
                seen[name] = true
                members[#members + 1] = name
            end
        end
    end
    return members
end

local function begin_role_phase(state)
    state.phase = 'roles'
    state.role_confirmed = {}
    state.roles_selected = {}
    for _, player in pairs(game.connected_players) do
        close_skill_frames(player)
    end
    for _, name in ipairs(role_members(state)) do
        local player = game.get_player(name)
        if state.virtual[name] or not player or not player.connected then
            state.roles_selected[name] = auto_roles(get_profile(name))
            state.role_confirmed[name] = true
        else
            state.role_confirmed[name] = false
        end
    end
    game.print('Draft complete. Every player must confirm a primary role; a secondary role is optional.')
    if all_roles_confirmed(state) then
        finish_roles(state)
    end
end

local defense_importance = {
    main_builder = 0.25,
    mining_support = 0.25,
    smelter_support = 0.25,
    oil_support = 0.20,
    power_support = 0.30,
    defender = 1.00,
    early_sci_outpost = 0.20,
    late_sci_parts_outpost = 0.30,
    defense_laser_outpost = 1.00,
    blueprint_filler = 0.10,
    teamwork_comms = 0.35,
}

local function transparent_score(profile, selected, effort, importance_map)
    if not selected or not selected.primary then
        return 0
    end
    local primary_importance = importance_map[selected.primary] or 0
    local secondary_importance = selected.secondary and (importance_map[selected.secondary] or 0) or 0
    local denominator = 10 * (primary_importance + 0.5 * secondary_importance)
    if denominator <= 0 then
        return 0
    end
    local primary = (profile.role_scores[selected.primary] or 1) * primary_importance
    local secondary = selected.secondary and (profile.role_scores[selected.secondary] or 1) * secondary_importance * 0.5 or 0
    return clamp((primary + secondary) / denominator * 100 * effort_multiplier(effort), 0, 100)
end

local function build_and_defense_scores(name, state)
    local profile = get_profile(name)
    local selected = state.roles_selected[name]
    local build_importance = {}
    for role_index, role in ipairs(roles) do
        build_importance[role] = role_importance[role_index] or 0
    end
    return transparent_score(profile, selected, state.effort[name] or 100, build_importance),
        transparent_score(profile, selected, state.effort[name] or 100, defense_importance)
end

local function draw_role(player)
    local state = get_state()
    if not state or state.phase ~= 'roles' or state.role_confirmed[player.name] then
        return
    end
    destroy_frame(player, FRAME_ROLE)
    local frame = player.gui.screen.add({ type = 'frame', name = FRAME_ROLE, direction = 'vertical' })
    frame.auto_center = true
    frame.style.minimal_width = 520
    frame.style.maximal_width = 620
    frame.add({ type = 'label', caption = 'Choose your roles for this match' }).style.font = 'heading-1'
    local instruction = frame.add({ type = 'label', caption = 'Primary role is mandatory. Secondary role is optional and must differ from the primary role. This window cannot be closed until you confirm.' })
    instruction.style.single_line = false

    local primary_flow = frame.add({ type = 'flow', name = 'primary_flow', direction = 'horizontal' })
    primary_flow.add({ type = 'label', caption = 'Primary role: ' })
    local primary = primary_flow.add({ type = 'drop-down', name = 'skill_draft_primary_role', items = role_captions, selected_index = 1 })
    primary.style.minimal_width = 330

    local secondary_items = { 'None' }
    for _, caption in ipairs(role_captions) do
        secondary_items[#secondary_items + 1] = caption
    end
    local secondary_flow = frame.add({ type = 'flow', name = 'secondary_flow', direction = 'horizontal' })
    secondary_flow.add({ type = 'label', caption = 'Secondary role: ' })
    local secondary = secondary_flow.add({ type = 'drop-down', name = 'skill_draft_secondary_role', items = secondary_items, selected_index = 1 })
    secondary.style.minimal_width = 330
    frame.add({ type = 'button', name = 'skill_draft_confirm_roles', caption = 'Confirm roles' })
    player.opened = frame
end

local function start_match(state)
    state.phase = 'playing'
    state.match_started_tick = game.ticks_played
    storage.tournament_mode = false
    storage.chosen_team = storage.chosen_team or {}
    state.assigned_team = {}
    for _, force_name in ipairs({ 'north', 'south' }) do
        for _, name in ipairs(state.teams[force_name].members) do
            if not state.virtual[name] and not state.assigned_team[name] then
                state.assigned_team[name] = force_name
                storage.chosen_team[name] = force_name
                local player = game.get_player(name)
                if player and player.connected then
                    TeamManager.switch_force(name, force_name)
                end
            end
        end
    end
    -- A fresh draft must own the match timer even if the lobby was opened on a
    -- map where the normal Biter Battles start hook has already run.
    storage.bb_game_start_tick = nil
    Functions.set_game_start_tick()
    game.print('Captains Skill Draft teams are ready. The match has started.')
end

finish_roles = function(state)
    if not all_roles_confirmed(state) then
        return
    end
    if state.test_mode then
        state.phase = 'results'
        game.print('Seeded bot playtest complete. No live Biter Battles match was started.')
    else
        start_match(state)
    end
end

local function draw_results(player, force_open)
    local state = get_state()
    if not state or state.phase ~= 'results' then
        return
    end
    if not force_open and not player.gui.screen[FRAME_RESULTS] then
        return
    end
    local frame = create_main(player, FRAME_RESULTS, 'Captains Skill Draft — Game results')
    frame.style.minimal_width = 1200
    frame.style.maximal_width = 1250
    frame.style.minimal_height = 760
    frame.style.maximal_height = 900
    local intro = frame.add({ type = 'label', caption = 'Transparent role and effort summary. Build and defense values are estimated from selected-role proficiency until live match telemetry is available.' })
    intro.style.single_line = false
    local team_flow = frame.add({ type = 'flow', name = 'skill_draft_results_team_flow', direction = 'horizontal' })
    team_flow.style.horizontally_stretchable = true
    team_flow.style.vertically_stretchable = true
    local team_width = 570
    local headers = { 'Player', 'Primary role', 'Secondary role', 'Effort', 'Build', 'Defense' }
    local widths = { 105, 105, 105, 55, 75, 75 }
    for _, force_name in ipairs({ 'north', 'south' }) do
        local team_frame = team_flow.add({
            type = 'frame',
            name = 'skill_draft_results_' .. force_name,
            style = 'inside_shallow_frame_packed',
            direction = 'vertical',
        })
        team_frame.style.minimal_width = team_width
        team_frame.style.maximal_width = team_width
        team_frame.style.vertically_stretchable = true
        local team_title = team_frame.add({
            type = 'label',
            caption = string.format(
                '%s team — %.3f skill (%s)',
                string.upper(force_name),
                team_skill(state, force_name),
                format_percent(team_win_probability(state, force_name))
            ),
        })
        team_title.style.font = 'heading-2'
        local scroll = team_frame.add({
            type = 'scroll-pane',
            name = 'players_scroll',
            direction = 'vertical',
            horizontal_scroll_policy = 'never',
            vertical_scroll_policy = 'auto',
        })
        scroll.style.minimal_width = team_width - 12
        scroll.style.maximal_width = team_width - 12
        scroll.style.maximal_height = 700
        scroll.style.vertically_stretchable = true
        local table_element = scroll.add({ type = 'table', column_count = 6, draw_vertical_lines = true })
        for header_index, header in ipairs(headers) do
            local label = table_element.add({ type = 'label', caption = header })
            label.style.font = 'default-bold'
            label.style.single_line = false
            label.style.minimal_width = widths[header_index]
            label.style.maximal_width = widths[header_index]
        end
        for _, name in ipairs(state.teams[force_name].members) do
            local selected = state.roles_selected[name] or auto_roles(get_profile(name))
            state.roles_selected[name] = selected
            local build, defense = build_and_defense_scores(name, state)
            local primary_caption = '-'
            local secondary_caption = 'None'
            for role_index, role in ipairs(roles) do
                if role == selected.primary then
                    primary_caption = role_captions[role_index]
                end
                if role == selected.secondary then
                    secondary_caption = role_captions[role_index]
                end
            end
            local values = {
                name,
                primary_caption,
                secondary_caption,
                tostring(state.effort[name] or 100) .. '%',
                string.format('%.1f', build),
                string.format('%.1f', defense),
            }
            for column_index, value in ipairs(values) do
                local cell = table_element.add({ type = 'label', caption = value })
                cell.style.minimal_width = widths[column_index]
                cell.style.maximal_width = widths[column_index]
                cell.style.single_line = false
            end
        end
    end
end

local function refresh_player(player, force_open)
    if not player or not player.valid then
        return
    end
    local state = get_state()
    if not state then
        return
    end
    ensure_top_button(player)
    if state.phase == 'lobby' then
        if force_open or player.gui.screen[FRAME_LOBBY] then
            draw_lobby(player)
        end
    elseif state.phase == 'draft' then
        if force_open or player.gui.screen[FRAME_DRAFT] then
            draw_draft(player)
        end
    elseif state.phase == 'roles' then
        if state.role_confirmed[player.name] == false then
            draw_role(player)
        else
            destroy_frame(player, FRAME_ROLE)
        end
    elseif state.phase == 'results' then
        draw_results(player, force_open)
    end
end

local function refresh_all(force_open)
    for _, player in pairs(game.connected_players) do
        refresh_player(player, force_open)
    end
end

local function collect_seed_names()
    local names = {}
    for row_index, row in ipairs(Seed.rows or {}) do
        if row_index > published_count then
            break
        end
        names[#names + 1] = row[1]
    end
    return names
end

local function shuffle(array)
    for index = #array, 2, -1 do
        local swap_index = math.random(index)
        array[index], array[swap_index] = array[swap_index], array[index]
    end
end

local function start_draft(state)
    if state.phase ~= 'lobby' then
        return false, 'A Skill Draft is already running.'
    end
    if not state.captains.north or not state.captains.south then
        return false, 'Two players must volunteer as the North and South captains first.'
    end
    state.pool = {}
    state.picked = {}
    state.teams = { north = { members = {} }, south = { members = {} } }
    state.virtual = state.virtual or {}
    if state.test_mode then
        local candidates = {}
        for _, name in ipairs(collect_seed_names()) do
            if name ~= state.captains.north and name ~= state.captains.south then
                candidates[#candidates + 1] = name
            end
        end
        shuffle(candidates)
        local amount = math.min(state.pool_size, #candidates)
        for index = 1, amount do
            local name = candidates[index]
            state.pool[#state.pool + 1] = name
            state.virtual[name] = true
            state.effort[name] = 100
            state.notes[name] = 'Seeded bot playtest'
        end
    else
        local names = {}
        for name in pairs(state.participants) do
            if not is_captain(state, name) then
                names[#names + 1] = name
            end
        end
        table.sort(names, function(left, right)
            return string.lower(left) < string.lower(right)
        end)
        for _, name in ipairs(names) do
            state.pool[#state.pool + 1] = name
            state.effort[name] = clamp_effort(state.effort[name] or 100)
        end
    end
    if #state.pool == 0 then
        return false, 'At least one player must be available to draft.'
    end

    state.phase = 'draft'
    state.picked = {}
    state.current_force = nil
    state.teams.north.members[#state.teams.north.members + 1] = state.captains.north
    state.teams.south.members[#state.teams.south.members + 1] = state.captains.south
    state.picked[state.captains.north] = 'north'
    state.picked[state.captains.south] = 'south'
    state.current_force = next_force(state)
    refresh_all(true)
    game.print('Captains Skill Draft started. ' .. string.upper(state.current_force) .. ' picks first.')
    return true
end

local function make_state(player, north, south, test_mode, pool_size)
    local state = {
        phase = 'lobby',
        started_by = player.name,
        captains = { north = north, south = south },
        participants = {},
        pool = {},
        pool_size = clamp(math.floor(tonumber(pool_size) or 30), 1, 100),
        picked = {},
        teams = { north = { members = {} }, south = { members = {} } },
        current_force = nil,
        effort = {},
        notes = {},
        virtual = {},
        roles_selected = {},
        role_confirmed = {},
        sort_key = 'skill',
        sort_ascending = false,
        explanation_open = false,
        test_mode = test_mode == true,
    }
    for _, participant in pairs(game.connected_players) do
        state.effort[participant.name] = 100
    end
    if state.test_mode then
        state.participants[player.name] = true
    end
    return state
end

local function activate(player, north, south, test_mode, pool_size)
    if get_state() then
        player.print('A Captains Skill Draft is already active.')
        return false
    end
    if not test_mode and (north or south) then
        player.print('Captains are selected by volunteers in the lobby.')
        return false
    end
    if test_mode then
        local north_player = game.get_player(north)
        local south_player = game.get_player(south)
        if not north_player or not south_player or not north_player.connected or not south_player.connected then
            player.print('The bot playtest captain must be a connected admin.')
            return false
        end
    end
    local state = make_state(player, north, south, test_mode, pool_size)
    storage.active_special_games.captains_skill_draft = true
    storage.special_games_variables.captains_skill_draft = state
    storage.bb_settings = storage.bb_settings or {}
    storage.bb_settings.automatic_captain = false
    storage.tournament_mode = true
    storage.chosen_team = {}
    for _, participant in pairs(game.connected_players) do
        TeamManager.switch_force(participant.name, 'spectator')
    end
    refresh_all(true)
    game.print('Captains Skill Draft lobby opened. Set effort before starting.')
    return true
end

local function finish_pick(state, player, name)
    if not can_control_draft(state, player) then
        player.print('Only the current captain can make this pick.')
        return
    end
    if not name or state.picked[name] then
        return
    end
    local available = false
    for _, candidate in ipairs(state.pool) do
        if candidate == name then
            available = true
            break
        end
    end
    if not available then
        return
    end
    state.picked[name] = state.current_force
    state.teams[state.current_force].members[#state.teams[state.current_force].members + 1] = name
    if #state.teams.north.members + #state.teams.south.members >= #state.pool + 2 then
        begin_role_phase(state)
        refresh_all(true)
        return
    end
    state.current_force = next_force(state)
    game.print(string.upper(state.current_force) .. ' picks next.')
    refresh_all(false)
end

local function on_gui_click(event)
    local element = event.element
    if not element or not element.valid then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local state = get_state()
    if not state then
        return
    end
    local name = element.name
    if name == TOP_BUTTON then
        if state.phase == 'lobby' then
            if player.gui.screen[FRAME_LOBBY] then
                destroy_frame(player, FRAME_LOBBY)
            else
                draw_lobby(player)
            end
        elseif state.phase == 'draft' then
            if player.gui.screen[FRAME_DRAFT] then
                destroy_frame(player, FRAME_DRAFT)
            else
                draw_draft(player)
            end
        elseif state.phase == 'results' then
            if player.gui.screen[FRAME_RESULTS] then
                destroy_frame(player, FRAME_RESULTS)
            else
                draw_results(player, true)
            end
        end
        return
    end
    if name == 'skill_draft_explain' then
        state.explanation_open = not state.explanation_open
        if state.phase == 'lobby' then
            draw_lobby(player)
        elseif state.phase == 'draft' then
            draw_draft(player)
        end
        return
    end
    if name == 'skill_draft_leaderboard' then
        draw_leaderboard(player)
        return
    end
    if name == 'skill_draft_start' then
        if is_operator(state, player) then
            local okay, message = start_draft(state)
            if not okay then
                player.print(message)
            end
        end
        return
    end
    if name == 'captain_player_clear_player_info' then
        state.notes[player.name] = ''
        draw_lobby(player)
        return
    end
    if name == 'skill_draft_save_notes' or name == 'captain_player_confirm_player_info' then
        local lobby = player.gui.screen[FRAME_LOBBY]
        local notes = lobby and lobby.info_flow and lobby.info_flow.insert and lobby.info_flow.insert.captain_player_info
        if notes and notes.valid then
            state.notes[player.name] = string.sub(notes.text or '', 1, 160)
            player.print('Draft notes saved.')
        end
        return
    end
    if name == 'skill_draft_join' or name == 'captain_player_want_to_play' then
        state.participants[player.name] = true
        state.effort[player.name] = state.effort[player.name] or 100
        refresh_player(player, true)
        return
    end
    if (name == 'skill_draft_leave' or name == 'captain_player_do_not_want_to_play') and not is_captain(state, player.name) then
        state.participants[player.name] = nil
        refresh_player(player, true)
        return
    end
    if name == 'captain_player_want_to_be_captain' and state.phase == 'lobby' then
        if state.captains.north and state.captains.south then
            player.print('Both captain slots are already filled.')
            return
        end
        local force_name = state.captains.north and 'south' or 'north'
        state.captains[force_name] = player.name
        state.participants[player.name] = true
        state.effort[player.name] = state.effort[player.name] or 100
        refresh_all(false)
        return
    end
    if name == 'captain_player_do_not_want_to_be_captain' and state.phase == 'lobby' then
        if state.captains.north == player.name then
            state.captains.north = nil
        elseif state.captains.south == player.name then
            state.captains.south = nil
        end
        refresh_all(false)
        return
    end
    if string.sub(name, 1, 17) == 'skill_draft_sort_' and state.phase == 'draft' then
        local key = string.sub(name, 18)
        if state.sort_key == key then
            state.sort_ascending = not state.sort_ascending
        else
            state.sort_key = key
            state.sort_ascending = key ~= 'skill'
        end
        draw_draft(player)
        return
    end
    if name == 'skill_draft_pick_player' then
        finish_pick(state, player, element.tags and element.tags.player_name)
        return
    end
    if name == 'skill_draft_confirm_roles' and state.phase == 'roles' then
        local role_frame = player.gui.screen[FRAME_ROLE]
        local primary = role_frame and role_frame.primary_flow and role_frame.primary_flow.skill_draft_primary_role
        local secondary = role_frame and role_frame.secondary_flow and role_frame.secondary_flow.skill_draft_secondary_role
        local primary_index = primary and tonumber(primary.selected_index) or 0
        local secondary_index = secondary and tonumber(secondary.selected_index) or 0
        if not primary or not secondary or primary_index < 1 then
            player.print('Select a primary role before confirming.')
            return
        end
        local primary_role = selected_role(nil, primary_index, false)
        local secondary_role = selected_role(nil, secondary_index, true)
        if not primary_role then
            player.print('Select a valid primary role before confirming.')
            return
        end
        if secondary_role and secondary_role == primary_role then
            player.print('Primary and secondary roles must be different.')
            return
        end
        state.roles_selected[player.name] = { primary = primary_role, secondary = secondary_role }
        state.role_confirmed[player.name] = true
        destroy_frame(player, FRAME_ROLE)
        finish_roles(state)
        if state.phase == 'roles' then
            refresh_all(false)
        else
            refresh_all(true)
        end
        return
    end
end

local function on_gui_value_changed(event)
    local element = event.element
    if not element or not element.valid or element.name ~= 'skill_draft_effort_slider' then
        return
    end
    local state = get_state()
    local player = game.get_player(event.player_index)
    if not state or not player or state.phase ~= 'lobby' then
        return
    end
    state.effort[player.name] = clamp_effort(element.slider_value)
    local lobby = player.gui.screen[FRAME_LOBBY]
    local label = lobby and lobby.effort_flow and lobby.effort_flow.skill_draft_effort_value
    if label and label.valid then
        label.caption = state.effort[player.name] .. '% (cost multiplier ' .. string.format('%.2f', effort_multiplier(state.effort[player.name])) .. ')'
    end
end

local function on_gui_closed(event)
    local state = get_state()
    local player = game.get_player(event.player_index)
    if not state or not player or not event.element or not event.element.valid then
        return
    end
    if event.element.name == FRAME_ROLE and state.phase == 'roles' and state.role_confirmed[player.name] == false then
        player.opened = nil
        draw_role(player)
    end
end

local function on_player_joined_game(event)
    local state = get_state()
    local player = game.get_player(event.player_index)
    if not state or not player then
        return
    end
    if state.phase == 'lobby' and not state.test_mode then
        state.participants[player.name] = true
        state.effort[player.name] = state.effort[player.name] or 100
    elseif state.phase == 'playing' and state.assigned_team and state.assigned_team[player.name] then
        TeamManager.switch_force(player.name, state.assigned_team[player.name])
    end
    refresh_player(player, true)
end

local function on_player_left_game(event)
    local state = get_state()
    local player = game.get_player(event.player_index)
    if not state or not player then
        return
    end
    if state.phase == 'roles' and state.role_confirmed[player.name] == false then
        state.roles_selected[player.name] = auto_roles(get_profile(player.name))
        state.role_confirmed[player.name] = true
        finish_roles(state)
    end
end

function Public.generate(config, player)
    return activate(player, nil, nil, false, nil)
end

-- Keep the live Special games confirm path unchanged. The selector dispatches
-- through the legacy Captain module, and this wrapper diverts only the new
-- Skill Draft selection while preserving the legacy mode byte-for-byte.
local Captain_event = require('comfy_panel.special_games.captain')
local legacy_captain_generate = Captain_event.generate
if not Captain_event.captains_skill_draft_dispatch then
    Captain_event.captains_skill_draft_dispatch = true
    Captain_event.generate = function(config, player)
        local selector = config and config.captain_game_mode_selector
        if selector and selector.valid and selector.selected_index == 2 then
            return Public.generate(config, player)
        end
        return legacy_captain_generate(config, player)
    end
end

function Public.start_test(player)
    if not player or not player.valid or not player.admin then
        return false
    end
    return activate(player, player.name, player.name, true, 30)
end

function Public.clear_gui_special()
    for _, player in pairs(game.connected_players) do
        close_skill_frames(player)
        local button = Gui.get_top_element(player, TOP_BUTTON)
        if button and button.valid then
            Gui.destroy(button)
        end
    end
end

function Public.reset_special_games()
    Public.clear_gui_special()
end

function Public.on_game_over()
    local state = get_state()
    if not state or (state.phase ~= 'playing' and state.phase ~= 'results') then
        return
    end
    state.phase = 'results'
    storage.tournament_mode = false
    refresh_all(true)
end

local config = {
}

Public.name = { type = 'label', caption = 'Captains Skill Draft' }
Public.config = config
Public.button = { name = 'apply', type = 'button', caption = 'Apply' }

commands.add_command('cpt-skill-test-start', 'Start a 30-player seeded Captains Skill Draft bot playtest.', function(command)
    local player = command.player_index and game.get_player(command.player_index)
    if not player or not player.admin then
        return
    end
    Public.start_test(player)
end)

Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_value_changed, on_gui_value_changed)
Event.add(defines.events.on_gui_closed, on_gui_closed)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game, on_player_left_game)

return Public
