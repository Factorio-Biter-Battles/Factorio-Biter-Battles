local Tables = require('maps.biter_battles_v2.tables')
local Quality = require('maps.biter_battles_v2.quality')
local bb_config = require('maps.biter_battles_v2.config')

local math_floor = math.floor

local Public = {}

---@param current_player_count integer
---@return number
local function get_instant_threat_player_count_modifier(current_player_count)
    local minimum_modifier = 125
    local maximum_modifier = 250
    local player_amount_for_maximum_threat_gain = 20
    local gain_per_player = (maximum_modifier - minimum_modifier) / player_amount_for_maximum_threat_gain
    local m = minimum_modifier + gain_per_player * current_player_count
    return math.min(m, maximum_modifier)
end

---@param initial_evo number
---@param food_value number
---@param num_flasks integer
---@param current_player_count integer
---@param max_reanim_thresh number Long ago, we used reanim_chance rather than health_factor, and this is the evo value at which it would sortof be 100% reanim_chance
---@return { evo_increase: number, threat_increase: number, biter_health_factor: number }
function Public.calc_feed_effects(initial_evo, food_value, num_flasks, current_player_count, max_reanim_thresh)
    local threat = 0
    local evo = initial_evo
    local food = food_value * num_flasks
    local threat_scale_factor_past_evo100 = bb_config.threat_scale_factor_past_evo100
    while food > 0 do
        local clamped_evo = math.min(evo, 1)
        ---SET EVOLUTION
        local e2 = (clamped_evo * 100) + 1
        local diminishing_modifier = (1 / (10 ^ (e2 * 0.015))) / (e2 * 0.5)
        local amount_of_food_this_iteration
        -- By growing by at least 1%, or exponentially by 10% of current evo, whichever is higher,
        -- we ensure that this will run a bounded number of times, even if /calc-send is run with
        -- very high numbers.
        local max_evo_gain_per_iteration
        if evo < 1 then
            max_evo_gain_per_iteration = 0.01
        else
            max_evo_gain_per_iteration = evo / 10
        end
        amount_of_food_this_iteration = math.min(food, max_evo_gain_per_iteration / diminishing_modifier)
        local evo_gain = (amount_of_food_this_iteration * diminishing_modifier)
        evo = evo + evo_gain

        --ADD INSTANT THREAT
        local diminishing_modifier = 1 / (0.2 + (e2 * 0.016))
        if evo > 1 then
            -- Give bonus threat for sending as evo grows
            diminishing_modifier = diminishing_modifier * (1 + (evo - 1) * threat_scale_factor_past_evo100)
        end
        threat = threat + (amount_of_food_this_iteration * diminishing_modifier)

        food = food - amount_of_food_this_iteration
    end
    -- Calculates reanimation chance. This value is normalized onto
    -- maximum re-animation threshold. For example if real evolution is 150
    -- and max is 350, then 150 / 350 = 42% chance.
    local reanim_chance = math_floor(math.max(evo - 1.0, 0) * 100.0)
    reanim_chance = reanim_chance / max_reanim_thresh * 100
    reanim_chance = math.min(math_floor(reanim_chance), 90.0)

    threat = threat * get_instant_threat_player_count_modifier(current_player_count)

    return {
        evo_increase = evo - initial_evo,
        threat_increase = threat,
        biter_health_factor = 1 / (1 - reanim_chance / 100),
    }
end

-- Player can be nil
---@param params string
---@param difficulty_vote_value number
---@param bb_evolution { string: number }
---@param max_reanim_thresh number
---@param training_mode boolean
---@param player_count integer
---@param player LuaPlayer|nil
---@return string
function Public.calc_send_command(
    params,
    difficulty_vote_value,
    bb_evolution,
    max_reanim_thresh,
    training_mode,
    player_count,
    player
)
    if params == nil then
        params = ''
    end
    local difficulty = difficulty_vote_value * 100
    local evo = nil
    local error_msg
    local flask_color
    local flask_count
    local flask_quality = Quality.TIER_DEFAULT
    local force_to_send_to
    local help_text
    if Quality.enabled() then
        help_text = '\nUsage: /calc-send evo=20.0 difficulty=30 players=4 color=green quality=rare count=1000'
            .. '\nUsage: /calc-send force=north color=white quality=rare count=1000'
    else
        help_text = '\nUsage: /calc-send evo=20.0 difficulty=30 players=4 color=green count=1000'
            .. '\nUsage: /calc-send force=north color=white count=1000'
    end

    if player and training_mode then
        force_to_send_to = player.force.name
    elseif player and player.force.name == 'north' then
        force_to_send_to = 'south'
    elseif player and player.force.name == 'south' then
        force_to_send_to = 'north'
    end
    local tiers = Quality.max_tier()
    ---@type table<string, number[]>
    local foods = {}
    ---@type table<number, number>
    local q_values = {}
    for k, _ in pairs(Tables.food_names) do
        foods[k] = {}
        -- indexed by tier
        for i = 1, tiers do
            foods[k][i] = 0
            q_values[i] = 0
        end
    end

    for param in string.gmatch(params, '([^%s]+)') do
        local k, v = string.match(param, '^(%w+)=([%w%p]+)$')
        if k and v then
            if k == 'force' then
                if v == 'n' or v == 'nth' or v == 'north' then
                    force_to_send_to = 'north'
                elseif v == 's' or v == 'sth' or v == 'south' then
                    force_to_send_to = 'south'
                else
                    error_msg = 'Invalid force'
                end
            elseif k == 'evo' then
                evo = tonumber(v)
                if evo == nil or evo < 0 or evo > 100000 then
                    error_msg = 'Invalid evo'
                end
            elseif k == 'difficulty' then
                difficulty = tonumber(v)
                if difficulty == nil or difficulty < 0 or difficulty > 10000 then
                    error_msg = 'Invalid difficulty'
                end
            elseif k == 'players' then
                player_count = tonumber(v)
                if
                    player_count == nil
                    or player_count < 0
                    or player_count > 10000
                    or player_count ~= math_floor(player_count)
                then
                    error_msg = 'Invalid player count'
                end
            elseif k == 'color' or k == 'colour' then
                if v == 'red' or v == 'automation' then
                    v = 'automation-science-pack'
                end
                if v == 'green' or v == 'logistic' then
                    v = 'logistic-science-pack'
                end
                if v == 'gray' or v == 'grey' or v == 'black' or v == 'military' then
                    v = 'military-science-pack'
                end
                if v == 'blue' or v == 'chemical' then
                    v = 'chemical-science-pack'
                end
                if v == 'purple' or v == 'production' then
                    v = 'production-science-pack'
                end
                if v == 'yellow' or v == 'utility' then
                    v = 'utility-science-pack'
                end
                if v == 'white' or v == 'space' then
                    v = 'space-science-pack'
                end
                local values = Tables.food_values[v]
                if values == nil then
                    error_msg = 'Invalid science pack color'
                else
                    flask_color = v
                end
            elseif k == 'quality' then
                if Quality.enabled() then
                    if flask_color == nil then
                        error_msg = 'Must specify flask color before quality'
                    else
                        local proto = prototypes.quality[v]
                        if proto == nil then
                            error_msg = string.format('Invalid quality name: %q', v)
                        else
                            flask_quality = Quality.tier_index_by_level(proto.level)
                        end
                    end
                else
                    error_msg = 'Quality is not enabled!'
                end
            elseif k == 'count' then
                if flask_color == nil then
                    error_msg = 'Must specify flask color before count'
                else
                    flask_count = tonumber(v)
                    if flask_count == nil or flask_count <= 0 or flask_count > 1000000000 then
                        error_msg = 'Invalid flask count'
                    else
                        foods[flask_color][flask_quality] = foods[flask_color][flask_quality] + flask_count
                    end
                end
                flask_color = nil
                flask_quality = nil
            else
                error_msg = string.format('Invalid parameter: %q', k)
            end
        else
            error_msg = string.format('Invalid parameter: %q, must do things like "evo=120"', param)
        end
        if error_msg then
            break
        end
    end
    if flask_color ~= nil then
        error_msg = 'Must specify "count" after "color"'
    end

    if error_msg == nil and params == '' and player ~= nil then
        local i = player.character.get_main_inventory()
        if i then
            for food_type, _ in pairs(Tables.food_values) do
                local req = {
                    name = food_type,
                }

                for j = 1, tiers do
                    req.quality = Quality.TIERS[j].name
                    local flask_amount = i.get_item_count(req)
                    if flask_amount > 0 then
                        foods[food_type][j] = flask_amount
                    end
                end
            end
        end
    end
    local biter_force_name
    if evo == nil and force_to_send_to then
        biter_force_name = force_to_send_to .. '_biters'
        if bb_evolution[biter_force_name] then
            evo = bb_evolution[biter_force_name] * 100
        end
    end
    if error_msg == nil and evo == nil then
        error_msg = 'Must specify evo (or force)'
    end
    if error_msg then
        return error_msg .. help_text
    end
    local total_food = 0
    local debug_command_str =
        string.format('evo=%.1f difficulty=%d players=%d', evo, math.floor(difficulty), player_count)
    for color, v in pairs(foods) do
        for tier, count in pairs(v) do
            if count ~= 0 then
                local quality = Quality.TIERS[tier]
                total_food = total_food + quality.multiplier * count * Tables.food_values[color].value
                if Quality.enabled() then
                    q_values[tier] = Quality.dry_feed_flasks(q_values[tier], color, count, difficulty_vote_value)
                    debug_command_str = debug_command_str
                        .. string.format('\ncolor=%s quality=%s count=%d', color, quality.name, count)
                else
                    debug_command_str = debug_command_str .. string.format('\ncolor=%s count=%d', color, count)
                end
            end
        end
    end

    if total_food == 0 then
        error_msg = 'no "color"/"count" specified and nothing found in inventory'
    end
    if error_msg then
        return error_msg .. help_text
    end

    local q_probs_str = {}
    if Quality.enabled() then
        local q_curr_values = Quality.collect_values(biter_force_name)
        for i, v in ipairs(q_values) do
            q_curr_values[i] = q_curr_values[i] + v
        end

        local q_probs = Quality.dry_test_probabilities(q_curr_values)
        for i, q_prob in ipairs(q_probs) do
            table.insert(q_probs_str, string.format('\n %s: %.2f%%', Quality.TIERS[i].name, q_prob))
        end
    end

    local effects =
        Public.calc_feed_effects(evo / 100, total_food * difficulty / 100, 1, player_count, max_reanim_thresh)
    return string.format(
        '/calc-send %s\nevo_increase: %.1f new_evo: %.1f\nthreat_increase: %d%s',
        debug_command_str,
        effects.evo_increase * 100,
        evo + effects.evo_increase * 100,
        math.floor(effects.threat_increase),
        table.concat(q_probs_str)
    )
end

return Public
