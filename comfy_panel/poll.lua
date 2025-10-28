local Gui = require('utils.gui')
local Global = require('utils.global')
local Event = require('utils.event')
local Server = require('utils.server')
local gui_style = require('utils.utils').gui_style
local frame_style = require('utils.utils').left_frame_style
local ternary = require('utils.utils').ternary
local Class = {}

local insert = table.insert

local default_poll_duration = 90 -- in seconds
local duration_max = 600 -- in seconds
local duration_step = 30 -- in seconds

local duration_slider_max = duration_max / duration_step
local tick_duration_step = duration_step * 60
local inv_tick_duration_step = 1 / tick_duration_step

local polls = {}
local polls_counter = { 0 }
local no_notify_players = {}
local player_poll_index = {}
local player_create_poll_data = {}

Global.register({
    polls = polls,
    polls_counter = polls_counter,
    no_notify_players = no_notify_players,
    player_poll_index = player_poll_index,
    player_create_poll_data = player_create_poll_data,
}, function(tbl)
    polls = tbl.polls
    polls_counter = tbl.polls_counter
    no_notify_players = tbl.no_notify_players
    player_poll_index = tbl.player_poll_index
    player_create_poll_data = tbl.player_create_poll_data
end)

local poll_flow_name = Gui.uid_name()
local main_button_name = Gui.uid_name()
local main_frame_name = Gui.uid_name()
local create_poll_button_name = Gui.uid_name()
local notify_checkbox_name = Gui.uid_name()

local poll_view_back_name = Gui.uid_name()
local poll_view_forward_name = Gui.uid_name()
local poll_view_vote_name = Gui.uid_name()
local poll_view_edit_name = Gui.uid_name()

local create_poll_frame_name = Gui.uid_name()
local create_poll_duration_name = Gui.uid_name()
local create_poll_label_name = Gui.uid_name()
local create_poll_question_name = Gui.uid_name()
local create_poll_answer_name = Gui.uid_name()
local create_poll_add_answer_name = Gui.uid_name()
local create_poll_delete_answer_name = Gui.uid_name()
local create_poll_close_name = Gui.uid_name()
local create_poll_clear_name = Gui.uid_name()
local create_poll_edit_name = Gui.uid_name()
local create_poll_confirm_name = Gui.uid_name()
local create_poll_delete_name = Gui.uid_name()

local function poll_id()
    local count = polls_counter[1] + 1
    polls_counter[1] = count
    return count
end

local function apply_button_style(button)
    gui_style(button, {
        font = 'default-semibold',
        height = 24,
        minimal_width = 26,
        top_padding = 0,
        bottom_padding = 0,
        left_padding = 2,
        right_padding = 2,
    })
end

local flow_style = { padding = 0, vertical_spacing = 0, maximal_width = 400 }

local function do_remaining_time(poll, remaining_time_label)
    local end_tick = poll.end_tick
    if end_tick == -1 then
        remaining_time_label.caption = 'Endless poll'
        return true
    end

    local ticks = end_tick - game.tick
    if ticks < 0 then
        remaining_time_label.caption = 'Poll Finished.'
        if ticks == -1 then
            Sounds.notify_all('utility/achievement_unlocked')
        end
        local stop_running = true
        for i = 1, polls_counter[1] do
            if polls[i] and polls[i].end_tick >= game.tick then
                stop_running = false
                break
            end
        end
        if stop_running then
            polls.running = false
        end
        return false
    else
        local time = math.ceil(ticks / 60)
        remaining_time_label.caption = time .. 's left'
        return true
    end
end

local function update_winner_buttons(poll, vote_buttons)
    local top_answer_voted_count = -1
    local top_answer_indexes = {}
    for i, a in pairs(poll.answers) do
        if a.voted_count > top_answer_voted_count then
            top_answer_voted_count = a.voted_count
            top_answer_indexes = {}
            insert(top_answer_indexes, i)
        elseif a.voted_count == top_answer_voted_count then
            insert(top_answer_indexes, i)
        end
    end

    if top_answer_voted_count > 0 then
        for i, ii in pairs(top_answer_indexes) do
            vote_buttons[ii].caption = '[img=virtual-signal/signal-check] ' .. poll.answers[ii].text
        end
    end
end

local function send_poll_result_to_discord(poll)
    local result = { 'Poll #', poll.id }

    local created_by_player = poll.created_by
    if created_by_player and created_by_player.valid then
        insert(result, ' Created by ')
        insert(result, created_by_player.name)
    end

    local edited_by_players = poll.edited_by
    if next(edited_by_players) then
        insert(result, ' Edited by ')
        for pi, _ in pairs(edited_by_players) do
            local p = game.get_player(pi)
            if p and p.valid then
                insert(result, p.name)
                insert(result, ', ')
            end
        end
        table.remove(result)
    end

    insert(result, '\\n**Question: ')
    insert(result, poll.question)
    insert(result, '**\\n')

    local answers = poll.answers
    local answers_count = #answers
    for i, a in pairs(answers) do
        insert(result, '[')
        insert(result, a.voted_count)
        insert(result, '] - ')
        insert(result, a.text)
        if i ~= answers_count then
            insert(result, '\\n')
        end
    end

    local message = table.concat(result)
    Server.to_discord_embed(message)
end

local function redraw_poll_viewer_content(data)
    local poll_viewer_content = data.poll_viewer_content
    local poll_index = data.poll_index
    local player = poll_viewer_content.gui.player

    data.vote_buttons = nil
    data.vote_labels = nil
    Gui.remove_data_recursively(poll_viewer_content)
    poll_viewer_content.clear()

    if poll_index < 1 then
        poll_viewer_content.add({ type = 'label', caption = 'No polls' })
    end

    local poll = polls[poll_index]
    if not poll then
        return
    end

    local answers = poll.answers
    local voters = poll.voters

    local tooltips = {}
    for _, a in pairs(answers) do
        tooltips[a] = {}
    end

    for player_index, answer in pairs(voters) do
        local p = game.get_player(player_index)
        insert(tooltips[answer], p.name)
    end

    for a, t in pairs(tooltips) do
        if #t == 0 then
            tooltips[a] = ''
        else
            tooltips[a] = table.concat(t, ', ')
        end
    end

    local poll_viewer_top_flow = poll_viewer_content.add({ type = 'table', column_count = 2 })
    gui_style(poll_viewer_top_flow, { horizontally_stretchable = true })

    local poll_index_label =
        poll_viewer_top_flow.add({ type = 'label', caption = 'Poll #' .. poll_index .. '/' .. #polls })
    gui_style(poll_index_label, { horizontally_stretchable = true })

    local remaining_time_label = poll_viewer_top_flow.add({ type = 'label' })

    data.remaining_time_label = remaining_time_label

    local poll_enabled = do_remaining_time(poll, remaining_time_label)

    local question_label = poll_viewer_content.add({ type = 'label', caption = poll.question })
    gui_style(question_label, {
        single_line = false,
        font = 'heading-2',
        font_color = { r = 0.98, g = 0.66, b = 0.22 },
        top_padding = 4,
        bottom_padding = 6,
        horizontally_stretchable = true,
    })

    local grid = poll_viewer_content.add({ type = 'table', column_count = 2 })
    gui_style(grid, { horizontally_stretchable = true })

    local vote_buttons = {}
    local vote_labels = {}
    for i, a in pairs(answers) do
        local vote_button_flow = grid.add({ type = 'flow' })
        local vote_button = vote_button_flow.add({
            type = 'button',
            name = poll_view_vote_name,
            caption = a.text,
            enabled = poll_enabled,
            toggled = voters[player.index] == a,
        })
        gui_style(vote_button, {
            horizontally_stretchable = true,
            top_padding = 6,
            bottom_padding = 6,
            horizontal_align = 'left',
            maximal_width = 300,
        })

        local label = grid.add({
            type = 'label',
            caption = a.voted_count .. ternary(a.voted_count == 1, ' vote', ' votes'),
            tooltip = tooltips[a],
        })
        gui_style(label, {
            left_padding = 6,
        })

        Gui.set_data(vote_button, { answer = a, data = data })
        vote_buttons[i] = vote_button
        vote_labels[i] = label
    end

    local bottom_flow = poll_viewer_content.add({ type = 'flow', direction = 'vertical' })

    local created_by_player = poll.created_by
    local created_by_text
    if created_by_player and created_by_player.valid then
        created_by_text = 'Created by ' .. created_by_player.name
    else
        created_by_text = ''
    end
    local created_by_label = bottom_flow.add({ type = 'label', font = 'default-small', caption = created_by_text })
    gui_style(created_by_label, { font = 'default-small', top_padding = 6 })

    local edited_by_players = poll.edited_by
    if next(edited_by_players) then
        local edit_names = { 'Edited by ' }
        for pi, _ in pairs(edited_by_players) do
            local p = game.get_player(pi)
            if p and p.valid then
                insert(edit_names, p.name)
                insert(edit_names, ', ')
            end
        end

        table.remove(edit_names)
        local edit_text = table.concat(edit_names)

        local edited_by_label = bottom_flow.add({ type = 'label', caption = edit_text, tooltip = edit_text })
        gui_style(
            edited_by_label,
            { single_line = false, horizontally_stretchable = false, font = 'default-small', top_margin = -6 }
        )
    end

    if not poll_enabled then
        update_winner_buttons(poll, vote_buttons)
    end

    data.vote_buttons = vote_buttons
    data.vote_labels = vote_labels
end

local function update_poll_viewer(data)
    local back_button = data.back_button
    local forward_button = data.forward_button
    local poll_index = data.poll_index

    if #polls == 0 then
        poll_index = 0
    else
        poll_index = math.clamp(poll_index, 1, #polls)
    end

    data.poll_index = poll_index

    back_button.enabled = poll_index > 1
    forward_button.enabled = poll_index < #polls

    redraw_poll_viewer_content(data)
end

local function draw_main_frame(player)
    local poll_flow = Gui.add_left_element(player, { type = 'flow', name = poll_flow_name, direction = 'vertical' })
    gui_style(poll_flow, flow_style)

    local old_frame = poll_flow[main_frame_name]
    if old_frame then
        old_frame.destroy()
    end
    local frame = poll_flow.add({ type = 'frame', name = main_frame_name, direction = 'vertical' })
    gui_style(frame, frame_style())

    local flow = frame.add({ type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' })
    local inner_frame = flow.add({
        type = 'frame',
        name = 'inner_frame',
        style = 'inside_shallow_frame_packed',
        direction = 'vertical',
    })

    -- == SUBHEADER =================================================================
    local subheader = inner_frame.add({ type = 'frame', name = 'subheader', style = 'subheader_frame' })
    gui_style(subheader, { horizontally_stretchable = true, horizontally_squashable = true, maximal_height = 40 })

    local label = subheader.add({ type = 'label', caption = 'Polls' })
    gui_style(label, { font = 'default-semibold', font_color = { 165, 165, 165 }, left_margin = 4 })

    local back_button = subheader.add({
        type = 'sprite-button',
        name = poll_view_back_name,
        sprite = 'utility/backward_arrow',
        hovered_sprite = 'utility/backward_arrow_black',
        style = 'frame_action_button',
    })
    gui_style(back_button, { left_margin = 4 })

    local forward_button = subheader.add({
        type = 'sprite-button',
        name = poll_view_forward_name,
        sprite = 'utility/forward_arrow',
        hovered_sprite = 'utility/forward_arrow_black',
        style = 'frame_action_button',
    })

    Gui.add_pusher(subheader)

    subheader.add({
        type = 'sprite-button',
        name = main_button_name,
        sprite = 'utility/close',
        clicked_sprite = 'utility/close_black',
        style = 'close_button',
        tooltip = { 'gui.close' },
    })

    -- == MAIN FRAME ================================================================
    local poll_viewer_content = inner_frame.add({
        type = 'scroll-pane',
        name = 'scroll_pane',
        style = 'scroll_pane_under_subheader',
        direction = 'vertical',
    })
    gui_style(poll_viewer_content, {
        left_padding = 8,
        right_padding = 8,
        maximal_height = 520,
        minimal_width = 232,
    })

    local poll_index = player_poll_index[player.index] or #polls

    local data = {
        back_button = back_button,
        forward_button = forward_button,
        poll_viewer_content = poll_viewer_content,
        poll_index = poll_index,
    }

    Gui.set_data(frame, data)
    Gui.set_data(back_button, data)
    Gui.set_data(forward_button, data)

    update_poll_viewer(data)

    -- == SUBFOOTER ===============================================================
    if is_admin(player) then
        local subfooter =
            inner_frame.add({ type = 'frame', name = 'subfooter', style = 'subfooter_frame', direction = 'horizontal' })
        gui_style(subfooter, {
            horizontally_stretchable = true,
            horizontally_squashable = true,
            maximal_height = 36,
            vertical_align = 'center',
        })

        Gui.add_pusher(subfooter)

        local edit_poll_button = subfooter.add({ type = 'button', name = poll_view_edit_name, caption = 'Edit poll' })
        apply_button_style(edit_poll_button)
        gui_style(edit_poll_button, { top_margin = 3 })

        local create_poll_button =
            subfooter.add({ type = 'button', name = create_poll_button_name, caption = 'Create poll' })
        apply_button_style(create_poll_button)
        gui_style(create_poll_button, { top_margin = 3 })
    end
end

local function remove_create_poll_frame(create_poll_frame, player_index)
    local data = Gui.get_data(create_poll_frame)

    data.edit_mode = nil
    player_create_poll_data[player_index] = data

    Gui.remove_data_recursively(create_poll_frame)
    create_poll_frame.destroy()
end

local function remove_main_frame(main_frame, player)
    local player_index = player.index
    local data = Gui.get_data(main_frame)
    player_poll_index[player_index] = data.poll_index

    Gui.remove_data_recursively(main_frame)
    main_frame.destroy()

    local poll_flow = Gui.get_left_element(player, poll_flow_name)
    local create_poll_frame = poll_flow and poll_flow[create_poll_frame_name]
    if create_poll_frame and create_poll_frame.valid then
        remove_create_poll_frame(create_poll_frame, player_index)
    end
    poll_flow.destroy()
end

local function toggle(event)
    local poll_flow = Gui.get_left_element(event.player, poll_flow_name)
    local main_frame = poll_flow and poll_flow[main_frame_name]

    if main_frame then
        remove_main_frame(main_frame, event.player)
    else
        draw_main_frame(event.player)
    end
end

local function update_duration(slider)
    local slider_data = Gui.get_data(slider)
    local label = slider_data.duration_label
    local value = slider.slider_value

    value = math.floor(value)

    slider_data.data.duration = value * tick_duration_step

    if value == 0 then
        label.caption = 'Endless poll'
    else
        label.caption = value * duration_step .. ' seconds'
    end
end

local function redraw_create_poll_content(data)
    local grid = data.grid
    local answers = data.answers

    Gui.remove_data_recursively(grid)
    grid.clear()

    grid.add({ type = 'flow' })
    grid.add({
        type = 'label',
        caption = 'Duration:',
        tooltip = 'Pro tip: Use mouse wheel or arrow keys for more fine control.',
    })

    local duration_flow = grid.add({ type = 'flow', direction = 'horizontal' })
    local duration_slider = duration_flow.add({
        type = 'slider',
        name = create_poll_duration_name,
        minimum_value = 0,
        maximum_value = duration_slider_max,
        value = math.floor(data.duration * inv_tick_duration_step),
    })
    gui_style(duration_slider, { minimal_width = 100, horizontally_stretchable = true })

    data.duration_slider = duration_slider

    local duration_label = duration_flow.add({ type = 'label' })

    Gui.set_data(duration_slider, { duration_label = duration_label, data = data })

    update_duration(duration_slider)

    grid.add({ type = 'flow' })
    local question_label = grid.add({ type = 'flow' })
        .add({ type = 'label', name = create_poll_label_name, caption = 'Question:' })
    local question_textfield = grid.add({ type = 'flow' })
        .add({ type = 'textfield', name = create_poll_question_name, text = data.question })
    gui_style(
        question_textfield,
        { natural_width = 0, width = 0, minimal_width = 170, horizontally_stretchable = true }
    )

    Gui.set_data(question_label, question_textfield)
    Gui.set_data(question_textfield, data)

    local edit_mode = data.edit_mode
    for count, answer in pairs(answers) do
        local delete_flow = grid.add({ type = 'flow' })

        local delete_button
        if edit_mode or count ~= 1 then
            delete_button = delete_flow.add({
                type = 'sprite-button',
                name = create_poll_delete_answer_name,
                sprite = 'utility/trash_white',
                tooltip = 'Delete answer field.',
                style = 'red_slot_button',
            })
            gui_style(delete_button, { height = 26, width = 26 })
        else
            gui_style(delete_flow, { height = 26, width = 26 })
        end

        local label_flow = grid.add({ type = 'flow' })
        local label = label_flow.add({
            type = 'label',
            name = create_poll_label_name,
            caption = table.concat({ 'Answer #', count, ':' }),
        })

        local textfield_flow = grid.add({ type = 'flow' })

        local textfield = textfield_flow.add({ type = 'textfield', name = create_poll_answer_name, text = answer.text })
        gui_style(textfield, { natural_width = 0, width = 0, minimal_width = 170, horizontally_stretchable = true })

        Gui.set_data(textfield, { answers = answers, count = count })

        if delete_button then
            Gui.set_data(delete_button, { data = data, count = count })
        end

        Gui.set_data(label, textfield)
    end
end

local function draw_create_poll_frame(player, previous_data)
    previous_data = previous_data or player_create_poll_data[player.index]

    local edit_mode
    local question
    local answers
    local duration
    local title_text
    local confirm_text
    local confirm_name
    if previous_data then
        edit_mode = previous_data.edit_mode

        question = previous_data.question

        answers = {}
        for i, a in pairs(previous_data.answers) do
            answers[i] = { text = a.text, source = a }
        end

        duration = previous_data.duration
    else
        question = ''
        answers = { { text = '' }, { text = '' }, { text = '' } }
        duration = default_poll_duration * 60
    end

    if edit_mode then
        title_text = 'Edit Poll #' .. previous_data.id
        confirm_text = 'Edit Poll'
        confirm_name = create_poll_edit_name
    else
        title_text = 'New Poll'
        confirm_text = 'Create Poll'
        confirm_name = create_poll_confirm_name
    end

    local frame = Gui.get_left_element(player, poll_flow_name)
        .add({ type = 'frame', name = create_poll_frame_name, direction = 'vertical' })
    gui_style(frame, frame_style())
    gui_style(frame, { minimal_width = 320, horizontally_stretchable = true })

    local flow = frame.add({ type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' })
    local inner_frame = flow.add({
        type = 'frame',
        name = 'inner_frame',
        style = 'inside_shallow_frame_packed',
        direction = 'vertical',
    })

    -- == SUBHEADER =================================================================
    local subheader = inner_frame.add({ type = 'frame', name = 'subheader', style = 'subheader_frame' })
    gui_style(subheader, { horizontally_stretchable = true, horizontally_squashable = true, maximal_height = 40 })

    local label = subheader.add({ type = 'label', caption = title_text })
    gui_style(label, { font = 'default-semibold', font_color = { 165, 165, 165 }, left_margin = 4 })

    -- == MAIN FRAME ================================================================
    local scroll_pane = inner_frame.add({
        type = 'scroll-pane',
        style = 'scroll_pane_under_subheader',
        vertical_scroll_policy = 'always',
    })
    gui_style(scroll_pane, { maximal_height = 250, horizontally_stretchable = true, padding = 4, margin = 6 })

    local grid = scroll_pane.add({ type = 'table', column_count = 3 })

    local data = {
        frame = frame,
        grid = grid,
        question = question,
        answers = answers,
        duration = duration,
        previous_data = previous_data,
        edit_mode = edit_mode,
    }

    Gui.set_data(frame, data)

    redraw_create_poll_content(data)

    local add_answer_button = scroll_pane.add({
        type = 'button',
        name = create_poll_add_answer_name,
        caption = 'Add Answer',
    })
    apply_button_style(add_answer_button)
    Gui.set_data(add_answer_button, data)

    local bottom_flow = frame.add({ type = 'flow', direction = 'horizontal' })

    -- == SUBFOOTER ===============================================================
    local subfooter =
        inner_frame.add({ type = 'frame', name = 'subfooter', style = 'subfooter_frame', direction = 'horizontal' })
    gui_style(subfooter, { horizontally_stretchable = true, horizontally_squashable = true, maximal_height = 36 })

    local close_button =
        subfooter.add({ type = 'button', name = create_poll_close_name, caption = 'Close', style = 'back_button' })
    apply_button_style(close_button)
    close_button.style.left_margin = 4
    Gui.set_data(close_button, frame)

    local clear_button = subfooter.add({ type = 'button', name = create_poll_clear_name, caption = 'Clear' })
    apply_button_style(clear_button)
    Gui.set_data(clear_button, data)

    Gui.add_pusher(subfooter)

    if edit_mode then
        local delete_button =
            subfooter.add({ type = 'button', name = create_poll_delete_name, caption = 'Delete', style = 'red_button' })
        apply_button_style(delete_button)
        Gui.set_data(delete_button, data)
    end

    local confirm_button = subfooter.add({
        type = 'button',
        name = confirm_name,
        caption = confirm_text,
        style = 'confirm_button_without_tooltip',
    })
    apply_button_style(confirm_button)
    confirm_button.style.right_margin = 4
    Gui.set_data(confirm_button, data)
end

local function show_new_poll(poll_data)
    local message =
        table.concat({ poll_data.created_by.name, ' has created a new Poll #', poll_data.id, ': ', poll_data.question })

    for _, p in pairs(game.connected_players) do
        local poll_flow = Gui.get_left_element(p, poll_flow_name)
        local frame = poll_flow and poll_flow[main_frame_name]
        if no_notify_players[p.index] then
            if frame and frame.valid then
                local data = Gui.get_data(frame)
                update_poll_viewer(data)
            end
        else
            p.print(message)

            if frame and frame.valid then
                local data = Gui.get_data(frame)
                data.poll_index = #polls
                update_poll_viewer(data)
            else
                player_poll_index[p.index] = nil
                draw_main_frame(p)
            end
        end
    end
end

local function create_poll(event)
    local player = event.player
    local data = Gui.get_data(event.element)

    local frame = data.frame
    local question = data.question

    if not question:find('%S') then
        event.player.print('Sorry, the poll needs a question.')
        return
    end

    local answers = {}
    for _, a in pairs(data.answers) do
        local text = a.text
        if text:find('%S') then
            local index = #answers + 1
            answers[index] = { text = text, index = index, voted_count = 0 }
        end
    end

    if #answers < 1 then
        player.print('Sorry, the poll needs at least one answer.')
        return
    end

    player_create_poll_data[player.index] = nil

    local tick = game.tick
    local duration = data.duration
    local end_tick

    if duration == 0 then
        end_tick = -1
    else
        end_tick = tick + duration
    end

    local poll_data = {
        id = poll_id(),
        question = question,
        answers = answers,
        voters = {},
        start_tick = tick,
        end_tick = end_tick,
        duration = duration,
        created_by = event.player,
        edited_by = {},
    }

    insert(polls, poll_data)

    polls.running = true

    show_new_poll(poll_data)
    send_poll_result_to_discord(poll_data)

    Gui.remove_data_recursively(frame)
    frame.destroy()
end

local function update_vote(voters, answer, direction)
    local count = answer.voted_count + direction
    answer.voted_count = count

    local tooltip = {}
    for pi, a in pairs(voters) do
        if a == answer then
            local player = game.get_player(pi)
            insert(tooltip, player.name)
        end
    end

    return tostring(count), table.concat(tooltip, ', ')
end

local function vote(event)
    local player_index = event.player_index
    local voted_button = event.element
    local button_data = Gui.get_data(voted_button)
    local answer = button_data.answer

    local poll_index = button_data.data.poll_index
    local poll = polls[poll_index]

    local voters = poll.voters

    local previous_vote_answer = voters[player_index]
    if previous_vote_answer == answer then
        return
    end

    local vote_index = answer.index

    voters[player_index] = answer

    local previous_vote_button_count
    local previous_vote_button_tooltip
    local previous_vote_index
    if previous_vote_answer then
        previous_vote_button_count, previous_vote_button_tooltip = update_vote(voters, previous_vote_answer, -1)
        previous_vote_index = previous_vote_answer.index
    end

    local vote_button_count, vote_button_tooltip = update_vote(voters, answer, 1)

    for _, p in pairs(game.connected_players) do
        local poll_flow = Gui.get_left_element(p, poll_flow_name)
        local frame = poll_flow and poll_flow[main_frame_name]
        if frame and frame.valid then
            local data = Gui.get_data(frame)

            if data.poll_index == poll_index then
                local vote_labels = data.vote_labels
                local vote_buttons = data.vote_buttons
                if previous_vote_answer then
                    local vote_label = vote_labels[previous_vote_index]
                    vote_label.caption = previous_vote_button_count
                        .. ternary(previous_vote_button_count == '1', ' vote', ' votes')
                    vote_label.tooltip = previous_vote_button_tooltip

                    if p.index == player_index then
                        vote_buttons[previous_vote_index].toggled = false
                    end
                end

                local vote_label = vote_labels[vote_index]
                vote_label.caption = vote_button_count .. ternary(vote_button_count == '1', ' vote', ' votes')
                vote_label.tooltip = vote_button_tooltip
                if p.index == player_index then
                    vote_buttons[vote_index].toggled = true
                end
            end
        end
    end
end

function Class.create_top_button(player)
    local button = Gui.add_top_element(player, {
        type = 'sprite-button',
        name = main_button_name,
        sprite = 'item/programmable-speaker',
        tooltip = { 'gui.polls_top_button' },
    })
end

local function player_joined(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end

    local polls = Gui.get_top_element(player, main_button_name)
    if polls then
        local poll_flow = Gui.get_left_element(player, poll_flow_name)
        local frame = poll_flow and poll_flow[main_frame_name]
        if frame and frame.valid then
            local data = Gui.get_data(frame)
            update_poll_viewer(data)
        end
    end
end

local function tick()
    if not polls.running then
        return
    end
    for _, p in pairs(game.connected_players) do
        local poll_flow = Gui.get_left_element(p, poll_flow_name)
        local frame = poll_flow and poll_flow[main_frame_name]
        if frame and frame.valid then
            local data = Gui.get_data(frame)
            local poll = polls[data.poll_index]
            if poll then
                local poll_enabled = do_remaining_time(poll, data.remaining_time_label)

                if not poll_enabled then
                    for _, v in pairs(data.vote_buttons) do
                        v.enabled = poll_enabled
                    end
                    update_winner_buttons(poll, data.vote_buttons)
                end
            end
        end
    end
end

Event.add(defines.events.on_player_joined_game, player_joined)
Event.on_nth_tick(60, tick)

Gui.on_click(main_button_name, toggle)

Gui.on_click(create_poll_button_name, function(event)
    local player = event.player
    local poll_flow = Gui.get_left_element(player, poll_flow_name)
    local frame = poll_flow and poll_flow[create_poll_frame_name]
    if frame and frame.valid then
        remove_create_poll_frame(frame, player.index)
    else
        draw_create_poll_frame(player)
    end
end)

Gui.on_click(poll_view_edit_name, function(event)
    local player = event.player
    local poll_flow = Gui.get_left_element(player, poll_flow_name)
    local frame = poll_flow and poll_flow[create_poll_frame_name]

    if frame and frame.valid then
        Gui.remove_data_recursively(frame)
        frame.destroy()
    end

    local main_frame = poll_flow and poll_flow[main_frame_name]
    local frame_data = Gui.get_data(main_frame)
    local poll = polls[frame_data.poll_index]

    poll.edit_mode = true
    draw_create_poll_frame(player, poll)
end)

Gui.on_value_changed(create_poll_duration_name, function(event)
    update_duration(event.element)
end)

Gui.on_click(create_poll_delete_answer_name, function(event)
    local button_data = Gui.get_data(event.element)
    local data = button_data.data

    table.remove(data.answers, button_data.count)
    redraw_create_poll_content(data)
end)

Gui.on_click(create_poll_label_name, function(event)
    local textfield = Gui.get_data(event.element)
    textfield.focus()
end)

Gui.on_text_changed(create_poll_question_name, function(event)
    local textfield = event.element
    local data = Gui.get_data(textfield)

    data.question = textfield.text
end)

Gui.on_text_changed(create_poll_answer_name, function(event)
    local textfield = event.element
    local data = Gui.get_data(textfield)

    data.answers[data.count].text = textfield.text
end)

Gui.on_click(create_poll_add_answer_name, function(event)
    local data = Gui.get_data(event.element)

    if not data then
        return
    end

    if data and #data.answers > 10 then
        return
    end

    insert(data.answers, { text = '' })
    redraw_create_poll_content(data)
end)

Gui.on_click(create_poll_close_name, function(event)
    local frame = Gui.get_data(event.element)
    remove_create_poll_frame(frame, event.player_index)
end)

Gui.on_click(create_poll_clear_name, function(event)
    local data = Gui.get_data(event.element)

    local slider = data.duration_slider
    slider.slider_value = math.floor(default_poll_duration * 60 * inv_tick_duration_step)
    update_duration(slider)

    data.question = ''

    local answers = data.answers
    for i = 1, #answers do
        answers[i].text = ''
    end

    redraw_create_poll_content(data)
end)

Gui.on_click(create_poll_confirm_name, create_poll)

Gui.on_click(create_poll_delete_name, function(event)
    local player = event.player
    local data = Gui.get_data(event.element)
    local frame = data.frame
    local poll = data.previous_data

    Gui.remove_data_recursively(frame)
    frame.destroy()

    player_create_poll_data[player.index] = nil

    local removed_index
    for i, p in pairs(polls) do
        if p == poll then
            table.remove(polls, i)
            removed_index = i
            break
        end
    end

    if not removed_index then
        return
    end

    local message = table.concat({ player.name, ' has deleted Poll #', poll.id, ': ', poll.question })

    for _, p in pairs(game.connected_players) do
        if not no_notify_players[p.index] then
            p.print(message)
        end

        local main_frame = Gui.get_left_element(p, main_frame_name)
        if main_frame and main_frame.valid then
            local main_frame_data = Gui.get_data(main_frame)
            local poll_index = main_frame_data.poll_index

            if removed_index < poll_index then
                main_frame_data.poll_index = poll_index - 1
            end

            update_poll_viewer(main_frame_data)
            toggle(event)
        end
    end
end)

Gui.on_click(create_poll_edit_name, function(event)
    local player = event.player
    local data = Gui.get_data(event.element)
    local frame = data.frame
    local poll = data.previous_data

    local new_question = data.question
    if not new_question:find('%S') then
        player.print('Sorry, the poll needs a question.')
        return
    end

    local new_answer_set = {}
    local new_answers = {}
    for _, a in pairs(data.answers) do
        if a.text:find('%S') then
            local source = a.source
            local index = #new_answers + 1
            if source then
                new_answer_set[source] = a
                source.text = a.text
                source.index = index
                new_answers[index] = source
            else
                new_answers[index] = { text = a.text, index = index, voted_count = 0 }
            end
        end
    end

    if not next(new_answers) then
        player.print('Sorry, the poll needs at least one answer.')
        return
    end

    Gui.remove_data_recursively(frame)
    frame.destroy()

    local player_index = player.index

    player_create_poll_data[player_index] = nil

    local old_answers = poll.answers
    local voters = poll.voters
    for _, a in pairs(old_answers) do
        if not new_answer_set[a] then
            for pi, a2 in pairs(voters) do
                if a == a2 then
                    voters[pi] = nil
                end
            end
        end
    end

    poll.question = new_question
    poll.answers = new_answers
    poll.edited_by[player_index] = true

    local start_tick = game.tick
    local duration = data.duration
    local end_tick

    if duration == 0 then
        end_tick = -1
    else
        end_tick = start_tick + duration
    end

    poll.start_tick = start_tick
    poll.end_tick = end_tick
    poll.duration = duration

    local poll_index
    for i, p in pairs(polls) do
        if poll == p then
            poll_index = i
            break
        end
    end

    if not poll_index then
        insert(polls, poll)
        poll_index = #polls
    end

    local message = table.concat({ player.name, ' has edited Poll #', poll.id, ': ', poll.question })

    for _, p in pairs(game.connected_players) do
        local main_frame = Gui.get_left_element(p, main_frame_name)

        if no_notify_players[p.index] then
            if main_frame and main_frame.valid then
                local main_frame_data = Gui.get_data(main_frame)
                update_poll_viewer(main_frame_data)
            end
        else
            p.print(message)
            if main_frame and main_frame.valid then
                local main_frame_data = Gui.get_data(main_frame)
                main_frame_data.poll_index = poll_index
                update_poll_viewer(main_frame_data)
            else
                draw_main_frame(p)
            end
        end
    end

    polls.running = true
end)

Gui.on_checked_state_changed(notify_checkbox_name, function(event)
    local player_index = event.player_index
    local checkbox = event.element

    local new_state
    if checkbox.state then
        new_state = nil
    else
        new_state = true
    end

    no_notify_players[player_index] = new_state
end)

local function do_direction(event, sign)
    local count
    if event.shift then
        count = #polls
    else
        local button = event.button
        if button == defines.mouse_button_type.right then
            count = 5
        else
            count = 1
        end
    end

    count = count * sign

    local data = Gui.get_data(event.element)
    data.poll_index = data.poll_index + count
    update_poll_viewer(data)
end

Gui.on_click(poll_view_back_name, function(event)
    do_direction(event, -1)
end)

Gui.on_click(poll_view_forward_name, function(event)
    do_direction(event, 1)
end)

Gui.on_click(poll_view_vote_name, vote)

function Class.reset()
    for k, _ in pairs(polls) do
        polls[k] = nil
    end
    for k, _ in pairs(player_poll_index) do
        player_poll_index[k] = nil
    end
    for k, _ in pairs(player_create_poll_data) do
        player_create_poll_data[k] = nil
    end
    for _, p in pairs(game.connected_players) do
        local main_frame = Gui.get_left_element(p, main_frame_name)
        if main_frame and main_frame.valid then
            local main_frame_data = Gui.get_data(main_frame)
            local poll_index = main_frame_data.poll_index
            update_poll_viewer(main_frame_data)
            remove_main_frame(main_frame, p)
        end
    end
end

function Class.get_no_notify_players()
    return no_notify_players
end

function Class.validate(data)
    if type(data) ~= 'table' then
        return false, 'argument must be of type table'
    end

    local question = data.question
    if type(question) ~= 'string' or question == '' then
        return false, 'field question must be a non empty string.'
    end

    local answers = data.answers
    if type(answers) ~= 'table' then
        return false, 'answers field must be an array.'
    end

    if #answers == 0 then
        return false, 'answer array must contain at least one entry.'
    end

    for _, a in pairs(answers) do
        if type(a) ~= 'string' or a == '' then
            return false, 'answers must be a non empty string.'
        end
    end

    local duration = data.duration
    local duration_type = type(duration)
    if duration_type == 'number' then
        if duration < 0 then
            return false, 'duration cannot be negative, set duration to 0 for endless poll.'
        end
    elseif duration_type ~= 'nil' then
        return false, 'duration must be of type number or nil'
    end

    return true
end

function Class.poll(data)
    local suc, error = Class.validate(data)
    if not suc then
        return false, error
    end

    local answers = {}
    for index, a in pairs(data.answers) do
        if a ~= '' then
            insert(answers, { text = a, index = index, voted_count = 0 })
        end
    end

    local duration = data.duration
    if duration then
        duration = duration * 60
    else
        duration = default_poll_duration * 60
    end

    local start_tick = game.tick
    local end_tick
    if duration == 0 then
        end_tick = -1
    else
        end_tick = start_tick + duration
    end

    local id = poll_id()

    local poll_data = {
        id = id,
        question = data.question,
        answers = answers,
        voters = {},
        start_tick = start_tick,
        end_tick = end_tick,
        duration = duration,
        created_by = game.player or { name = '<server>', valid = true },
        edited_by = {},
    }

    insert(polls, poll_data)

    show_new_poll(poll_data)
    send_poll_result_to_discord(poll_data)

    return true, id
end

function Class.poll_result(id)
    if type(id) ~= 'number' then
        return 'poll-id must be a number'
    end

    for _, poll_data in pairs(polls) do
        if poll_data.id == id then
            local result = { 'Question: ', poll_data.question, ' Answers: ' }
            local answers = poll_data.answers
            local answers_count = #answers
            for i, a in pairs(answers) do
                insert(result, '( [')
                insert(result, a.voted_count)
                insert(result, '] - ')
                insert(result, a.text)
                insert(result, ' )')
                if i ~= answers_count then
                    insert(result, ', ')
                end
            end

            return table.concat(result)
        end
    end

    return table.concat({ 'poll #', id, ' not found' })
end

function Class.send_poll_result_to_discord(id)
    if type(id) ~= 'number' then
        Server.to_discord_embed('poll-id must be a number')
        return
    end

    for _, poll_data in pairs(polls) do
        if poll_data.id == id then
            send_poll_result_to_discord(poll_data)
            return
        end
    end

    local message = table.concat({ 'poll #', id, ' not found' })
    Server.to_discord_embed(message)
end

return Class
