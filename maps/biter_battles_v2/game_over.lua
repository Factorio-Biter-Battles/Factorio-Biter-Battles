local AiTargets = require('maps.biter_battles_v2.ai_targets')
local BBGui = require('maps.biter_battles_v2.gui')
local Captain_special = require('comfy_panel.special_games.captain')
local Color = require('utils.color_presets')
local Event = require('utils.event')
local Functions = require('maps.biter_battles_v2.functions')
local Gui = require('utils.gui')
local Init = require('maps.biter_battles_v2.init')
local Score = require('comfy_panel.score')
local Server = require('utils.server')
local Special_games = require('comfy_panel.special_games')
local Tables = require('maps.biter_battles_v2.tables')
local Task = require('utils.task')
local Token = require('utils.token')
local team_stats_compare = require('maps.biter_battles_v2.team_stats_compare')
local math_random = math.random
local gui_style = require('utils.utils').gui_style

local Public = {}

local gui_values = {
    ['north'] = { color1 = { r = 0.55, g = 0.55, b = 0.99 } },
    ['south'] = { color1 = { r = 0.99, g = 0.33, b = 0.33 } },
}

local function shuffle(tbl)
    local size = #tbl
    for i = size, 1, -1 do
        local rand = math.random(size)
        tbl[i], tbl[rand] = tbl[rand], tbl[i]
    end
    return tbl
end

function Public.reveal_map()
    for _, f in pairs({ 'north', 'south', 'player', 'spectator' }) do
        local r = 768
        game.forces[f].chart(game.surfaces[storage.bb_surface_name], { { r * -1, r * -1 }, { r, r } })
    end
end

local function silo_kaboom(entity)
    local surface = entity.surface
    local center_position = entity.position
    local force = entity.force
    surface.create_entity({
        name = 'atomic-rocket',
        position = center_position,
        force = force,
        source = center_position,
        target = center_position,
        max_range = 1,
        speed = 0.1,
    })

    local drops = {}
    for x = -32, 32, 1 do
        for y = -32, 32, 1 do
            local p = { x = center_position.x + x, y = center_position.y + y }
            local distance_to_silo = math.sqrt((center_position.x - p.x) ^ 2 + (center_position.y - p.y) ^ 2)
            local count = math.floor((32 - distance_to_silo * 1.2) * 0.28)
            if distance_to_silo < 32 and count > 0 then
                table.insert(drops, { p, count })
            end
        end
    end
    for _, drop in pairs(drops) do
        for _ = 1, drop[2], 1 do
            entity.surface.spill_item_stack({
                position = { drop[1].x + math.random(0, 9) * 0.1, drop[1].y + math.random(0, 9) * 0.1 },
                stack = { name = 'raw-fish', count = 1 },
                enable_looted = false,
                force = nil,
                allow_belts = true,
            })
        end
    end
end

local function get_sorted_list(column_name, score_list)
    for _ = 1, #score_list, 1 do
        for y = 1, #score_list, 1 do
            if not score_list[y + 1] then
                break
            end
            if score_list[y][column_name] < score_list[y + 1][column_name] then
                local key = score_list[y]
                score_list[y] = score_list[y + 1]
                score_list[y + 1] = key
            end
        end
    end
    return score_list
end

local function get_mvps(force)
    local get_score = Score.get_table().score_table
    if not get_score[force] then
        return false
    end
    local score = get_score[force]
    local score_list = {}
    for _, p in pairs(game.players) do
        if score.players[p.name] then
            local killscore = 0
            if score.players[p.name].killscore then
                killscore = score.players[p.name].killscore
            end
            local deaths = 0
            if score.players[p.name].deaths then
                deaths = score.players[p.name].deaths
            end
            local built_entities = 0
            if score.players[p.name].built_entities then
                built_entities = score.players[p.name].built_entities
            end
            local mined_entities = 0
            if score.players[p.name].mined_entities then
                mined_entities = score.players[p.name].mined_entities
            end
            table.insert(score_list, {
                name = p.name,
                killscore = killscore,
                deaths = deaths,
                built_entities = built_entities,
                mined_entities = mined_entities,
            })
        end
    end
    local mvp = {}
    score_list = get_sorted_list('killscore', score_list)
    mvp.killscore = { name = score_list[1].name, score = score_list[1].killscore }
    score_list = get_sorted_list('deaths', score_list)
    mvp.deaths = { name = score_list[1].name, score = score_list[1].deaths }
    score_list = get_sorted_list('built_entities', score_list)
    mvp.built_entities = { name = score_list[1].name, score = score_list[1].built_entities }
    return mvp
end

local function show_endgame_gui(player)
    local get_score = Score.get_table().score_table
    if not get_score then
        return
    end
    if Gui.get_left_element(player, 'mvps') then
        return
    end
    local category_style = { font = 'default-listbox', font_color = { r = 0.22, g = 0.77, b = 0.44 } }
    local winner_style = { font = 'default-bold', font_color = { r = 0.33, g = 0.66, b = 0.9 } }

    local main_frame = Gui.add_left_element(player, { type = 'frame', name = 'mvps', direction = 'vertical' })
    local flow = main_frame.add({ type = 'flow', style = 'vertical_flow', direction = 'vertical' })
    local inner_frame = flow.add({ type = 'frame', style = 'inside_shallow_frame_packed', direction = 'vertical' })

    do -- Game overview
        local subheader = inner_frame.add({ type = 'frame', style = 'subheader_frame' })
        gui_style(subheader, {
            horizontally_squashable = true,
            use_header_filler = true,
            vertically_stretchable = true,
            minimal_height = 36,
            maximal_height = 180,
        })

        local icon = subheader.add({
            type = 'sprite-button',
            sprite = 'utility/side_menu_achievements_icon',
            style = 'transparent_slot',
        })
        Gui.add_pusher(subheader)

        local label =
            subheader.add({ type = 'label', caption = Functions.team_name(storage.bb_game_won_by_team) .. ' won!' })
        gui_style(
            label,
            { font = 'heading-2', font_color = { 165, 165, 165 }, single_line = false, maximal_width = 280, margin = 4 }
        )

        Gui.add_pusher(subheader)
        local icon = subheader.add({
            type = 'sprite-button',
            sprite = 'utility/side_menu_achievements_icon',
            style = 'transparent_slot',
        })

        local sp =
            inner_frame.add({ type = 'scroll-pane', style = 'scroll_pane_under_subheader', direction = 'vertical' })

        local l = sp.add({ type = 'label', style = 'caption_label', caption = storage.victory_time })
        gui_style(l, { left_padding = 8 })

        local l = sp.add({
            type = 'label',
            style = 'caption_label',
            caption = 'Total players - ' .. table_size(storage.chosen_team),
        })
        gui_style(l, { left_padding = 8 })
    end

    do -- MVPs
        local subheader = inner_frame.add({ type = 'frame', style = 'subheader_frame' })
        gui_style(subheader, { horizontally_squashable = true, maximal_height = 40, use_header_filler = true })

        local icon =
            subheader.add({ type = 'sprite-button', sprite = 'utility/empty_armor_slot', style = 'transparent_slot' })
        Gui.add_pusher(subheader)

        local label = subheader.add({ type = 'label', caption = 'MVPs' })
        gui_style(label, { font = 'default-semibold', font_color = { 165, 165, 165 }, left_margin = 4 })

        Gui.add_pusher(subheader)
        local icon =
            subheader.add({ type = 'sprite-button', sprite = 'utility/empty_armor_slot', style = 'transparent_slot' })

        local sp =
            inner_frame.add({ type = 'scroll-pane', style = 'scroll_pane_under_subheader', direction = 'vertical' })

        -- North
        local mvp = get_mvps('north')
        if mvp then
            local f = sp.add({ type = 'frame', style = 'bordered_frame', direction = 'vertical', caption = 'North:' })
            gui_style(f, { font = 'default-listbox', font_color = { r = 0.55, g = 0.55, b = 0.99 } })

            local t = f.add({ type = 'table', column_count = 2 })

            local l = t.add({ type = 'label', caption = 'Defender >> ' })
            gui_style(l, category_style)

            local l =
                t.add({ type = 'label', caption = mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score })
            gui_style(l, winner_style)

            local l = t.add({ type = 'label', caption = 'Builder >> ' })
            gui_style(l, category_style)

            local l = t.add({
                type = 'label',
                caption = mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things',
            })
            gui_style(l, winner_style)

            local l = t.add({ type = 'label', caption = 'Deaths >> ' })
            gui_style(l, category_style)

            local l = t.add({ type = 'label', caption = mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times' })
            gui_style(l, winner_style)

            if not storage.results_sent_north then
                local result = {}
                table.insert(result, 'NORTH: \\n')
                table.insert(result, 'MVP Defender: \\n')
                table.insert(result, mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score .. '\\n')
                table.insert(result, '\\n')
                table.insert(result, 'MVP Builder: \\n')
                table.insert(result, mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things\\n')
                table.insert(result, '\\n')
                table.insert(result, 'MVP Deaths: \\n')
                table.insert(result, mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times')
                local message = table.concat(result)
                Server.to_discord_embed(message)
                storage.results_sent_north = true
            end
        end

        -- South
        mvp = get_mvps('south')
        if mvp then
            local f = sp.add({ type = 'frame', style = 'bordered_frame', direction = 'vertical', caption = 'South:' })
            gui_style(f, { font = 'default-listbox', font_color = { r = 0.99, g = 0.33, b = 0.33 } })

            local t = f.add({ type = 'table', column_count = 2 })

            local l = t.add({ type = 'label', caption = 'Defender >> ' })
            gui_style(l, category_style)

            local l =
                t.add({ type = 'label', caption = mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score })
            gui_style(l, winner_style)

            local l = t.add({ type = 'label', caption = 'Builder >> ' })
            gui_style(l, category_style)

            local l = t.add({
                type = 'label',
                caption = mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things',
            })
            gui_style(l, winner_style)

            local l = t.add({ type = 'label', caption = 'Deaths >> ' })
            gui_style(l, category_style)

            local l = t.add({ type = 'label', caption = mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times' })
            gui_style(l, winner_style)

            if not storage.results_sent_south then
                local result = {}
                table.insert(result, 'SOUTH: \\n')
                table.insert(result, 'MVP Defender: \\n')
                table.insert(result, mvp.killscore.name .. ' with a score of ' .. mvp.killscore.score .. '\\n')
                table.insert(result, '\\n')
                table.insert(result, 'MVP Builder: \\n')
                table.insert(result, mvp.built_entities.name .. ' built ' .. mvp.built_entities.score .. ' things\\n')
                table.insert(result, '\\n')
                table.insert(result, 'MVP Deaths: \\n')
                table.insert(result, mvp.deaths.name .. ' died ' .. mvp.deaths.score .. ' times')
                local message = table.concat(result)
                Server.to_discord_embed(message)
                storage.results_sent_south = true
            end
        end
    end
end

local enemy_team_of = { ['north'] = 'south', ['south'] = 'north' }

function Public.server_restart()
    if not storage.server_restart_timer then
        return
    end
    storage.server_restart_timer = storage.server_restart_timer - 5

    if storage.server_restart_timer <= 0 then
        if storage.restart then
            if not storage.announced_message then
                local message = 'Soft-reset is disabled! Server will restart from scenario to load new changes.'
                game.print(message, { color = { r = 0.22, g = 0.88, b = 0.22 } })
                Server.to_discord_bold(table.concat({ '*** ', message, ' ***' }))
                Server.start_scenario('Biter_Battles')
                storage.announced_message = true
                return
            end
        end
        if storage.shutdown then
            if not storage.announced_message then
                local message = 'Soft-reset is disabled! Server will shutdown. Most likely because of updates.'
                game.print(message, { color = { r = 0.22, g = 0.88, b = 0.22 } })
                Server.to_discord_bold(table.concat({ '*** ', message, ' ***' }))
                Server.stop_scenario()
                storage.announced_message = true
                return
            end
        end
        game.print('Map is restarting!', { color = { r = 0.22, g = 0.88, b = 0.22 } })
        local message = 'Map is restarting! '
        Server.to_discord_bold(table.concat({ '*** ', message, ' ***' }))

        Public.generate_new_map()
        return
    end
    if storage.server_restart_timer % 30 == 0 then
        game.print(
            'Map will restart in ' .. storage.server_restart_timer .. ' seconds!',
            { color = { r = 0.22, g = 0.88, b = 0.22 } }
        )
        if storage.server_restart_timer / 30 == 1 then
            game.print('Good luck with your next match!', { color = { r = 0.98, g = 0.66, b = 0.22 } })
        end
    end
end

local function set_victory_time()
    local tick = Functions.get_ticks_since_game_start()
    local minutes = tick % 216000
    local hours = tick - minutes
    minutes = math.floor(minutes / 3600)
    hours = math.floor(hours / 216000)
    storage.victory_time =
        table.concat({ 'Time - ', hours > 0 and (hours .. ' hours and ') or '', minutes, ' minutes' })
end

local function freeze_all_biters(surface)
    for _, e in pairs(surface.find_entities_filtered({ force = 'north_biters' })) do
        e.active = false
    end
    for _, e in pairs(surface.find_entities_filtered({ force = 'south_biters' })) do
        e.active = false
    end
    for _, e in pairs(surface.find_entities_filtered({ force = 'north_biters_boss' })) do
        e.active = false
    end
    for _, e in pairs(surface.find_entities_filtered({ force = 'south_biters_boss' })) do
        e.active = false
    end
end

local function biter_killed_the_silo(event)
    local force = event.force
    if force ~= nil then
        return string.find(event.force.name, '_biters')
    end

    local cause = event.cause
    if cause ~= nil then
        return (cause.valid and cause.type == 'unit')
    end

    log('Could not determine what destroyed the silo')
    return false
end

local function respawn_silo(event)
    local entity = event.entity
    local surface = entity.surface
    if surface == nil or not surface.valid then
        log('Surface ' .. storage.bb_surface_name .. ' invalid - cannot respawn silo')
        return
    end

    local force_name = entity.force.name
    -- Has to be created instead of clone otherwise it will be moved to south.
    entity = surface.create_entity({
        name = entity.name,
        position = entity.position,
        surface = surface,
        force = force_name,
        create_build_effect_smoke = false,
    })
    entity.minable_flag = false
    entity.health = 5
    storage.rocket_silo[force_name] = entity
    AiTargets.start_tracking(entity)
end

local function log_to_db(message, appendBool)
    helpers.write_file('logToDBgameResult', message, appendBool, 0)
end

function Public.silo_death(event)
    local entity = event.entity
    if not entity.valid then
        return
    end
    if entity.name ~= 'rocket-silo' then
        return
    end
    if storage.bb_game_won_by_team then
        return
    end
    if entity == storage.rocket_silo.south or entity == storage.rocket_silo.north then
        -- Respawn Silo in case of friendly fire
        if not biter_killed_the_silo(event) then
            respawn_silo(event)
            return
        end

        storage.bb_game_won_by_team = enemy_team_of[entity.force.name]

        set_victory_time()
        team_stats_compare.game_over()
        local north_players = 'NORTH PLAYERS: \\n'
        local south_players = 'SOUTH PLAYERS: \\n'

        for _, player in pairs(game.connected_players) do
            player.play_sound({ path = 'utility/game_won', volume_modifier = 1 })
            local main_frame = Gui.get_left_element(player, 'bb_main_gui')
            if main_frame then
                main_frame.visible = false
            end
            show_endgame_gui(player)
            if player.force.name == 'south' then
                south_players = south_players .. player.name .. '   '
            elseif player.force.name == 'north' then
                north_players = north_players .. player.name .. '   '
            end
        end

        storage.spy_fish_timeout.north = game.tick + 999999
        storage.spy_fish_timeout.south = game.tick + 999999
        storage.server_restart_timer = 150

        game.speed = 1

        local north_evo = math.floor(1000 * storage.bb_evolution['north_biters']) * 0.1
        local north_threat = math.floor(storage.bb_threat['north_biters'])
        local south_evo = math.floor(1000 * storage.bb_evolution['south_biters']) * 0.1
        local south_threat = math.floor(storage.bb_threat['south_biters'])

        local discord_message = table.concat({
            '*** Team ',
            storage.bb_game_won_by_team,
            ' has won! ***',
            '\\n',
            storage.victory_time,
            '\\n\\n',
            'North Evo: ',
            north_evo,
            '%\\n',
            'North Threat: ',
            north_threat,
            '\\n\\n',
            'South Evo: ',
            south_evo,
            '%\\n',
            'South Threat: ',
            south_threat,
            '\\n\\n',
            north_players,
            '\\n\\n',
            south_players,
        })

        Server.to_discord_embed(discord_message)
        log({ '', '[TEAMSTATS-FINAL]', helpers.table_to_json(storage.team_stats) })

        storage.results_sent_south = false
        storage.results_sent_north = false
        silo_kaboom(entity)

        freeze_all_biters(entity.surface)
        local special = storage.special_games_variables.captain_mode
        if special and not special.prepaPhase then
            storage.tournament_mode = false
            game.print('Tournament mode is now disabled')
            game.print('Updating logs for the game')
            if special.communityPickingMode then
                Server.send_special_game_state('[COMMUNITY-PICK]')
            else
                Server.send_special_game_state('[CAPTAIN-SPECIAL]')
            end
            log_to_db('>Game has ended\n', false)
            log_to_db('[RefereeName]' .. special.stats.InitialReferee .. '\n', true)
            if special.stats.NorthInitialCaptain then
                log_to_db('[CaptainNorth]' .. special.stats.NorthInitialCaptain .. '\n', true)
            end
            if special.stats.SouthInitialCaptain then
                log_to_db('[CaptainSouth]' .. special.stats.SouthInitialCaptain .. '\n', true)
            end
            local listPicks = table.concat(special.stats.northPicks, ';')
            log_to_db('[NorthTeam]' .. listPicks .. '\n', true)
            listPicks = table.concat(special.stats.southPicks, ';')
            log_to_db('[SouthTeam]' .. listPicks .. '\n', true)
            log_to_db('[Gamelength]' .. game.ticks_played .. '\n', true)
            log_to_db('[StartTick]' .. special.stats.tickGameStarting .. '\n', true)
            log_to_db('[WinnerTeam]' .. storage.bb_game_won_by_team .. '\n', true)
            log_to_db('[ExtraInfo]' .. special.stats.extrainfo .. '\n', true)
            log_to_db('[SpecialEnabled]' .. special.stats.specialEnabled .. '\n', true)
            log_to_db('[CommunityPickMode]' .. tostring(special.communityPickingMode) .. '\n', true)
            for _, player in pairs(game.players) do
                if player.connected and (player.force.name == 'north' or player.force.name == 'south') then
                    Captain_special.captain_log_end_time_player(player)
                end
                if special.stats.playerPlaytimes[player.name] ~= nil then
                    log_to_db(
                        '[Playtime][' .. player.name .. ']' .. special.stats.playerPlaytimes[player.name] .. '\n',
                        true
                    )
                end
            end
            if special.stats.communityPickInfo then
                log_to_db('[CommunityPickInfo]' .. helpers.table_to_json(special.stats.communityPickInfo) .. '\n', true)
            end
            log_to_db('[TeamStats]' .. helpers.table_to_json(storage.team_stats) .. '\n', true)
            log_to_db('>End of log', true)
        end
    end
end

local function chat_with_everyone(event)
    if not storage.server_restart_timer then
        return
    end
    if not event.message then
        return
    end
    if not event.player_index then
        return
    end
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    local enemy = Tables.enemy_team_of[player.force.name]
    if not enemy then
        return
    end
    local message = player.name .. '[auto-shout]: ' .. event.message
    game.forces[enemy].print(message, { color = player.chat_color })
end

---@return number, number, number #success percent[0-1], yes count, no count
local function get_reroll_stats()
    local total_votes = table.size(storage.reroll_map_voting)
    if total_votes == 0 then
        return 0, 0, 0
    end

    local yes_votes = 0
    for _, vote in pairs(storage.reroll_map_voting) do
        yes_votes = yes_votes + vote
    end
    return math.floor(100 * yes_votes / total_votes), yes_votes, total_votes - yes_votes
end

local function draw_reroll_gui(player)
    if Gui.get_top_element(player, 'reroll_frame') then
        return
    end

    local frame = Gui.add_top_element(player, { type = 'frame', name = 'reroll_frame', style = 'subheader_frame' })
    gui_style(frame, { minimal_height = 36, maximal_height = 36, padding = 0, vertical_align = 'center' })

    local f = frame.add({ type = 'flow', name = 'flow', direction = 'horizontal' })
    local line = f.add({ type = 'line', direction = 'vertical' })

    do -- buttons
        local t = f.add({ type = 'table', name = 'reroll_table', column_count = 3, vertical_centering = true })
        gui_style(t, { top_margin = 2, left_margin = 8, right_margin = 8 })

        local l = t.add({ type = 'label', caption = { 'gui.reroll_caption', storage.reroll_time_left } })
        gui_style(l, {
            font = 'heading-2',
            font_color = { r = 0.88, g = 0.55, b = 0.11 },
            minimal_width = 120,
            maximal_width = 120,
            right_padding = 2,
        })

        local b = t.add({ type = 'button', caption = 'No', name = 'reroll_no', style = 'red_back_button' })
        gui_style(b, { minimal_width = 56, maximal_width = 56, font = 'heading-2' })

        local b =
            t.add({ type = 'button', caption = 'Yes', name = 'reroll_yes', style = 'confirm_button_without_tooltip' })
        gui_style(b, { minimal_width = 56, maximal_width = 56, font = 'heading-2' })
    end

    local line = f.add({ type = 'line', direction = 'vertical' })

    do -- stats
        local percent, yes_votes, no_votes = get_reroll_stats()

        local l = f.add({
            type = 'label',
            name = 'reroll_stats',
            caption = { 'gui.reroll_stats', no_votes, yes_votes, percent },
        })
        gui_style(
            l,
            { font = 'heading-2', right_padding = 4, left_padding = 4, top_margin = 6, font_color = { 165, 165, 165 } }
        )
    end
end

---@return number, number, number #success percent[0-1], yes count, no count
local function get_automatic_captain_stats()
    local total_votes = table.size(storage.automatic_captain_voting)
    if total_votes == 0 then
        return 0, 0, 0
    end

    local yes_votes = 0
    for _, vote in pairs(storage.automatic_captain_voting) do
        yes_votes = yes_votes + vote
    end
    return math.floor(100 * yes_votes / total_votes), yes_votes, total_votes - yes_votes
end

local function draw_automatic_captain_poll_gui(player)
    if Gui.get_top_element(player, 'automatic_captain_poll_frame') then
        return
    end

    local frame = Gui.add_top_element(
        player,
        { type = 'frame', name = 'automatic_captain_poll_frame', style = 'subheader_frame' }
    )
    gui_style(frame, { minimal_height = 36, maximal_height = 36, padding = 0, vertical_align = 'center' })

    local f = frame.add({ type = 'flow', name = 'flow', direction = 'horizontal' })
    local line = f.add({ type = 'line', direction = 'vertical' })

    do -- buttons
        local t =
            f.add({ type = 'table', name = 'automatic_captain_table', column_count = 3, vertical_centering = true })
        gui_style(t, { top_margin = 2, left_margin = 8, right_margin = 8 })

        local l = t.add({
            type = 'label',
            caption = { 'gui.automatic_captain_caption', storage.automatic_captain_time_left },
        })
        gui_style(l, {
            font = 'heading-2',
            font_color = { r = 0.88, g = 0.55, b = 0.11 },
            minimal_width = 120,
            maximal_width = 120,
            right_padding = 2,
        })

        local b = t.add({ type = 'button', caption = 'No', name = 'automatic_captain_no', style = 'red_back_button' })
        gui_style(b, { minimal_width = 56, maximal_width = 56, font = 'heading-2' })

        local b = t.add({
            type = 'button',
            caption = 'Yes',
            name = 'automatic_captain_yes',
            style = 'confirm_button_without_tooltip',
        })
        gui_style(b, { minimal_width = 56, maximal_width = 56, font = 'heading-2' })
    end

    local line = f.add({ type = 'line', direction = 'vertical' })

    do -- stats
        local percent, yes_votes, no_votes = get_automatic_captain_stats()

        local l = f.add({
            type = 'label',
            name = 'automatic_captain_stats',
            caption = { 'gui.automatic_captain_stats', no_votes, yes_votes, percent },
        })
        gui_style(
            l,
            { font = 'heading-2', right_padding = 4, left_padding = 4, top_margin = 6, font_color = { 165, 165, 165 } }
        )
    end
end

local function stop_automatic_captain()
    storage.automatic_captain_time_left = 0
    -- remove existing buttons
    for _, player in pairs(game.players) do
        local frame = Gui.get_top_element(player, 'automatic_captain_poll_frame')
        if frame then
            frame.destroy()
        end
    end
end

local decrement_timer_automatic_captain_token = Token.get_counter() + 1 -- predict what the token will look like
decrement_timer_automatic_captain_token = Token.register(function()
    if not storage.bb_settings.automatic_captain then
        stop_automatic_captain()
        return
    end

    storage.automatic_captain_time_left = storage.automatic_captain_time_left - 1
    if storage.automatic_captain_time_left > 0 then
        for _, player in pairs(game.connected_players) do
            local frame = Gui.get_top_element(player, 'automatic_captain_poll_frame')
            if frame and frame.valid then
                frame.flow.automatic_captain_table.children[1].caption =
                    { 'gui.automatic_captain_caption', storage.automatic_captain_time_left }
                local percent, yes_votes, no_votes = get_automatic_captain_stats()
                frame.flow.automatic_captain_stats.caption =
                    { 'gui.automatic_captain_stats', no_votes, yes_votes, percent }
            end
        end

        Sounds.notify_all('utility/armor_insert')
        Task.set_timeout_in_ticks(60, decrement_timer_automatic_captain_token)
    else
        stop_automatic_captain()
        -- count votes
        local result, yes_votes, _ = get_automatic_captain_stats()
        local amountVotesRequired = 13
        local percentRequired = 66
        if result >= percentRequired and yes_votes > amountVotesRequired then
            game.print('Vote to start captain event has succeeded (' .. result .. '%)')
            Captain_special.generate_automatic_captain()
        else
            game.print('Vote to start captain event has failed (' .. result .. '%)')
            if yes_votes <= amountVotesRequired then
                game.print(
                    'At least '
                        .. amountVotesRequired
                        .. ' votes voting yes are required, there were only '
                        .. yes_votes
                        .. ' yes votes'
                )
            end
            if result < percentRequired then
                game.print('At least ' .. percentRequired .. '% of yes are required')
            end
            storage.tournament_mode = false
        end
    end
end)

local function start_auto_captain_vote()
    if
        storage.bb_settings.automatic_captain
        and #game.connected_players > storage.automatic_captain_min_connected_players_for_vote
    then
        game.print(
            'You can now vote to start or not a captain game, top of screen! You wont be able to play until the poll is over',
            { color = { r = 0.22, g = 0.88, b = 0.22 } }
        )
        storage.tournament_mode = true
        storage.automatic_captain_time_left = storage.automatic_captain_time_limit / 60
        Task.set_timeout_in_ticks(60, decrement_timer_automatic_captain_token)
        for _, player in pairs(game.connected_players) do
            draw_automatic_captain_poll_gui(player)
        end
        Sounds.notify_all('utility/scenario_message')
    end
end

local reroll_buttons_token = Token.register(
    -- create buttons for joining players
    function(event)
        local player = game.get_player(event.player_index)
        draw_reroll_gui(player)
    end
)

local function stop_map_reroll()
    storage.reroll_time_left = 0
    -- disable reroll buttons creation for joining players
    Event.remove_removable(defines.events.on_player_joined_game, reroll_buttons_token)
    -- remove existing buttons
    for _, player in pairs(game.players) do
        local frame = Gui.get_top_element(player, 'reroll_frame')
        if frame then
            frame.destroy()
        end
    end
end

local decrement_timer_token = Token.get_counter() + 1 -- predict what the token will look like
decrement_timer_token = Token.register(function()
    if not storage.bb_settings.map_reroll then
        stop_map_reroll()
        return
    end

    storage.reroll_time_left = storage.reroll_time_left - 1
    if storage.reroll_time_left > 0 then
        for _, player in pairs(game.connected_players) do
            local frame = Gui.get_top_element(player, 'reroll_frame')
            if frame and frame.valid then
                frame.flow.reroll_table.children[1].caption = { 'gui.reroll_caption', storage.reroll_time_left }

                local percent, yes_votes, no_votes = get_reroll_stats()
                frame.flow.reroll_stats.caption = { 'gui.reroll_stats', no_votes, yes_votes, percent }
            end
        end

        Sounds.notify_all('utility/armor_insert')
        Task.set_timeout_in_ticks(60, decrement_timer_token)
    else
        stop_map_reroll()
        -- count votes
        local result, _, _ = get_reroll_stats()
        if result >= 66 then
            game.print('Vote to reload the map has succeeded (' .. result .. '%)')
            game.print('Map is being rerolled!', { color = { r = 0.22, g = 0.88, b = 0.22 } })
            Public.generate_new_map()
        else
            game.print('Vote to reload the map has failed (' .. result .. '%)')
            start_auto_captain_vote()
        end
    end
end)

local function start_map_reroll()
    if storage.bb_settings.map_reroll then
        if not storage.reroll_time_left or storage.reroll_time_left <= 0 then
            Task.set_timeout_in_ticks(60, decrement_timer_token)
            Event.add_removable(defines.events.on_player_joined_game, reroll_buttons_token)
        end
        storage.reroll_time_left = storage.reroll_time_limit / 60
        for _, player in pairs(game.connected_players) do
            draw_reroll_gui(player)
        end
        Sounds.notify_all('utility/scenario_message')
    end
end

function Public.generate_new_map()
    game.speed = 1
    local prev_surface = storage.bb_surface_name
    Special_games.reset_special_games()
    Init.tables()
    Init.playground_surface()
    Init.forces()
    Init.draw_structures()
    BBGui.reset_tables_gui()
    Init.queue_reveal_map()
    for _, player in pairs(game.players) do
        Functions.init_player(player)
        for _, e in pairs(player.gui.left.children) do
            e.destroy()
        end
        local suspend_frame = Gui.get_top_element(player, 'suspend_frame')
        if suspend_frame then
            suspend_frame.destroy()
        end
        BBGui.create_main_gui(player)
        BBGui.refresh_feature_flags(player)
    end
    game.reset_time_played()
    storage.server_restart_timer = nil
    game.delete_surface(prev_surface)
    start_map_reroll()
end

function Public.automatic_captain_draw_buttons(event)
    if not storage.bb_settings.automatic_captain then
        return
    end

    if storage.automatic_captain_time_left > 0 then
        local player = game.get_player(event.player_index)
        draw_automatic_captain_poll_gui(player)
    end
end

Event.add(defines.events.on_console_chat, chat_with_everyone)
Event.add(defines.events.on_player_joined_game, Public.automatic_captain_draw_buttons)
return Public
