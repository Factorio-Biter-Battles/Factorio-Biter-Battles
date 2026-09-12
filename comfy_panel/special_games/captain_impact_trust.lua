local Data = require('comfy_panel.special_games.captain_impact_data')
local Seed = require('comfy_panel.special_games.captain_impact_seed')
local CurrentSeed = require('comfy_panel.special_games.captain_impact_current_seed')
local Choice = require('comfy_panel.special_games.captain_impact_choice')
local LearningStore = require('comfy_panel.special_games.captain_impact_store')

local Public = {}

local function pct(x)
    return string.format('%.1f%%', 100 * x)
end

function Public.lines()
    local t = Seed.trust
    local live = Data.get_live_metrics()
    local learning = LearningStore.get_status()
    local choice = Choice.get_metadata()
    local lines =
        {
            '[font=default-large-bold]BB Captain Impact trust dashboard[/font]',
            'Seed model: ' .. Seed.model_version,
            '',
            '[font=default-bold]Retrospective historical comparisons[/font]',
            'These periods were examined during development; fresh matches are needed to confirm generalization.',
            'Match outcome: accuracy ' .. pct(t.frozen_outcome_accuracy) .. ', log loss ' .. string.format(
                '%.3f',
                t.frozen_outcome_log_loss
            ) .. ', Brier ' .. string.format('%.3f', t.frozen_outcome_brier),
            'Previous pick comparison (ties counted as correct): '
                .. pct(t.captain_pick_pairwise_accuracy)
                .. '; early '
                .. pct(t.early_pick_accuracy)
                .. ', late '
                .. pct(t.late_pick_accuracy),
            'AMWI magnitude calibration k: validation '
                .. string.format('%.2f', t.magnitude_k_validation)
                .. ', frozen '
                .. string.format('%.2f', t.magnitude_k_frozen)
                .. ' (1.00 = current spacing)',
            'Whole-model bootstrap: '
                .. tostring(t.bootstrap_successful)
                .. '/'
                .. tostring(t.bootstrap_attempted)
                .. ' successful',
            'Historical recency comparison: ' .. tostring(t.currentness_deployed),
            'Impact current-form layer: ' .. tostring(CurrentSeed.model_version)
                .. ' (pick half-life '
                .. tostring(CurrentSeed.pick_half_life_matches)
                .. ', inactivity half-life '
                .. tostring(CurrentSeed.inactivity_half_life_matches)
                .. ' matches)',
            '',
            '[font=default-bold]Historical captain-choice model[/font]',
            'Version: ' .. choice.model_version,
            'Pairwise accuracy (half credit for ties): '
                .. pct(choice.validation_accuracy)
                .. '; log loss '
                .. string.format('%.3f', choice.validation_log_loss)
                .. '; Brier '
                .. string.format('%.3f', choice.validation_brier),
            'Learned from classic draft history. Impact predictions are recorded for evaluation; they do not set AMWI or pick turns.',
            'Pick-history tooltips are frozen through ' .. string.sub(choice.last_match_date, 1, 10) .. '.',
            '',
            '[font=default-bold]Automatic outcome learner[/font]',
            'Version: ' .. tostring(learning.version),
            'Eligible games: '
                .. tostring(learning.games)
                .. '; promotions '
                .. tostring(learning.promotions)
                .. '; rollbacks '
                .. tostring(learning.rollbacks),
            'Live leaderboard: ' .. tostring(learning.games >= 20) .. '; journal pending: ' .. tostring(
                learning.pending
            ) .. '; synchronized: ' .. tostring(learning.synced),
            learning.last_error and ('Last learner error: ' .. tostring(learning.last_error))
                or 'Learner status: healthy',
            '',
            '[font=default-bold]Fresh server-native prospective data[/font]',
        }
    if live.games == 0 then
        lines[#lines + 1] = 'No completed prospective Captain Games recorded yet.'
    else
        lines[#lines + 1] = 'Games: '
            .. live.games
            .. '; accuracy '
            .. pct(live.accuracy)
            .. '; log loss '
            .. string.format('%.3f', live.log_loss)
            .. '; Brier '
            .. string.format('%.3f', live.brier)
    end
    lines[#lines + 1] = ''
    lines[#lines + 1] =
        'Interpretation: broad established-player tiers and broad AMWI gaps are more trustworthy than exact adjacent ranks or ±1 pp precision.'
    return lines
end

function Public.print(player)
    for _, line in ipairs(Public.lines()) do
        player.print(line)
    end
end

return Public
