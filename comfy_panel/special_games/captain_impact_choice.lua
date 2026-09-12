local Seed = require('comfy_panel.special_games.captain_impact_choice_seed')

local Public = {}

local function finite(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

local function logistic(x)
    if x >= 0 then
        return 1 / (1 + math.exp(-x))
    end
    local z = math.exp(x)
    return z / (1 + z)
end

function Public.get_metadata()
    return {
        model_version = Seed.model_version,
        trained_regime = Seed.trained_regime,
        impact_policy = Seed.impact_policy,
        last_match_date = Seed.last_match_date,
        validation_status = Seed.validation_status,
        validation_accuracy = Seed.validation_accuracy,
        validation_log_loss = Seed.validation_log_loss,
        validation_brier = Seed.validation_brier,
    }
end

function Public.get_history(player_name)
    local row = Seed.players[player_name]
    if not row then
        return nil
    end
    -- Do not expose the mutable seed table to UI callers or match records.
    local result = {}
    for key, value in pairs(row) do
        result[key] = value
    end
    return result
end

-- Score for a pairwise comparison at the SAME current pick. This is a
-- historical preference estimate, not a win contribution or a pick allocation
-- value. The auxiliary base coefficients are frozen in this seed too: live
-- outcome learning cannot silently change this model's predictions.
function Public.score(player_name, pick_index, prior_games)
    if not finite(pick_index) or pick_index < 1 or pick_index % 1 ~= 0 then
        return nil
    end
    local row = Seed.players[player_name]
    if prior_games == nil then
        prior_games = row and row.prior_games or 0
    end
    if not finite(prior_games) or prior_games < 0 then
        return nil
    end
    local stage = pick_index <= 6 and 1 or (pick_index <= 15 and 2 or 3)
    local experience = -math.exp(-prior_games / Seed.experience_tau)
    local choice = (row and row.choice_logodds or 0) + Seed.experience_coefficient * experience
    local base = (row and row.base_skill_logodds or 0) + Seed.base_experience_coefficient * experience
    return Seed.stage_choice_weights[stage] * choice + Seed.stage_base_weights[stage] * 2 * base
end

function Public.pair_probability(score_a, score_b)
    if not finite(score_a) or not finite(score_b) then
        return nil
    end
    return logistic(score_a - score_b)
end

function Public.history_tooltip(player_name)
    local row = Seed.players[player_name]
    if not row or row.pick_games == 0 then
        return 'No historical pick-position evidence.'
    end
    local lines = {
        'Historical pick evidence through ' .. string.sub(Seed.last_match_date, 1, 10) .. ':',
        string.format(
            'Average team pick %.2f; median %.1f; %d drafts (captains excluded).',
            row.avg_team_pick,
            row.median_team_pick,
            row.pick_games
        ),
    }
    if row.avg_team_pick_fraction then
        lines[#lines + 1] = string.format(
            'Average position within the team list: %.1f%% (0%% first, 100%% last; accounts for list size).',
            100 * row.avg_team_pick_fraction
        )
    end
    if row.global_pick_games > 0 then
        lines[#lines + 1] = string.format(
            'Average overall pick %.2f across %d drafts with reconstructed order.',
            row.avg_global_pick,
            row.global_pick_games
        )
    end
    if row.recent_pick_games > 0 then
        lines[#lines + 1] = string.format(
            'Last historical year: average team pick %.2f across %d drafts.',
            row.recent_avg_team_pick,
            row.recent_pick_games
        )
    end
    if row.pick_games < 10 then
        lines[#lines + 1] = 'Limited evidence: fewer than 10 observed drafts.'
    end
    lines[#lines + 1] =
        'Pick positions also reflect available players, roles, groups and late arrivals. They are not win-strength ratings.'
    return table.concat(lines, '\n')
end

return Public
