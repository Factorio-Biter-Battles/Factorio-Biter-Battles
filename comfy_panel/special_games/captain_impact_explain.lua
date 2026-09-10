local Impact = require('comfy_panel.special_games.captain_impact_model')
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local Color = require('utils.color_presets')
local gui_style = require('utils.utils').gui_style

local Public = {}
local FRAME_NAME = 'captain_impact_explain_ui'

local function signed(value, digits)
    return string.format('%+.' .. tostring(digits or 3) .. 'f', tonumber(value) or 0)
end

local function add_section(parent, caption)
    local label = parent.add({ type = 'label', caption = caption, style = 'semibold_label' })
    gui_style(label, { top_margin = 7, bottom_margin = 3 })
    return label
end

local function add_pair(tab, left, right, tooltip)
    local a = tab.add({ type = 'label', caption = left })
    gui_style(a, { minimal_width = 235 })
    local b = tab.add({ type = 'label', caption = right, tooltip = tooltip or '' })
    b.style.horizontal_align = 'right'
    gui_style(b, { minimal_width = 145 })
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
    gui_style(frame, { minimal_width = 560, maximal_width = 640, minimal_height = 680, maximal_height = 780 })

    local title_flow = frame.add({ type = 'flow', direction = 'horizontal' })
    local title = title_flow.add({ type = 'label', caption = 'How Captain Impact ratings work', style = 'frame_title' })
    title.drag_target = frame
    local dragger = title_flow.add({ type = 'empty-widget', style = 'draggable_space_header' })
    dragger.drag_target = frame
    gui_style(dragger, { horizontally_stretchable = true, height = 24 })
    title_flow.add({ type = 'sprite-button', name = 'captain_impact_explain_close', sprite = 'utility/close', style = 'frame_action_button' })

    local scroll = frame.add({ type = 'scroll-pane', direction = 'vertical' })
    gui_style(scroll, { horizontally_stretchable = true, vertically_stretchable = true, minimal_height = 585, maximal_height = 675, padding = 8 })

    local flow = scroll.add({ type = 'flow', direction = 'vertical' })
    gui_style(flow, { horizontally_stretchable = true })

    local key = flow.add({
        type = 'label',
        caption = '[font=default-large-bold]Games  ->  Skill  ->  Experience  ->  vs Average  ->  AMWI[/font]',
    })
    key.style.font_color = Color.light_cyan
    key.style.horizontal_align = 'center'
    gui_style(key, { horizontally_stretchable = true, bottom_margin = 8 })

    local intro = flow.add({
        type = 'label',
        caption = 'The model does not assign AMWI directly. It first learns a native player-strength value, then converts that value into an easier win-probability display.',
    })
    gui_style(intro, { single_line = false, maximal_width = 540 })

    add_section(flow, '1. Games -> persistent skill')
    local games = flow.add({
        type = 'label',
        caption = 'Historical match results are evaluated while accounting for teammate strength, opponent strength, team size and experience. A weak Captain-pick preference signal also contributes. Small samples are pulled toward average.',
    })
    gui_style(games, { single_line = false, maximal_width = 540 })

    add_section(flow, '2. Experience -> current skill')
    local exp = flow.add({
        type = 'label',
        caption = 'Current skill = persistent skill + the shared experience adjustment. The adjustment fades toward zero with Captain Game experience. No separate recent-form bonus is currently deployed.',
    })
    gui_style(exp, { single_line = false, maximal_width = 540 })

    add_section(flow, '3. Current skill -> AMWI')
    local amwi = flow.add({
        type = 'label',
        caption = 'Current skill is compared with the active established-player average. That advantage is translated across typical Captain Game situations into Average Marginal Win Impact (AMWI).',
    })
    gui_style(amwi, { single_line = false, maximal_width = 540 })

    local note = flow.add({
        type = 'label',
        caption = '[font=default-bold]AMWI is a display metric, not a score that can be added between players.[/font] Impact Dynamic balances complete rosters with the native additive log-odds model, then converts the result to win probability.',
    })
    note.style.font_color = Color.yellow
    gui_style(note, { single_line = false, maximal_width = 540, top_margin = 7, bottom_margin = 7 })

    add_section(flow, 'Worked example - Jimmy50')
    local b = Impact.get_rating_breakdown('Jimmy50')
    local tab = flow.add({ type = 'table', column_count = 2 })
    add_pair(tab, 'Historical Captain Games', tostring(b.games))
    add_pair(tab, 'Persistent skill', signed(b.persistent_skill_logodds, 3) .. ' log-odds', 'Native additive player-strength scale.')
    add_pair(tab, 'Experience adjustment', signed(b.experience_adjustment_logodds, 3), 'Shared experience curve at Jimmy50\'s historical game count.')
    add_pair(tab, 'Current skill', signed(b.current_skill_logodds, 3) .. ' log-odds')
    add_pair(tab, Seed.reference_caption or 'Established average', signed(b.reference_current_skill_logodds, 3))
    add_pair(tab, 'Advantage vs average', signed(b.advantage_vs_reference_logodds, 3) .. ' log-odds')
    if b.amwi_pp then
        add_pair(tab, 'Realized AMWI', string.format('%+.1f pp', b.amwi_pp))
        add_pair(tab, '95% bootstrap range', string.format('%+.1f to %+.1f pp', b.amwi_low_pp or b.amwi_pp, b.amwi_high_pp or b.amwi_pp))
        add_pair(tab, 'Likely rank', string.format('#%.0f - #%.0f', b.rank_low or b.rank, b.rank_high or b.rank))
    end

    local effort_note = flow.add({
        type = 'label',
        caption = "[font=default-bold]Match effort:[/font] players can declare 0-100% effort in the lobby. Because this signal is not yet calibrated, its first policy is conservative: 100%=100% value, 75%=90%, 50%=80%, 25%=70%, 0%=60%, never below the player-value floor. It does not change permanent Rank or AMWI. The declaration is stored so future outcomes can learn a better coefficient.",
    })
    effort_note.style.font_color = Color.light_cyan
    gui_style(effort_note, { single_line = false, maximal_width = 540, top_margin = 7, bottom_margin = 7 })

    local guardrail = flow.add({
        type = 'label',
        caption = "[font=default-bold]Draft guardrail:[/font] negative AMWI means below the average reference; it does NOT mean negative human value. A below-average or unrated player is never treated as free. For turn allocation, every player counts for at least 50% of the established-average player's marginal roster contribution. Rows marked * are using this floor. This is a draft-policy safety guardrail, not a change to AMWI.",
    })
    guardrail.style.font_color = Color.light_cyan
    gui_style(guardrail, { single_line = false, maximal_width = 540, top_margin = 9 })

    local excludes = flow.add({
        type = 'label',
        caption = '[font=default-bold]Not permanent AMWI bonuses:[/font] role scarcity, current draft needs, denial value and specific teammate synergy. These can matter to a particular draft/match without being baked into generic player AMWI.',
    })
    gui_style(excludes, { single_line = false, maximal_width = 540, top_margin = 9, bottom_margin = 10 })
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
    if element.name == 'captain_impact_explain_open' then
        Public.open(player)
        return true
    elseif element.name == 'captain_impact_explain_close' then
        Public.close(player)
        return true
    end
    return false
end

return Public
