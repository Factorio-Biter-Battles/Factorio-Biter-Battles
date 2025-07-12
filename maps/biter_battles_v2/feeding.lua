local bb_config = require('maps.biter_battles_v2.config')
local FeedingCalculations = require('maps.biter_battles_v2.feeding_calculations')
local Functions = require('maps.biter_battles_v2.functions')
local Server = require('utils.server')

local tables = require('maps.biter_battles_v2.tables')
local food_values = tables.food_values
local force_translation = tables.force_translation
local enemy_team_of = tables.enemy_team_of
local math_floor = math.floor
local math_round = math.round
local safe_wrap_with_player_print = require('utils.utils').safe_wrap_with_player_print
local malloc = require('maps.biter_battles_v2.pool').malloc
local food_long_and_short = tables.food_long_and_short

local Public = {}

local function update_boss_modifiers(force_name_biter, damage_mod_mult, speed_mod_mult)
    local damage_mod = math_round(storage.bb_evolution[force_name_biter] * 1.0, 3) * damage_mod_mult
    local speed_mod = math_round(storage.bb_evolution[force_name_biter] * 0.25, 3) * speed_mod_mult
    local force = game.forces[force_name_biter .. '_boss']
    force.set_ammo_damage_modifier('melee', damage_mod)
    force.set_ammo_damage_modifier('biological', damage_mod)
    force.set_ammo_damage_modifier('artillery-shell', damage_mod)
    force.set_ammo_damage_modifier('flamethrower', damage_mod)
    force.set_gun_speed_modifier('melee', speed_mod)
    force.set_gun_speed_modifier('biological', speed_mod)
    force.set_gun_speed_modifier('artillery-shell', speed_mod)
    force.set_gun_speed_modifier('flamethrower', speed_mod)
end

local function set_biter_endgame_modifiers(force)
    if force.get_evolution_factor(storage.bb_surface_name) ~= 1 then
        return
    end

    local damage_mod = math_round((storage.bb_evolution[force.name] - 1) * 1.0, 3)
    force.set_ammo_damage_modifier('melee', damage_mod)
    force.set_ammo_damage_modifier('biological', damage_mod)
    force.set_ammo_damage_modifier('artillery-shell', damage_mod)
    force.set_ammo_damage_modifier('flamethrower', damage_mod)
end

local function get_enemy_team_of(team)
    if storage.training_mode then
        return team
    else
        return enemy_team_of[team]
    end
end

local function print_feeding_msg(player, food, flask_amount)
    local enemy = get_enemy_team_of(player.force.name)
    if not enemy then
        return
    end

    local colored_player_name = table.concat({
        '[color=',
        player.color.r * 0.6 + 0.35,
        ',',
        player.color.g * 0.6 + 0.35,
        ',',
        player.color.b * 0.6 + 0.35,
        ']',
        player.name,
        '[/color]',
    })
    local formatted_food = table.concat({
        '[color=',
        food_values[food].color,
        ']',
        food_values[food].name,
        ' juice[/color]',
        '[img=item/',
        food,
        ']',
    })
    local formatted_amount = table.concat({ '[font=heading-1][color=255,255,255]', flask_amount, '[/color][/font]' })

    if flask_amount >= 20 then
        game.print(
            table.concat({
                colored_player_name,
                ' fed ',
                formatted_amount,
                ' flasks of ',
                formatted_food,
                ' to ',
                Functions.team_name_with_color(enemy),
                "'s biters!",
            }),
            { color = { r = 0.9, g = 0.9, b = 0.9 } }
        )
        Server.to_discord_bold(table.concat({
            player.name,
            ' fed ',
            flask_amount,
            ' flasks of ',
            food_values[food].name,
            ' to team ',
            enemy,
            ' biters!',
        }))
    else
        local target_team_text = 'the enemy'
        if storage.training_mode then
            target_team_text = 'your own'
        end
        if flask_amount == 1 then
            player.print(
                'You fed one flask of ' .. formatted_food .. ' to ' .. target_team_text .. " team's biters.",
                { color = { r = 0.98, g = 0.66, b = 0.22 } }
            )
        else
            player.print(
                'You fed '
                    .. formatted_amount
                    .. ' flasks of '
                    .. formatted_food
                    .. ' to '
                    .. target_team_text
                    .. " team's biters.",
                { color = { r = 0.98, g = 0.66, b = 0.22 } }
            )
        end
    end
end

--- @param player LuaPlayer?
--- @param feeding_force_name string
--- @param food string
--- @param flask_amount number
--- @param biter_force_name string
--- @param evo_before_science_feed number
--- @param threat_before_science_feed number
function Public.add_feeding_stats(
    player,
    feeding_force_name,
    food,
    flask_amount,
    biter_force_name,
    evo_before_science_feed,
    threat_before_science_feed
)
    local colored_player_name = 'unknown player'
    if player then
        colored_player_name = table.concat({
            '[color=',
            player.color.r * 0.6 + 0.35,
            ',',
            player.color.g * 0.6 + 0.35,
            ',',
            player.color.b * 0.6 + 0.35,
            ']',
            player.name,
            '[/color]',
        })
    end
    local formatted_food = table.concat({ '[color=', food_values[food].color, '][/color]', '[img=item/', food, ']' })
    local formatted_amount = table.concat({ '[font=heading-1][color=255,255,255]', flask_amount, '[/color][/font]' })
    if flask_amount > 0 then
        local tick = Functions.get_ticks_since_game_start()
        local feed_time_mins = math_round(tick / (60 * 60), 0)
        local minute_unit = ''
        if feed_time_mins <= 1 then
            minute_unit = 'min'
        else
            minute_unit = 'mins'
        end

        local shown_feed_time_hours = ''
        local shown_feed_time_mins = ''
        shown_feed_time_mins = feed_time_mins .. minute_unit
        local formatted_feed_time = shown_feed_time_hours .. shown_feed_time_mins
        evo_before_science_feed = math_round(evo_before_science_feed * 100, 1)
        threat_before_science_feed = math_round(threat_before_science_feed, 0)
        local formatted_evo_after_feed = math_round(storage.bb_evolution[biter_force_name] * 100, 1)
        local formatted_threat_after_feed = math_round(storage.bb_threat[biter_force_name], 0)
        local evo_jump = table.concat({ evo_before_science_feed, ' to ', formatted_evo_after_feed })
        local threat_jump = table.concat({ threat_before_science_feed, ' to ', formatted_threat_after_feed })
        local evo_jump_difference = math_round(formatted_evo_after_feed - evo_before_science_feed, 1)
        local threat_jump_difference = math_round(formatted_threat_after_feed - threat_before_science_feed, 0)
        local line_log_stats_to_add =
            table.concat({ formatted_amount, ' ', formatted_food, ' by ', colored_player_name, ' to ' })
        local team_name_fed_by_science = get_enemy_team_of(feeding_force_name)

        if storage.science_logs_total_north == nil then
            storage.science_logs_total_north = malloc(#food_long_and_short)
            storage.science_logs_total_south = malloc(#food_long_and_short)
        end

        local total_science_of_player_force = nil
        if feeding_force_name == 'north' then
            total_science_of_player_force = storage.science_logs_total_north
        else
            total_science_of_player_force = storage.science_logs_total_south
        end

        local indexScience = tables.food_long_to_short[food].indexScience
        total_science_of_player_force[indexScience] = total_science_of_player_force[indexScience] + flask_amount

        if storage.science_logs_text then
            table.insert(storage.science_logs_date, 1, formatted_feed_time)
            table.insert(storage.science_logs_text, 1, line_log_stats_to_add)
            table.insert(storage.science_logs_evo_jump, 1, evo_jump)
            table.insert(storage.science_logs_evo_jump_difference, 1, evo_jump_difference)
            table.insert(storage.science_logs_threat, 1, threat_jump)
            table.insert(storage.science_logs_threat_jump_difference, 1, threat_jump_difference)
            table.insert(storage.science_logs_fed_team, 1, team_name_fed_by_science)
            table.insert(storage.science_logs_food_name, 1, food)
        else
            storage.science_logs_date = { formatted_feed_time }
            storage.science_logs_text = { line_log_stats_to_add }
            storage.science_logs_evo_jump = { evo_jump }
            storage.science_logs_evo_jump_difference = { evo_jump_difference }
            storage.science_logs_threat = { threat_jump }
            storage.science_logs_threat_jump_difference = { threat_jump_difference }
            storage.science_logs_fed_team = { team_name_fed_by_science }
            storage.science_logs_food_name = { food }
        end
    end
end

function Public.do_raw_feed(flask_amount, food, biter_force_name)
    local force_index = game.forces[biter_force_name].index
    local decimals = 9

    local food_value = food_values[food].value * storage.difficulty_vote_value

    local evo = storage.bb_evolution[biter_force_name]
    local threat = 0.0

    local current_player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
    local effects = FeedingCalculations.calc_feed_effects(
        evo,
        food_value,
        flask_amount,
        current_player_count,
        storage.max_reanim_thresh
    )
    evo = evo + effects.evo_increase
    threat = threat + effects.threat_increase * (storage.threat_multiplier or 1)
    evo = math_round(evo, decimals)
    storage.biter_health_factor[force_index] = effects.biter_health_factor

    --SET THREAT INCOME
    storage.bb_threat_income[biter_force_name] = evo * 25

    game.forces[biter_force_name].set_evolution_factor(math.min(evo, 1), storage.bb_surface_name)
    storage.bb_evolution[biter_force_name] = evo
    set_biter_endgame_modifiers(game.forces[biter_force_name])

    if evo > 1 then
        update_boss_modifiers(biter_force_name, 2, 1)
    end
    if evo > 3.3 then -- 330% evo => 3.3
        storage.max_group_size[biter_force_name] = 50
    elseif evo > 2.3 then
        storage.max_group_size[biter_force_name] = 75
    elseif evo > 1.3 then
        storage.max_group_size[biter_force_name] = 100
    elseif evo > 0.7 then
        storage.max_group_size[biter_force_name] = 200
    end

    storage.bb_threat[biter_force_name] = math_round(storage.bb_threat[biter_force_name] + threat, decimals)

    if storage.active_special_games['shared_science_throw'] then
        local enemyBitersForceName = enemy_team_of[force_translation[biter_force_name]] .. '_biters'
        game.forces[enemyBitersForceName].set_evolution_factor(
            game.forces[biter_force_name].get_evolution_factor(storage.bb_surface_name),
            storage.bb_surface_name
        )
        storage.bb_evolution[enemyBitersForceName] = storage.bb_evolution[biter_force_name]
        storage.bb_threat_income[enemyBitersForceName] = storage.bb_threat_income[biter_force_name]
        storage.bb_threat[enemyBitersForceName] = math_round(storage.bb_threat[enemyBitersForceName] + threat, decimals)
    end
end

--- @param player LuaPlayer
--- @param food string
function Public.feed_biters_from_inventory(player, food)
    local tick = Functions.get_ticks_since_game_start()
    if storage.active_special_games['captain_mode'] then
        tick = game.ticks_played
    end
    if tick <= storage.difficulty_votes_timeout then
        player.print('Please wait for voting to finish before feeding')
        return
    end

    local enemy_force_name = get_enemy_team_of(player.force.name) ---------------
    --enemy_force_name = player.force.name

    local biter_force_name = enemy_force_name .. '_biters'

    local i = player.character.get_main_inventory()
    if not i then
        return
    end
    local flask_amount = i.get_item_count(food)
    if flask_amount == 0 then
        player.print(
            'You have no ' .. food_values[food].name .. ' flask in your inventory.',
            { color = { r = 0.98, g = 0.66, b = 0.22 } }
        )
        return
    end

    i.remove({ name = food, count = flask_amount })

    print_feeding_msg(player, food, flask_amount)
    local evolution_before_feed = storage.bb_evolution[biter_force_name]
    local threat_before_feed = storage.bb_threat[biter_force_name]

    Public.do_raw_feed(flask_amount, food, biter_force_name)

    Public.add_feeding_stats(
        player,
        player.force.name,
        food,
        flask_amount,
        biter_force_name,
        evolution_before_feed,
        threat_before_feed
    )

    if food == 'space-science-pack' then
        storage.spy_fish_timeout[player.force.name] = game.tick + 99999999
    end
end

--- @param player LuaPlayer
--- @param button defines.mouse_button_type
function Public.feed_biters_mixed_from_inventory(player, button)
    local tick = Functions.get_ticks_since_game_start()
    if storage.active_special_games['captain_mode'] then
        tick = game.ticks_played
    end
    if tick <= storage.difficulty_votes_timeout then
        player.print('Please wait for voting to finish before feeding')
        return
    end
    local enemy_force_name = get_enemy_team_of(player.force.name)
    local biter_force_name = enemy_force_name .. '_biters'
    local food = {
        'automation-science-pack',
        'logistic-science-pack',
        'military-science-pack',
        'chemical-science-pack',
        'production-science-pack',
        'utility-science-pack',
        'space-science-pack',
    }
    if button == defines.mouse_button_type.right then
        food = {
            'space-science-pack',
            'utility-science-pack',
            'production-science-pack',
            'chemical-science-pack',
            'military-science-pack',
            'logistic-science-pack',
            'automation-science-pack',
        }
    end
    local i = player.character.get_main_inventory()
    if not i then
        return
    end
    local colored_player_name = table.concat({
        '[color=',
        player.color.r * 0.6 + 0.35,
        ',',
        player.color.g * 0.6 + 0.35,
        ',',
        player.color.b * 0.6 + 0.35,
        ']',
        player.name,
        '[/color]',
    })
    local message = { colored_player_name, ' fed ' }
    for k, v in pairs(food) do
        local evolution_before_feed = storage.bb_evolution[biter_force_name]
        local threat_before_feed = storage.bb_threat[biter_force_name]
        local flask_amount = i.get_item_count(v)
        if flask_amount ~= 0 then
            table.insert(
                message,
                '[font=heading-1][color=255,255,255]' .. flask_amount .. '[/color][/font]' .. '[img=item.' .. v .. '], '
            )
            Server.to_discord_bold(table.concat({
                player.name,
                ' fed ',
                flask_amount,
                ' flasks of ',
                food_values[v].name,
                ' to team ',
                enemy_force_name,
                ' biters!',
            }))
            Public.do_raw_feed(flask_amount, v, biter_force_name)
            Public.add_feeding_stats(
                player,
                player.force.name,
                v,
                flask_amount,
                biter_force_name,
                evolution_before_feed,
                threat_before_feed
            )
            i.remove({ name = v, count = flask_amount })
            if v == 'space-science-pack' then
                storage.spy_fish_timeout[player.force.name] = game.tick + 99999999
            end
        end
    end
    if #message == 2 then
        player.print('You have no flasks in your inventory', { color = { r = 0.98, g = 0.66, b = 0.22 } })
        return
    end
    table.insert(message, 'to ' .. Functions.team_name_with_color(enemy_force_name) .. "'s biters!")
    game.print(table.concat(message), { color = { r = 0.9, g = 0.9, b = 0.9 } })
end

local function calc_send(cmd)
    local player
    if cmd.player_index then
        player = game.get_player(cmd.player_index)
    end
    local player_count = #game.forces.north.connected_players + #game.forces.south.connected_players
    local result = safe_wrap_with_player_print(
        player,
        FeedingCalculations.calc_send_command,
        cmd.parameter,
        storage.difficulty_vote_value,
        storage.bb_evolution,
        storage.max_reanim_thresh,
        storage.training_mode,
        player_count,
        player
    )
    if not result then
        return
    end
    if player then
        player.print(result)
    else
        game.print(result)
    end
end

commands.add_command('calc-send', 'Calculate the impact of sending science', calc_send)

return Public
