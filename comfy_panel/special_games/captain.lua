local CaptainCommunityPick = require('comfy_panel.special_games.captain_community_pick')
local CaptainTaskGroup = require('comfy_panel.special_games.captain_task_group')
local CaptainUtils = require('comfy_panel.special_games.captain_utils')
local ClosableFrame = require('utils.ui.closable_frame')
local Color = require('utils.color_presets')
local ComfyPanelGroup = require('comfy_panel.group')
local DifficultyVote = require('maps.biter_battles_v2.difficulty_vote')
local Event = require('utils.event')
local Functions = require('maps.biter_battles_v2.functions')
local Gui = require('utils.gui')
local PlayerList = require('comfy_panel.player_list')
local PlayerUtils = require('utils.player')
local Session = require('utils.datastore.session_data')
local Tables = require('maps.biter_battles_v2.tables')
local Task = require('utils.task')
local TeamManager = require('maps.biter_battles_v2.team_manager')
local Token = require('utils.token')
local safe_wrap_cmd = require('utils.utils').safe_wrap_cmd

local gui_style = require('utils.utils').gui_style
local frame_style = require('utils.utils').left_frame_style
local ternary = require('utils.utils').ternary
local pretty_print_player_list = CaptainUtils.pretty_print_player_list
local cpt_get_player = CaptainUtils.cpt_get_player
local table_contains = CaptainUtils.table_contains
local insert, remove, concat, sort = table.insert, table.remove, table.concat, table.sort
local math_floor = math.floor
local math_random = math.random
local string_find = string.find
local string_format = string.format
local string_sub = string.sub

local Public = {
    name = { type = 'label', caption = 'Captain event', tooltip = 'Captain event' },
    config = {
        { name = 'label4', type = 'label', caption = 'Referee' },
        { name = 'refereeName', type = 'textfield', text = '', numeric = false, width = 140 },
        {
            name = 'autoTrust',
            type = 'switch',
            switch_state = 'right',
            allow_none_state = false,
            tooltip = 'Trust all players automatically : Yes / No',
        },
        {
            name = 'captainKickPower',
            type = 'switch',
            switch_state = 'left',
            allow_none_state = false,
            tooltip = 'Captain can eject players from his team : Yes / No',
        },
        {
            name = 'specialEnabled',
            type = 'switch',
            switch_state = 'right',
            allow_none_state = false,
            tooltip = 'A special will be added to the event : Yes / No',
        },
    },
    button = { name = 'apply', type = 'button', caption = 'Apply' },
}
global.captain_ui = global.captain_ui or {}

local tournament_pages = {
    {
        name = 'captain_join_info',
        sprite = 'utility/custom_tag_icon',
        caption = 'Event info',
        tooltip = 'Toggle introductory window to captains event',
    },
    {
        name = 'captain_player_gui',
        sprite = 'entity/big-biter',
        caption = 'Join captain event',
        tooltip = 'Toggle join window for captain event',
    },
    {
        name = 'captain_referee_gui',
        sprite = 'achievement/lazy-bastard',
        caption = 'Referee',
        tooltip = 'Toggle the referee window',
    },
    {
        name = 'captain_manager_gui',
        sprite = 'utility/hand',
        caption = 'Team Permissions',
        tooltip = "Toggle the captain's team manager window",
    },
    {
        name = 'captain_organization_gui',
        sprite = 'utility/slot_icon_robot_material',
        caption = 'Team Organization',
        tooltip = 'Toggle your team organization window',
    },
}

-- == UTILS ===================================================================
local function is_test_player(player)
    return not player.gui
end

local function is_test_player_name(player_name)
    local special = global.special_games_variables.captain_mode
    return special.test_players and special.test_players[player_name]
end

local function table_contains(tab, str)
    for _, entry in ipairs(tab) do
        if entry == str then
            return true
        end
    end
    return false
end

local function table_remove_element(tab, str)
    for i, entry in ipairs(tab) do
        if entry == str then
            remove(tab, i)
            break -- Stop the loop once the string is found and removed
        end
    end
end

local function add_to_trust(playerName)
    if global.special_games_variables.captain_mode.autoTrust then
        local trusted = Session.get_trusted_table()
        if not trusted[playerName] then
            trusted[playerName] = true
        end
    end
end

local function switch_team_of_player(playerName, playerForceName)
    if global.chosen_team[playerName] then
        if global.chosen_team[playerName] ~= playerForceName then
            game.print(
                { 'captain.change_player_team_err', playerName, global.chosen_team[playerName], playerForceName },
                Color.red
            )
        end
        return
    end
    local special = global.special_games_variables.captain_mode
    local player = cpt_get_player(playerName)
    if is_test_player_name(playerName) or not player.connected then
        global.chosen_team[playerName] = playerForceName
    else
        TeamManager.switch_force(playerName, playerForceName)
    end
    local forcePickName = playerForceName .. 'Picks'
    insert(special.stats[forcePickName], playerName)
    if not special.playerPickedAtTicks[playerName] then
        special.playerPickedAtTicks[playerName] = Functions.get_ticks_since_game_start()
    end
    add_to_trust(playerName)
end

local function clear_gui_captain_mode()
    for _, player in pairs(game.players) do
        local gui = player.gui
        local screen = gui.screen
        for _, element in pairs({
            Gui.get_top_element(player, 'captain_tournament_button'),
            Gui.get_left_element(player, 'captain_tournament_gui'),
            gui.center.bb_captain_countdown,
            screen.captain_join_info,
            screen.captain_player_gui,
            screen.captain_referee_gui,
            screen.captain_manager_gui,
            screen.captain_organization_gui,
            screen.captain_poll_alternate_pick_choice_frame,
        }) do
            if element then
                element.destroy()
            end
        end
        global.captain_ui[player.name] = {}
    end
end

local function clear_character_corpses()
    for _, object in pairs(game.surfaces[global.bb_surface_name].find_entities_filtered({ name = 'character-corpse' })) do
        object.destroy()
    end
end

local function force_end_captain_event()
    game.print('Captain event was canceled')
    global.special_games_variables.captain_mode = nil
    global.tournament_mode = false
    if global.freeze_players == true then
        global.freeze_players = false
        TeamManager.unfreeze_players()
        game.print('>>> Players have been unfrozen!', { r = 255, g = 77, b = 77 })
    end
    global.active_special_games.captain_mode = false
    global.bb_threat.north_biters = 0
    global.bb_threat.south_biters = 0
    rendering.clear()
    clear_gui_captain_mode()
    for _, pl in pairs(game.connected_players) do
        if pl.force.name ~= 'spectator' then
            TeamManager.switch_force(pl.name, 'spectator')
        end
    end
    global.difficulty_votes_timeout = game.ticks_played + 36000
    clear_character_corpses()
end

local function starts_with(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function pick_player_generator(player, tableBeingLooped, name, caption, button1Text, button1Name, location)
    if player.gui.screen[name] then
        player.gui.screen[name].destroy()
        return
    end

    ---@param parent LuaGuiElement
    local function create_button(parent, name, caption, wordToPutInstead)
        local button = parent.add({
            type = 'button',
            name = name:gsub('Magical1@StringHere', wordToPutInstead),
            caption = caption:gsub('Magical1@StringHere', wordToPutInstead),
            style = 'green_button',
            tooltip = 'Click to select',
        })
        gui_style(button, { font = 'default-bold', height = 24, minimal_width = 100, horizontally_stretchable = true })
    end

    local function make_table_row(parent, button_name, button_1_text, player_name, group_name, play_time)
        local special = global.special_games_variables.captain_mode

        local l
        create_button(parent, button_name, button_1_text, player_name)

        l = parent.add({ type = 'label', caption = group_name, style = 'valid_mod_label' })
        gui_style(l, { minimal_width = 100, font_color = Color.antique_white })

        l = parent.add({ type = 'label', caption = play_time, style = 'valid_mod_label' })
        gui_style(l, { minimal_width = 100 })

        l = parent.add({ type = 'label', caption = special.player_info[player_name] or '', style = 'valid_mod_label' })
        gui_style(l, { minimal_width = 100, single_line = false, maximal_width = 300 })
    end

    local frame = player.gui.screen.add({ type = 'frame', name = name, direction = 'vertical' })
    gui_style(frame, { maximal_width = 900, maximal_height = 800 })
    if location then
        frame.location = location
    else
        frame.auto_center = true
    end

    do -- title
        local flow = frame.add({ type = 'flow', direction = 'horizontal' })
        gui_style(flow, { horizontal_spacing = 8, bottom_padding = 4 })

        local title = flow.add({ type = 'label', caption = caption, style = 'frame_title' })
        title.drag_target = frame

        local dragger = flow.add({ type = 'empty-widget', style = 'draggable_space_header' })
        dragger.drag_target = frame
        gui_style(dragger, { height = 24, horizontally_stretchable = true })
    end

    do -- pick table
        local flow = frame.add({ type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' })
        local inner_frame = flow.add({
            type = 'frame',
            name = 'inner_frame',
            style = 'a_inner_paddingless_frame',
            direction = 'vertical',
        })
        local sp = inner_frame.add({
            type = 'scroll-pane',
            name = 'scroll_pane',
            style = 'scroll_pane_under_subheader',
            direction = 'vertical',
        })
        gui_style(sp, { horizontally_squashable = false, padding = 0 })
        local t = sp.add({ type = 'table', column_count = 4, style = 'mods_table' })
        if tableBeingLooped ~= nil then
            local label_style = {
                font_color = Color.antique_white,
                font = 'heading-2',
                minimal_width = 100,
                top_margin = 4,
                bottom_margin = 4,
            }
            local l = t.add({ type = 'label', caption = 'Player' })
            gui_style(l, label_style)

            l = t.add({ type = 'label', caption = 'Group' })
            gui_style(l, label_style)

            l = t.add({ type = 'label', caption = 'Total playtime' })
            gui_style(l, label_style)

            l = t.add({ type = 'label', caption = 'Notes' })
            gui_style(l, label_style)

            local listGroupAlreadyDone = {}
            for _, pl in pairs(tableBeingLooped) do
                if button1Text ~= nil then
                    local groupCaptionText = ''
                    local groupName = ''
                    local playerIterated = cpt_get_player(pl)
                    local playtimePlayer = '0 minutes'
                    if global.total_time_online_players[playerIterated.name] then
                        playtimePlayer = PlayerList.get_formatted_playtime_from_ticks(
                            global.total_time_online_players[playerIterated.name]
                        )
                    end
                    if
                        starts_with(playerIterated.tag, ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX)
                    then
                        if not listGroupAlreadyDone[playerIterated.tag] then
                            groupName = playerIterated.tag
                            listGroupAlreadyDone[playerIterated.tag] = true
                            make_table_row(t, button1Name, button1Text, pl, groupName, playtimePlayer)
                            for _, plOfGroup in pairs(tableBeingLooped) do
                                if plOfGroup ~= pl then
                                    local groupNameOtherPlayer = cpt_get_player(plOfGroup).tag
                                    if groupNameOtherPlayer ~= '' and groupName == groupNameOtherPlayer then
                                        playtimePlayer = '0 minutes'
                                        local nameOtherPlayer = cpt_get_player(plOfGroup).name
                                        if global.total_time_online_players[nameOtherPlayer] then
                                            playtimePlayer = PlayerList.get_formatted_playtime_from_ticks(
                                                global.total_time_online_players[nameOtherPlayer]
                                            )
                                        end
                                        make_table_row(
                                            t,
                                            button1Name,
                                            button1Text,
                                            plOfGroup,
                                            groupName,
                                            playtimePlayer
                                        )
                                    end
                                end
                            end
                        end
                    else
                        make_table_row(t, button1Name, button1Text, pl, groupName, playtimePlayer)
                    end
                end
            end
        end
    end
end

local function poll_alternate_picking(player, location)
    pick_player_generator(
        player,
        global.special_games_variables.captain_mode.listPlayers,
        'captain_poll_alternate_pick_choice_frame',
        'Who do you want to pick ?',
        'Magical1@StringHere',
        'captain_player_picked_Magical1@StringHere',
        location
    )
end

local function render_text(textId, textChosen, targetPos, color, scaleChosen, fontChosen)
    global.special_games_variables.rendering[textId] = rendering.draw_text({
        text = textChosen,
        surface = game.surfaces[global.bb_surface_name],
        target = targetPos,
        color = color,
        scale = scaleChosen,
        font = fontChosen,
        alignment = 'center',
        scale_with_zoom = false,
    })
end

local function generate_generic_rendering_captain()
    local y = -14
    render_text('captainLineOne', 'Special event rule only : ', { -65, y }, { 1, 1, 1, 1 }, 3, 'heading-1')
    y = y + 2
    render_text(
        'captainLineTwo',
        '-Use of /nth /sth /north-chat /south-chat /s /shout by spectator can be punished (warn-tempban event)',
        { -65, y },
        Color.captain_versus_float,
        3,
        'heading-1'
    )
    y = y + 4
    render_text('captainLineThree', 'Notes: ', { -65, y }, { 1, 1, 1, 1 }, 2.5, 'heading-1')
    y = y + 2
    render_text(
        'captainLineFour',
        '-Chat of spectator can only be seen by spectators for players',
        { -65, y },
        { 1, 1, 1, 1 },
        2.5,
        'heading-1'
    )
    y = y + 2
    render_text(
        'captainLineSix',
        '-Teams are locked, if you want to play, click "Join captain event" in your Tournament menu',
        { -65, y },
        { 1, 1, 1, 1 },
        2.5,
        'heading-1'
    )
    y = y + 2
    render_text(
        'captainLineSeven',
        '-We are using discord bb for comms (not required), feel free to join to listen, even if no mic',
        { -65, y },
        { 1, 1, 1, 1 },
        2.5,
        'heading-1'
    )
    y = y + 2
    render_text(
        'captainLineEight',
        '-If you are not playing, you can listen to any team, but your mic must be off',
        { -65, y },
        { 1, 1, 1, 1 },
        2.5,
        'heading-1'
    )
    y = y + 2
    render_text(
        'captainLineNine',
        '-No sign up required, anyone can play the event!',
        { -65, y },
        { 1, 1, 1, 1 },
        2.5,
        'heading-1'
    )
    y = y + 2
end

local function auto_pick_all_of_group(cptPlayer, playerName)
    local special = global.special_games_variables.captain_mode
    if special.captainGroupAllowed and not special.initialPickingPhaseFinished then
        local playerChecked = cpt_get_player(playerName)
        local amountPlayersSwitchedForGroup = 0
        local playersToSwitch = {}
        for _, playerName in ipairs(special.listPlayers) do
            local player = cpt_get_player(playerName)
            if
                global.chosen_team[playerName] == nil
                and player.tag == playerChecked.tag
                and player.force.name == 'spectator'
            then -- only pick player without a team within the same group
                if amountPlayersSwitchedForGroup < special.groupLimit - 1 then
                    insert(playersToSwitch, playerName)
                    amountPlayersSwitchedForGroup = amountPlayersSwitchedForGroup + 1
                else
                    game.print(
                        playerName .. ' was not picked automatically with group system, as the group limit was reached',
                        Color.red
                    )
                end
            end
        end
        for _, playerName in ipairs(playersToSwitch) do
            local player = cpt_get_player(playerName)
            game.print(playerName .. ' was automatically picked with group system', Color.cyan)
            switch_team_of_player(playerName, playerChecked.force.name)
            player.print({ 'captain.comms_reminder' }, Color.cyan)
            table_remove_element(special.listPlayers, playerName)
        end
    end
end

---@param playerName string
---@return boolean
local function is_player_in_group_system(playerName)
    -- function used to balance team when a team is picked
    if global.special_games_variables.captain_mode.captainGroupAllowed then
        local playerChecked = cpt_get_player(playerName)
        if
            playerChecked
            and playerChecked.tag ~= ''
            and starts_with(playerChecked.tag, ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PLAYER_TAG_PREFIX)
        then
            return true
        end
    end
    return false
end

---@param playerNames string[]
---@return table<string, string[]>
local function generate_groups(playerNames)
    local special = global.special_games_variables.captain_mode
    local groups = {}
    for _, playerName in pairs(playerNames) do
        if is_player_in_group_system(playerName) then
            local player = cpt_get_player(playerName)
            if player then
                local groupName = player.tag
                local group = groups[groupName]
                if not group then
                    group = {}
                    groups[groupName] = group
                end
                local group_size = 0
                for _ in pairs(group) do
                    group_size = group_size + 1
                end
                if group_size < special.groupLimit then
                    insert(group, playerName)
                end
            end
        end
    end
    for groupName, group in pairs(groups) do
        if #group <= 1 then
            groups[groupName] = nil
        end
    end
    return groups
end

local function check_if_enough_playtime_to_play(player)
    return (global.total_time_online_players[player.name] or 0)
        >= global.special_games_variables.captain_mode.minTotalPlaytimeToPlay
end

local function allow_vote()
    local tick = game.ticks_played
    global.difficulty_votes_timeout = tick + 999999
    global.difficulty_player_votes = {}
    game.print(
        '[font=default-large-bold]Difficulty voting is opened until the referee starts the picking phase ![/font]',
        Color.cyan
    )
end

local function generate_captain_mode(refereeName, autoTrust, captainKick, specialEnabled)
    if Functions.get_ticks_since_game_start() > 0 then
        game.print(
            "Must start the captain event on a fresh map. Enable tournament_mode and do '/instant_map_reset current' to reset to current seed.",
            Color.red
        )
        return
    end
    captainKick = captainKick == 'left'
    autoTrust = autoTrust == 'left'

    local auto_pick_interval_ticks = 5 * 60 * 60 -- 5 minutes
    local special = {
        ---@type string[]
        captainList = {},
        refereeName = refereeName,
        ---@type string[]
        listPlayers = {},
        ---@type table<string, string[]>
        communityPickOrder = {},
        ---@type table<string, boolean>
        communityPicksConfirmed = {},
        communityPickingMode = false,
        ---@type table<string, string>
        player_info = {},
        ---@type table<string, boolean>
        kickedPlayers = {},
        listTeamReadyToPlay = {},
        prepaPhase = true,
        countdown = 9,
        minTotalPlaytimeToPlay = 30 * 60 * 60, -- 30 minutes
        pickingPhase = false,
        initialPickingPhaseStarted = false,
        initialPickingPhaseFinished = false,
        nextAutoPicksFavor = { north = 0, south = 0 },
        autoPickIntervalTicks = auto_pick_interval_ticks,
        nextAutoPickTicks = auto_pick_interval_ticks,
        autoTrust = autoTrust,
        captainKick = captainKick,
        northEnabledScienceThrow = true,
        northThrowPlayersListAllowed = {},
        southEnabledScienceThrow = true,
        southThrowPlayersListAllowed = {},
        captainGroupAllowed = true,
        groupLimit = 3,
        teamAssignmentSeed = math_random(10000, 100000),
        playerPickedAtTicks = {},
        stats = {
            northPicks = {},
            southPicks = {},
            tickGameStarting = 0,
            playerPlaytimes = {},
            playerSessionStartTimes = {},
        },
        groupsOrganization = { north = {}, south = {} },
    }
    global.special_games_variables.captain_mode = special
    global.active_special_games.captain_mode = true
    for i = 1, CaptainTaskGroup.get_max_num_organization_groups() do
        special.groupsOrganization.north[i] = { name = 'Group ' .. i, players = {}, player_order = {} }
        special.groupsOrganization.south[i] = { name = 'Group ' .. i, players = {}, player_order = {} }
    end
    local referee = cpt_get_player(special.refereeName)
    if referee == nil then
        game.print(
            'Event captain aborted, referee is not a player connected. Provided referee name was: '
                .. special.refereeName
        )
        global.special_games_variables.captain_mode = nil
        global.active_special_games.captain_mode = false
        return
    end

    if not check_if_enough_playtime_to_play(referee) then
        game.print(
            'Referee does not seem to have enough playtime (which is odd), so disabling min playtime requirement',
            Color.red
        )
        special.minTotalPlaytimeToPlay = 0
    end

    global.bb_threat.north_biters = -1e12
    global.bb_threat.south_biters = -1e12
    clear_gui_captain_mode()

    for _, player in pairs(game.connected_players) do
        if player.force.name ~= 'spectator' then
            player.print('Captain event is on the way, switched you to spectator')
            TeamManager.switch_force(player.name, 'spectator')
        end
        global.captain_ui[player.name] = global.captain_ui[player.name] or {}
        global.captain_ui[player.name].captain_player_gui = true
        global.captain_ui[player.name].captain_referee_gui = true
        Public.draw_captain_tournament_button(player)
        Public.draw_captain_tournament_gui(player)
        Public.draw_captain_player_gui(player)
        Sounds.notify_player(player, 'utility/new_objective')
    end
    global.chosen_team = {}
    clear_character_corpses()
    game.print('Captain mode started !! Have fun ! Referee will be ' .. referee.name)
    if special.autoTrust then
        game.print('Option was enabled : All players will be trusted once they join a team', Color.cyan)
    end
    if special.captainKick then
        game.print('Option was enabled : Captains can eject players of their team', Color.cyan)
    end
    game.print('Picking system : 1-2-2-2-2...', Color.cyan)
    referee.print(
        'Command only allowed for referee to change a captain : /replaceCaptainNorth <playerName> or /replaceCaptainSouth <playerName>',
        Color.cyan
    )
    for _, player in pairs(game.connected_players) do
        if player.admin then
            game.print(
                'Command only allowed for referee or admins to change the current referee : /replaceReferee <playerName>',
                Color.cyan
            )
        end
    end

    if specialEnabled == 'left' then
        special.stats.specialEnabled = 1
    else
        special.stats.specialEnabled = 0
    end

    global.tournament_mode = true
    if global.freeze_players == false or global.freeze_players == nil then
        global.freeze_players = true
        TeamManager.freeze_players()
        game.print('>>> Players have been frozen!', { r = 111, g = 111, b = 255 })
    end
    allow_vote()

    local y = 0
    if global.special_games_variables.rendering == nil then
        global.special_games_variables.rendering = {}
    end
    rendering.clear()
    render_text(
        'captainLineTen',
        "Special Captain's tournament mode enabled",
        { 0, -16 },
        { 1, 0, 0, 1 },
        5,
        'heading-1'
    )
    render_text(
        'captainLineEleven',
        'team xx vs team yy. Referee: ' .. refereeName .. '. Teams on VC',
        { 0, 10 },
        Color.captain_versus_float,
        1.5,
        'heading-1'
    )
    generate_generic_rendering_captain()
end

local function delete_player_from_playersList(playerName, isNorthPlayerBoolean)
    local special = global.special_games_variables.captain_mode
    local tableChosen = special.stats.southPicks
    if isNorthPlayerBoolean then
        tableChosen = special.stats.northPicks
    end
    local index = {}
    for k, v in pairs(tableChosen) do
        index[v] = k
    end
    local indexPlayer = index[playerName]
    remove(tableChosen, indexPlayer)
end

local function generate_vs_text_rendering()
    if
        global.active_special_games
        and global.special_games_variables.rendering
        and global.special_games_variables.rendering.captainLineVersus
    then
        rendering.destroy(global.special_games_variables.rendering.captainLineVersus)
    end

    local special = global.special_games_variables.captain_mode
    local text = string_format(
        'Team %s (North) vs (South) Team %s. Referee: %s. Teams on Voice Chat',
        special.captainList[1],
        special.captainList[2],
        special.refereeName
    )

    render_text('captainLineVersus', text, { 0, 10 }, Color.captain_versus_float, 1.5, 'heading-1')
end

local function start_captain_event()
    Functions.set_game_start_tick()
    game.print('[font=default-large-bold]Time to start the game!! Good luck and have fun everyone ![/font]', Color.cyan)
    if global.freeze_players == true then
        global.freeze_players = false
        TeamManager.unfreeze_players()
        game.print('>>> Players have been unfrozen!', { r = 255, g = 77, b = 77 })
        log('Players have been unfrozen! Game starts now!')
    end
    local special = global.special_games_variables.captain_mode
    special.prepaPhase = false
    special.stats.tickGameStarting = game.ticks_played
    special.stats.NorthInitialCaptain = special.captainList[1]
    special.stats.SouthInitialCaptain = special.captainList[2]
    special.stats.InitialReferee = special.refereeName
    local difficulty = DifficultyVote.difficulty_name()
    if 'difficulty' == "I'm Too Young to Die" then
        difficulty = 'ITYTD'
    elseif 'difficulty' == 'Fun and Fast' then
        difficulty = 'FNF'
    elseif 'difficulty' == 'Piece of Cake' then
        difficulty = 'POC'
    end
    special.stats.extrainfo = difficulty
    global.bb_threat.north_biters = 0
    global.bb_threat.south_biters = 0

    rendering.clear()
    render_text(
        'captainLineSeventeen',
        "Special Captain's tournament mode enabled",
        { 0, -16 },
        { 1, 0, 0, 1 },
        5,
        'heading-1'
    )
    generate_vs_text_rendering()
    generate_generic_rendering_captain()
    render_text(
        'captainLineEighteen',
        'Want to play? Click "Join captain event" in your Tournament menu!',
        { 0, -9 },
        { 1, 1, 1, 1 },
        3,
        'heading-1'
    )

    for _, player in pairs(game.connected_players) do
        if player.force.name == 'north' or player.force.name == 'south' then
            special.stats.playerSessionStartTimes[player.name] = Functions.get_ticks_since_game_start()
        end
    end
end

local countdown_captain_start_token = Token.register(function()
    if global.special_games_variables.captain_mode.countdown > 0 then
        for _, player in pairs(game.connected_players) do
            local _sprite = 'file/png/' .. global.special_games_variables.captain_mode.countdown .. '.png'
            if player.gui.center.bb_captain_countdown then
                player.gui.center.bb_captain_countdown.destroy()
            end
            player.gui.center.add({ name = 'bb_captain_countdown', type = 'sprite', sprite = _sprite })
        end
        Sounds.notify_all('utility/build_blueprint_large')
        global.special_games_variables.captain_mode.countdown = global.special_games_variables.captain_mode.countdown
            - 1
    else
        for _, player in pairs(game.connected_players) do
            if player.gui.center.bb_captain_countdown then
                player.gui.center.bb_captain_countdown.destroy()
            end
        end
        start_captain_event()
    end
end)

local function prepare_start_captain_event()
    local special = global.special_games_variables.captain_mode
    special.listTeamReadyToPlay = { 'north', 'south' }
    Public.update_all_captain_player_guis()

    Task.set_timeout_in_ticks(60, countdown_captain_start_token)
    Task.set_timeout_in_ticks(120, countdown_captain_start_token)
    Task.set_timeout_in_ticks(180, countdown_captain_start_token)
    Task.set_timeout_in_ticks(240, countdown_captain_start_token)
    Task.set_timeout_in_ticks(300, countdown_captain_start_token)
    Task.set_timeout_in_ticks(360, countdown_captain_start_token)
    Task.set_timeout_in_ticks(420, countdown_captain_start_token)
    Task.set_timeout_in_ticks(480, countdown_captain_start_token)
    Task.set_timeout_in_ticks(540, countdown_captain_start_token)
    Task.set_timeout_in_ticks(600, countdown_captain_start_token)
end

local function close_difficulty_vote()
    global.difficulty_votes_timeout = game.ticks_played
    game.print('[font=default-large-bold]Difficulty voting is now closed ![/font]', Color.cyan)
end

local function captain_log_start_time_player(player)
    if
        global.special_games_variables.captain_mode ~= nil
        and (player.force.name == 'south' or player.force.name == 'north')
        and not global.special_games_variables.captain_mode.prepaPhase
    then
        if not global.special_games_variables.captain_mode.stats.playerSessionStartTimes[player.name] then
            global.special_games_variables.captain_mode.stats.playerSessionStartTimes[player.name] =
                Functions.get_ticks_since_game_start()
        end
    end
end

-- Update the 'dropdown' GuiElement with the new items, trying to preserve the current selection (otherwise go to index 1).
local function update_dropdown(dropdown, new_items)
    local selected_index = dropdown.selected_index
    if selected_index == 0 then
        selected_index = 1
    end
    local change_items = #dropdown.items ~= #new_items
    if not change_items then
        for i = 1, #new_items do
            if new_items[i] ~= dropdown.items[i] then
                change_items = true
                break
            end
        end
    end
    if change_items then
        local existing_selection = dropdown.items[selected_index]
        selected_index = 1 -- if no match, go back to "Select Player"
        for index, item in ipairs(new_items) do
            if item == existing_selection then
                selected_index = index
                break
            end
        end
        dropdown.items = new_items
        dropdown.selected_index = selected_index
    end
end

local function get_player_list_with_groups()
    local special = global.special_games_variables.captain_mode
    local result = pretty_print_player_list(special.listPlayers)
    local groups = generate_groups(special.listPlayers)
    local group_strings = {}
    for _, group in pairs(groups) do
        insert(group_strings, '(' .. pretty_print_player_list(group) .. ')')
    end
    if #group_strings > 0 then
        result = result .. '\nGroups: ' .. concat(group_strings, ', ')
    end
    return result
end

local function insert_player_by_playtime(playerName)
    local special = global.special_games_variables.captain_mode
    local playtime = 0
    if global.total_time_online_players[playerName] then
        playtime = global.total_time_online_players[playerName]
    end
    local listPlayers = special.listPlayers
    if table_contains(listPlayers, playerName) then
        return
    end
    local insertionPosition = 1
    for i, player in ipairs(listPlayers) do
        local playtimeOtherPlayer = 0
        if global.total_time_online_players[player] then
            playtimeOtherPlayer = global.total_time_online_players[player]
        end
        if playtimeOtherPlayer < playtime then
            insertionPosition = i
            break
        else
            insertionPosition = i + 1
        end
    end
    insert(listPlayers, insertionPosition, playerName)
end

local function end_of_picking_phase()
    local special = global.special_games_variables.captain_mode
    special.pickingPhase = false
    if not special.initialPickingPhaseFinished then
        special.initialPickingPhaseFinished = true
        if special.captainGroupAllowed then
            game.print(
                '[font=default-large-bold]Initial Picking Phase done - group picking is now disabled[/font]',
                Color.cyan
            )
        end
    end
    special.nextAutoPickTicks = Functions.get_ticks_since_game_start() + special.autoPickIntervalTicks
    if special.prepaPhase then
        game.print(
            '[font=default-large-bold]All players were picked by captains, time to start preparation for each team ! Once your team is ready, captain, click on yes on top popup[/font]',
            Color.cyan
        )
        for _, captain_name in pairs(global.special_games_variables.captain_mode.captainList) do
            local captain = cpt_get_player(captain_name)
            captain.print(
                'As a captain, you can handle your team by accessing "Team Permissions" in your Tournament menu',
                Color.yellow
            )
            if not is_test_player(captain) then
                TeamManager.custom_team_name_gui(captain, captain.force.name)
            end
        end
    end
    Public.update_all_captain_player_guis()
end

local function start_picking_phase()
    local special = global.special_games_variables.captain_mode
    local is_initial_picking_phase = not special.initialPickingPhaseStarted
    special.pickingPhase = true
    if not special.initialPickingPhaseStarted then
        close_difficulty_vote()
        special.initialPickingPhaseStarted = true
    end
    if special.communityPickingMode and is_initial_picking_phase then
        -- Take only the picks that were "confirmed"
        local final_community_picks = {}
        for player, _ in pairs(special.communityPicksConfirmed) do
            filtered_picks = {}
            for _, pick in pairs(special.communityPickOrder[player]) do
                insert(filtered_picks, pick)
            end
            if #filtered_picks ~= #special.listPlayers then
                game.print(string_format('Error: bad picks for player "%s"', player), Color.red)
                force_end_captain_event()
                return
            end
            final_community_picks[player] = filtered_picks
        end
        local picks = CaptainCommunityPick.assign_teams(final_community_picks)
        if not picks then
            force_end_captain_event()
            return
        end
        for i, team in ipairs(picks) do
            local force_name = i == 1 and 'north' or 'south'
            game.print(
                string_format(
                    'Player %s is assigned captain of team %s - this is just for latejoiner picking purposes. Change captain with /replaceCaptain* commands.',
                    team[1],
                    force_name
                ),
                Color.cyan
            )
            table.insert(special.captainList, team[1])
            for _, player in ipairs(team) do
                switch_team_of_player(player, force_name)
                table_remove_element(special.listPlayers, player)
            end
        end
        assert(#special.listPlayers == 0)
        end_of_picking_phase()
        return
    end
    if is_initial_picking_phase then
        game.print(
            '[font=default-large-bold]Picking phase started, captains will pick their team members[/font]',
            Color.cyan
        )
    end
    if #special.listPlayers == 0 then
        end_of_picking_phase()
    else
        special.pickingPhase = true
        local captainChosen
        local favor = special.nextAutoPicksFavor
        for index, force in ipairs({ 'north', 'south' }) do
            if favor[force] > 0 then
                favor[force] = favor[force] - 1
                captainChosen = index
                break
            end
        end
        if captainChosen == nil then
            local counts = { north = 0, south = 0 }
            for _, player in pairs(game.connected_players) do
                local force = player.force.name
                if force == 'north' or force == 'south' then -- exclude "spectator"
                    counts[force] = counts[force] + 1
                end
            end
            local northThreshold = 0.5 - 0.1 * (counts.north - counts.south)
            captainChosen = math_random() < northThreshold and 1 or 2
            log('Captain chosen: ' .. captainChosen)
        end
        poll_alternate_picking(cpt_get_player(special.captainList[captainChosen]))
    end
    Public.update_all_captain_player_guis()
end

---@param referee LuaPlayer
---@return boolean
local function check_if_right_number_of_captains(referee)
    local special = global.special_games_variables.captain_mode
    if #special.captainList < 2 then
        referee.print('Not enough captains! Ask people to volunteer!', Color.cyan)
        return false
    elseif #special.captainList == 2 then
        for index, force_name in pairs({ 'north', 'south' }) do
            local captainName = special.captainList[index]
            add_to_trust(captainName)
            if not special.communityPickingMode then
                switch_team_of_player(captainName, force_name)
                table_remove_element(special.listPlayers, captainName)
            end
        end
        return true
    else
        referee.print('Too many captains! Remove some first!', Color.cyan)
        return false
    end
end

---@return boolean
local function have_enough_community_picks()
    local special = global.special_games_variables.captain_mode
    local num_confirmed = table.size(special.communityPicksConfirmed)
    return num_confirmed >= 5 and num_confirmed >= #special.listPlayers * 0.3
end

local function get_dropdown_value(dropdown)
    if dropdown and dropdown.selected_index then
        return dropdown.items[dropdown.selected_index]
    end
end

---@param cmd CustomCommandData
---@param force string
local function change_captain(cmd, force)
    if not cmd.player_index then
        return
    end
    local playerOfCommand = cpt_get_player(cmd.player_index)
    if not playerOfCommand then
        return
    end
    if not global.active_special_games.captain_mode then
        return playerOfCommand.print({ 'captain.cmd_only_captain_mode' }, Color.red)
    end
    local special = global.special_games_variables.captain_mode
    if special.prepaPhase then
        return playerOfCommand.print({ 'captain.cmd_only_after_prepa_phase' }, Color.red)
    end
    if special.refereeName ~= playerOfCommand.name then
        return playerOfCommand.print('Only referee have license to use that command', Color.red)
    end

    if special.captainList[1] == nil or special.captainList[2] == nil then
        return playerOfCommand.print('Something broke, no captain in the captain variable..', Color.red)
    end
    if cmd.parameter then
        local victim = cpt_get_player(cmd.parameter)
        if victim and victim.valid then
            if not victim.connected then
                return playerOfCommand.print('You can only use this command on a connected player.', Color.red)
            end
            if victim.force.name ~= force then
                return playerOfCommand.print({ 'captain.change_captain_wrong_member' }, Color.red)
            end
            local captain_index = force == 'north' and 1 or 2
            game.print({
                'captain.change_captain_announcement',
                playerOfCommand.name,
                victim.name,
                special.captainList[captain_index],
            }, Color.cyan)
            local oldCaptain = cpt_get_player(special.captainList[captain_index])
            if oldCaptain.gui.screen.captain_manager_gui then
                oldCaptain.gui.screen.captain_manager_gui.destroy()
            end
            if Gui.get_top_element(oldCaptain, 'captain_manager_toggle_button') then
                Gui.get_top_element(oldCaptain, 'captain_manager_toggle_button').destroy()
            end
            special.captainList[captain_index] = victim.name
            generate_vs_text_rendering()
        else
            playerOfCommand.print('Invalid name', Color.warning)
        end
    else
        playerOfCommand.print('Usage: /replaceCaptainNorth <playerName>', Color.warning)
    end
end

local cpt_ui_visibility = {
    -- visible to all
    captain_join_info = function(player)
        return true
    end,
    captain_player_gui = function(player)
        --[[ Visible ON
      1. captain preparation phase
      2. player not assigned to a team (late joiners)
      3. referee always ON to mirror late joiners' view
    ]]
        local special = global.special_games_variables.captain_mode
        return special.prepaPhase or not global.chosen_team[player.name] or (special.refereeName == player.name)
    end,
    captain_referee_gui = function(player)
        -- only to referee
        local special = global.special_games_variables.captain_mode
        return special.refereeName == player.name
    end,
    captain_manager_gui = function(player)
        -- only to captains
        local special = global.special_games_variables.captain_mode
        return global.chosen_team[player.name] and table_contains(special.captainList, player.name)
    end,
    captain_organization_gui = function(player)
        -- only to picked players
        return global.chosen_team[player.name]
    end,
}

-- == EVENTS ==================================================================
local function on_gui_switch_state_changed(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end
    local special = global.special_games_variables.captain_mode
    local name = element.name
    if name == 'captain_community_picking_mode' then
        special.communityPickingMode = element.switch_state == 'left'
        special.communityPicksConfirmed = {}
        special.communityPickOrder = {}
        special.captainList = {}
        special.captainGroupAllowed = false
        if special.test_mode then
            for _, player in pairs(special.listPlayers) do
                if math.random() < 0.5 then
                    special.communityPicksConfirmed[player] = true
                    local pick_order = table.deepcopy(special.listPlayers)
                    -- randomize "pick_order"
                    for i = #pick_order, 2, -1 do
                        local j = math.random(i)
                        pick_order[i], pick_order[j] = pick_order[j], pick_order[i]
                    end
                    special.communityPickOrder[player] = pick_order
                end
            end
        end
        Public.update_all_captain_player_guis()
    elseif name == 'captain_enable_groups_switch' then
        if not special.communityPickingMode then
            special.captainGroupAllowed = element.switch_state == 'left'
            Public.update_all_captain_player_guis()
        end
    end
end

local function on_gui_value_changed(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end
    local special = global.special_games_variables.captain_mode
    if not special then
        return
    end
    if element.name == 'captain_group_limit_slider' then
        special.groupLimit = element.slider_value
        Public.update_all_captain_player_guis()
    end
end

---@param event EventData.on_gui_click
local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then
        return
    end
    local special = global.special_games_variables.captain_mode
    if not special then
        return
    end
    local player = cpt_get_player(event.player_index)
    if not player then
        return
    end
    local name = element.name

    if name == 'captain_player_want_to_play' then
        if not special.pickingPhase then
            if check_if_enough_playtime_to_play(player) then
                insert_player_by_playtime(player.name)
                -- make everyone re-confirm their pick order
                special.communityPicksConfirmed = {}
                Public.update_all_captain_player_guis()
            else
                player.print(
                    'You need to have spent more time on biter battles server to join the captain game event! Learn and watch a bit meanwhile',
                    Color.red
                )
            end
        end
    elseif name == 'captain_player_do_not_want_to_play' then
        if not special.pickingPhase then
            DifficultyVote.remove_player_from_difficulty_vote(player)
            table_remove_element(special.listPlayers, player.name)
            table_remove_element(special.captainList, player.name)
            for _, picks in pairs(special.communityPickOrder) do
                table_remove_element(picks, player.name)
            end
            Public.update_all_captain_player_guis()
        end
    elseif name == 'captain_player_want_to_be_captain' then
        if
            not special.initialPickingPhaseStarted
            and not table_contains(special.captainList, player.name)
            and table_contains(special.listPlayers, player.name)
            and not special.communityPickingMode
        then
            insert(special.captainList, player.name)
            Public.update_all_captain_player_guis()
        end
    elseif name == 'captain_player_do_not_want_to_be_captain' then
        if not special.initialPickingPhaseStarted then
            table_remove_element(special.captainList, player.name)
            Public.update_all_captain_player_guis()
        end
    elseif name == 'captain_player_clear_player_info' then
        local frame = Public.get_active_tournament_frame(player, 'captain_player_gui')
        if frame then
            local textbox = frame.info_flow.insert.captain_player_info
            textbox.text = ''
            special.player_info[player.name] = nil

            local button = frame.info_flow.display.captain_player_info
            button.caption = ''

            frame.info_flow.display.visible = false
        end
    elseif name == 'captain_player_confirm_player_info' then
        local frame = Public.get_active_tournament_frame(player, 'captain_player_gui')
        if frame then
            local textbox = frame.info_flow.insert.captain_player_info
            local text = textbox.text
            text = text:gsub('[%(%)%[%]%=]', '')
            if #text > 200 then
                player.print('Player info must not exceed 200 characters', Color.warning)
                text = string_sub(text, 1, 200)
            end
            textbox.text = text
            local button = frame.info_flow.display.captain_player_info
            button.caption = text
            frame.info_flow.display.visible = #text > 0
            special.player_info[player.name] = text
            if special.communityPickingMode then
                Public.update_all_captain_player_guis()
            end
        end
    elseif name == 'captain_force_end_event' then
        force_end_captain_event()
    elseif name == 'captain_start_initial_picking' then
        -- This marks the start of a picking phase, so players can no longer volunteer to become captain or play
        if not special.initialPickingPhaseStarted then
            game.print('The referee has started the initial picking phase', Color.cyan)
            if special.communityPickingMode then
                if have_enough_community_picks() then
                    start_picking_phase()
                end
            else
                if check_if_right_number_of_captains(player) then
                    start_picking_phase()
                end
            end
        end
    elseif starts_with(name, 'captain_remove_captain_') then
        local captain = element.tags.captain
        table_remove_element(special.captainList, captain)
        Public.update_all_captain_player_guis()
    elseif name == 'captain_start_join_poll' then
        if not global.special_games_variables.captain_mode.pickingPhase then
            start_picking_phase()
        end
    elseif name == 'referee_force_picking_to_stop' then
        if special.pickingPhase then
            end_of_picking_phase()
            -- destroy any open picking UIs
            for _, player in pairs(game.connected_players) do
                if player.gui.screen.captain_poll_alternate_pick_choice_frame then
                    player.gui.screen.captain_poll_alternate_pick_choice_frame.destroy()
                end
            end
            game.print(
                '[font=default-large-bold]Referee ' .. player.name .. ' has forced the picking phase to stop[/font]',
                Color.cyan
            )
        end
    elseif starts_with(name, 'captain_player_picked_') then
        local playerPicked = name:gsub('^captain_player_picked_', '')
        local location
        if player.gui.screen.captain_poll_alternate_pick_choice_frame then
            location = player.gui.screen.captain_poll_alternate_pick_choice_frame.location
            player.gui.screen.captain_poll_alternate_pick_choice_frame.destroy()
        end
        game.print(playerPicked .. ' was picked by Captain ' .. player.name)
        local listPlayers = special.listPlayers
        local forceToGo = 'north'
        if player.name == special.captainList[2] then
            forceToGo = 'south'
        end
        switch_team_of_player(playerPicked, forceToGo)
        cpt_get_player(playerPicked).print({ '', { 'captain.comms_reminder' } }, Color.cyan)
        for index, name in pairs(listPlayers) do
            if name == playerPicked then
                remove(listPlayers, index)
                break
            end
        end
        if is_player_in_group_system(playerPicked) then
            auto_pick_all_of_group(player, playerPicked)
        end
        if #global.special_games_variables.captain_mode.listPlayers == 0 then
            special.pickingPhase = false
            end_of_picking_phase()
        else
            local captain_to_pick_next
            if not special.initialPickingPhaseFinished then
                -- The logic below defaults to a 1-2-2-2-2-... picking system. However, if large groups
                -- are picked, then whatever captain is picking gets to keep picking until they have more
                -- players than the other team, so if there is one group of 3 that is picked first, then
                -- the picking would go 3-4-2-2-2-...
                if #special.stats.southPicks > #special.stats.northPicks then
                    captain_to_pick_next = 1
                elseif #special.stats.northPicks > #special.stats.southPicks then
                    captain_to_pick_next = 2
                else
                    -- default to the same captain continuing to pick
                    captain_to_pick_next = (player.name == special.captainList[1] and 1 or 2)
                end
            else
                -- just alternate picking
                captain_to_pick_next = (player.name == special.captainList[1] and 2 or 1)
            end
            poll_alternate_picking(cpt_get_player(special.captainList[captain_to_pick_next]), location)
        end
        Public.update_all_captain_player_guis()
    elseif name == 'captain_is_ready' then
        if not table_contains(special.listTeamReadyToPlay, player.force.name) then
            game.print('[font=default-large-bold]Team of captain ' .. player.name .. ' is ready ![/font]', Color.cyan)
            insert(special.listTeamReadyToPlay, player.force.name)
            if #special.listTeamReadyToPlay >= 2 then
                prepare_start_captain_event()
            end
        end
        Public.update_all_captain_player_guis()
    elseif name == 'captain_force_captains_ready' then
        if #special.listTeamReadyToPlay < 2 then
            game.print(
                '[font=default-large-bold]Referee ' .. player.name .. ' force started the game ![/font]',
                Color.cyan
            )
            prepare_start_captain_event()
            Public.update_all_captain_player_guis()
        end
    elseif name == 'captain_toggle_throw_science' then
        if special.captainList[2] == player.name then
            special.southEnabledScienceThrow = not special.southEnabledScienceThrow
            game.forces.south.print(
                'Can anyone throw science in your team ? ' .. tostring(special.southEnabledScienceThrow),
                Color.yellow
            )
        else
            special.northEnabledScienceThrow = not special.northEnabledScienceThrow
            game.forces.north.print(
                'Can anyone throw science in your team ? ' .. tostring(special.northEnabledScienceThrow),
                Color.yellow
            )
        end
        Public.update_all_captain_player_guis()
    elseif name == 'captain_favor_plus' then
        local force = element.parent.name
        special.nextAutoPicksFavor[force] = special.nextAutoPicksFavor[force] + 1
        Public.update_all_captain_player_guis()
    elseif name == 'captain_favor_minus' then
        local force = element.parent.name
        special.nextAutoPicksFavor[force] = math.max(0, special.nextAutoPicksFavor[force] - 1)
        Public.update_all_captain_player_guis()
    elseif name == 'captain_change_assignment_seed' then
        special.teamAssignmentSeed = math_random(10000, 100000)
        Public.update_all_captain_player_guis()
    elseif name == 'captain_tournament_button' then
        Public.toggle_captain_tournament_button(player)
    elseif name == 'captain_add_someone_to_throw_trustlist' then
        local frame = Public.get_active_tournament_frame(player, 'captain_manager_gui')
        local playerNameUpdateText =
            get_dropdown_value(frame.captain_manager_root_table.captain_add_trustlist_playerlist)
        if playerNameUpdateText and playerNameUpdateText ~= '' and playerNameUpdateText ~= 'Select Player' then
            local tableToUpdate = special.northThrowPlayersListAllowed
            local forceForPrint = 'north'
            if player.name == special.captainList[2] then
                tableToUpdate = special.southThrowPlayersListAllowed
                forceForPrint = 'south'
            end
            local playerToAdd = cpt_get_player(playerNameUpdateText)
            if playerToAdd ~= nil and playerToAdd.valid then
                if not table_contains(tableToUpdate, playerNameUpdateText) then
                    insert(tableToUpdate, playerNameUpdateText)
                    game.forces[forceForPrint].print(playerNameUpdateText .. ' added to throw trustlist !', Color.green)
                else
                    player.print(playerNameUpdateText .. ' was already added to throw trustlist !', Color.red)
                end
                Public.update_all_captain_player_guis()
            else
                player.print(playerNameUpdateText .. ' does not even exist or not even valid !', Color.red)
            end
        end
    elseif name == 'captain_remove_someone_to_throw_trustlist' then
        local frame = Public.get_active_tournament_frame(player, 'captain_manager_gui')
        local playerNameUpdateText =
            get_dropdown_value(frame.captain_manager_root_table.captain_remove_trustlist_playerlist)
        if playerNameUpdateText and playerNameUpdateText ~= '' and playerNameUpdateText ~= 'Select Player' then
            local tableToUpdate = special.northThrowPlayersListAllowed
            local forceForPrint = 'north'
            if player.name == special.captainList[2] then
                tableToUpdate = special.southThrowPlayersListAllowed
                forceForPrint = 'south'
            end
            if table_contains(tableToUpdate, playerNameUpdateText) then
                table_remove_element(tableToUpdate, playerNameUpdateText)
                game.forces[forceForPrint].print(
                    playerNameUpdateText .. ' was removed in throw trustlist !',
                    Color.green
                )
            else
                player.print(playerNameUpdateText .. ' was not found in throw trustlist !', Color.red)
            end
            Public.update_all_captain_player_guis()
        end
    elseif name == 'captain_eject_player' then
        local frame = Public.get_active_tournament_frame(player, 'captain_manager_gui')
        local dropdown = frame.captain_manager_root_table_two.captain_eject_playerlist
        local victim = cpt_get_player(get_dropdown_value(dropdown))
        if victim and victim.valid then
            if victim.name == player.name then
                return player.print("You can't select yourself!", Color.red)
            end
            game.print({ 'captain.eject_player', player.name, victim.name })
            special.kickedPlayers[victim.name] = true
            delete_player_from_playersList(victim.name, victim.force.name)
            if victim.character then
                victim.character.die('player')
            end
            TeamManager.switch_force(victim.name, 'spectator')
        else
            player.print('Invalid name', Color.red)
        end
    elseif name == 'tournament_subheader_toggle' then
        local parent_name = element.parent.name
        local action = Public['toggle_' .. parent_name]
        if action then
            action(player)
        else
            error('Missing captain.lua/Public.toggle_' .. parent_name .. '(player)')
        end
    elseif name == 'tournament_frame_row_toggle' then
        local default = element.sprite == 'utility/collapse'
        element.sprite = default and 'utility/expand_dots_white' or 'utility/collapse'
        element.hovered_sprite = default and 'utility/expand_dots' or 'utility/collapse_dark'
        local body = element.parent.parent.flow.frame
        body.visible = not body.visible
        global.captain_ui[player.name][body.parent.parent.name] = body.visible
        if body.visible and Public['update_' .. body.parent.parent.name] then
            Public['update_' .. body.parent.parent.name](player)
        end
    elseif starts_with(name, 'captains_community_pick_add_player_') then
        local pick_order = special.communityPickOrder[player.name]
        if not pick_order then
            pick_order = {}
            special.communityPickOrder[player.name] = pick_order
        end
        local player_to_add = element.tags.player_name
        if table_contains(pick_order, player_to_add) then
            return
        end
        insert(pick_order, player_to_add)
        Public.update_captain_player_gui(player)
    elseif starts_with(name, 'captains_community_pick_move_') then
        local move_by = starts_with(name, 'captains_community_pick_move_up_') and -1 or 1
        local pick_order = special.communityPickOrder[player.name] or {}
        if event.shift then
            move_by = move_by * #pick_order
        elseif event.button == defines.mouse_button_type.right then
            move_by = move_by * 5
        end
        local tags = element.tags
        local old_position = tags.old_position --[[@as integer]]
        if pick_order[old_position] == tags.player_name then
            local new_position = math.clamp(old_position + move_by, 1, #pick_order)
            remove(pick_order, old_position)
            insert(pick_order, new_position, tags.player_name)
        end
        Public.update_captain_player_gui(player)
    elseif name == 'captain_community_pick_confirm' then
        local pick_order = special.communityPickOrder[player.name] or {}
        for _, player_to_add in pairs(pick_order) do
            if not table_contains(special.listPlayers, player_to_add) then
                return
            end
        end
        special.communityPicksConfirmed[player.name] = true
        Public.update_all_captain_player_guis()
    end
end

local function on_player_changed_force(event)
    local player = game.get_player(event.player_index)
    if player.force.name == 'spectator' then
        Public.captain_log_end_time_player(player)
    else
        captain_log_start_time_player(player)
    end
    Public.update_all_captain_player_guis()
end

local function on_player_left_game(event)
    local player = game.get_player(event.player_index)

    local special = global.special_games_variables.captain_mode
    if not special or not player then
        return
    end
    DifficultyVote.remove_player_from_difficulty_vote(player)
    if not special.pickingPhase then
        table_remove_element(special.listPlayers, player.name)
        if special.prepaPhase then
            table_remove_element(special.captainList, player.name)
        end
    end

    Public.captain_log_end_time_player(player)
    Public.update_all_captain_player_guis()
end

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    if global.special_games_variables.captain_mode ~= nil and player.gui.center.bb_captain_countdown then
        player.gui.center.bb_captain_countdown.destroy()
    end
    captain_log_start_time_player(player)
    if global.special_games_variables.captain_mode then
        global.captain_ui[player.name] = global.captain_ui[player.name] or {}
        global.captain_ui[player.name].captain_player_gui = true

        Public.draw_captain_tournament_button(player)
        Public.draw_captain_tournament_gui(player)
        Public.draw_captain_player_gui(player)
        Sounds.notify_player(player, 'utility/new_objective')
    end
    Public.update_all_captain_player_guis()
end

local function every_5sec(event)
    if global.special_games_variables.captain_mode then
        Public.update_all_captain_player_guis()
        if Functions.get_ticks_since_game_start() >= global.special_games_variables.captain_mode.nextAutoPickTicks then
            if not global.special_games_variables.captain_mode.pickingPhase then
                start_picking_phase()
            end
        end
    end
end

-- == DRAW BUTTONS ============================================================
function Public.draw_captain_tournament_button(player)
    if is_test_player(player) then
        return
    end
    local button = Gui.add_top_element(player, {
        type = 'sprite-button',
        sprite = 'utility/side_menu_achievements_icon',
        hovered_sprite = 'utility/side_menu_achievements_hover_icon',
        name = 'captain_tournament_button',
        tooltip = { 'gui.tournament_top_button' },
        index = Gui.get_top_index(player),
    })
end

-- == TOGGLES =================================================================
function Public.toggle_captain_join_info(player)
    if player.gui.screen.captain_join_info then
        global.captain_ui[player.name].captain_join_info = false
        player.gui.screen.captain_join_info.destroy()
    else
        global.captain_ui[player.name].captain_join_info = true
        Public.draw_captain_join_info(player)
    end
end

function Public.toggle_captain_player_gui(player)
    if player.gui.screen.captain_player_gui then
        global.captain_ui[player.name].captain_player_gui = false
        player.gui.screen.captain_player_gui.destroy()
    else
        global.captain_ui[player.name].captain_player_gui = true
        Public.draw_captain_player_gui(player)
    end
end

function Public.toggle_captain_referee_gui(player)
    if player.gui.screen.captain_referee_gui then
        global.captain_ui[player.name].captain_referee_gui = false
        player.gui.screen.captain_referee_gui.destroy()
    else
        global.captain_ui[player.name].captain_referee_gui = true
        Public.draw_captain_referee_gui(player)
    end
end

function Public.toggle_captain_manager_gui(player)
    if player.gui.screen.captain_manager_gui then
        global.captain_ui[player.name].captain_manager_gui = false
        player.gui.screen.captain_manager_gui.destroy()
    else
        global.captain_ui[player.name].captain_manager_gui = true
        Public.draw_captain_manager_gui(player)
    end
end

function Public.toggle_captain_organization_gui(player)
    CaptainTaskGroup.toggle_captain_organization_gui(player)
end

function Public.toggle_captain_tournament_button(player)
    Public.toggle_captain_tournament_gui(player)
end

function Public.toggle_captain_tournament_gui(player)
    local main_frame = Gui.get_left_element(player, 'captain_tournament_gui')
    if main_frame then
        main_frame.destroy()
    else
        Public.draw_captain_tournament_gui(player)
    end
end

-- == DRAW GUI =================================================================
function Public.draw_captain_join_info(player, main_frame)
    if is_test_player(player) then
        return
    end

    if not main_frame then
        if player.gui.screen.captain_join_info then
            player.gui.screen.captain_join_info.destroy()
        end

        main_frame = ClosableFrame.create_draggable_frame(player, 'captain_join_info', 'Tournament info')
        gui_style(main_frame, { minimal_width = 700, maximal_width = 920 })
    end

    local flow = main_frame.add({ type = 'flow', direction = 'vertical' })
    gui_style(flow, { vertically_squashable = false })

    local label = flow.add({ type = 'label', caption = { 'captain.info_content' } })
    gui_style(label, {
        single_line = false,
        font_color = { 255, 255, 255 },
        horizontally_squashable = true,
        horizontally_stretchable = true,
    })
end

---@param parent LuaGuiElement
---@param flow_name string
---@param sprite string
---@param caption LocalisedString
---@return LuaGuiElement
local function captain_player_gui_header(parent, flow_name, sprite, caption)
    local title_wrap = parent.add({ name = flow_name, type = 'flow', direction = 'vertical' })
    local title = title_wrap.add({ name = 'inner_flow', type = 'flow', direction = 'horizontal' })
    gui_style(title, {
        horizontally_stretchable = true,
        vertically_stretchable = true,
        vertical_align = 'center',
        horizontal_align = 'center',
    })

    Gui.add_pusher(title)

    button = title.add({
        type = 'sprite-button',
        sprite = sprite,
        style = 'transparent_slot',
    })
    button.ignored_by_interaction = true
    gui_style(button, { size = 40 })

    Gui.add_pusher(title)

    label = title.add({ name = 'title', type = 'label', caption = caption })
    gui_style(label, { font = 'heading-2' })

    Gui.add_pusher(title)

    button = title.add({
        type = 'sprite-button',
        sprite = sprite,
        style = 'transparent_slot',
    })
    button.ignored_by_interaction = true
    gui_style(button, { size = 40 })

    Gui.add_pusher(title)
    return title_wrap
end

function Public.draw_captain_player_gui(player, main_frame)
    if is_test_player(player) then
        return
    end

    if not main_frame then
        if player.gui.screen.captain_player_gui then
            player.gui.screen.captain_player_gui.destroy()
        end

        main_frame = ClosableFrame.create_draggable_frame(player, 'captain_player_gui', 'Join Tournament')
        main_frame.style.maximal_width = 800
    end

    local label, button, line
    local special = global.special_games_variables.captain_mode

    local title_flow = captain_player_gui_header(
        main_frame,
        'title_flow',
        'utility/side_menu_achievements_icon',
        'A CAPTAINS GAME WILL START SOON!'
    )
    title_flow.add({ type = 'line' })

    do -- Preparation flow
        local prepa_flow = main_frame.add({ type = 'flow', name = 'prepa_flow', direction = 'vertical' })
        gui_style(prepa_flow, { horizontally_stretchable = true })

        label = prepa_flow.add({
            type = 'label',
            name = 'want_to_play_players_list',
            style = 'label_with_left_padding',
        })
        gui_style(label, { single_line = false, maximal_width = 400 })

        label = prepa_flow.add({
            type = 'label',
            name = 'captain_volunteers_list',
            style = 'label_with_left_padding',
        })

        label = prepa_flow.add({
            type = 'label',
            name = 'confirmed_picks_label',
            style = 'label_with_left_padding',
        })
        gui_style(label, { single_line = false })

        label = prepa_flow.add({
            type = 'label',
            name = 'remaining_players_list',
            style = 'label_with_left_padding',
        })
        gui_style(label, { single_line = false })
        prepa_flow.add({ type = 'line' })
    end

    do -- Status
        label = main_frame.add({
            type = 'label',
            name = 'status_label',
            caption = 'status_label',
            style = 'label_with_left_padding',
        })
        gui_style(label, { single_line = false })
    end

    main_frame.add({ type = 'line' })

    do -- Join buttons
        local flow = main_frame.add({ type = 'flow', name = 'join_flow', direction = 'horizontal' })
        gui_style(flow, { horizontal_align = 'center', margin = 8 })

        Gui.add_pusher(flow)

        local join_table = flow.add({ type = 'table', name = 'table', column_count = 2 })
        button = join_table.add({
            type = 'button',
            name = 'captain_player_do_not_want_to_play',
            caption = "Nevermind, I don't want to play",
            style = 'red_back_button',
            tooltip = 'Boo',
        })
        gui_style(button, { natural_width = 240, height = 28, horizontal_align = 'center', font = 'heading-3' })

        button = join_table.add({
            type = 'button',
            name = 'captain_player_want_to_play',
            caption = 'I want to play!',
            style = 'confirm_button',
            tooltip = 'Yay',
        })
        gui_style(button, { natural_width = 200, height = 28, horizontal_align = 'left', font = 'heading-3' })

        button = join_table.add({
            type = 'button',
            name = 'captain_player_do_not_want_to_be_captain',
            caption = "Nevermind, I don't want to captain",
            style = 'red_back_button',
            tooltip = 'The weight of responsibility is too great',
        })
        gui_style(button, { natural_width = 240, height = 28, horizontal_align = 'center', font = 'heading-3' })

        button = join_table.add({
            type = 'button',
            name = 'captain_player_want_to_be_captain',
            caption = 'I want to be a CAPTAIN!',
            style = 'confirm_button',
            tooltip = 'The community needs you',
        })
        gui_style(button, { natural_width = 200, height = 28, horizontal_align = 'left', font = 'heading-3' })

        Gui.add_pusher(flow)
    end

    main_frame.add({ type = 'line' })

    do -- Player info
        -- Add a textbox for the player to enter info for the captains to see when picking
        local info_flow = main_frame.add({ type = 'flow', name = 'info_flow', direction = 'vertical' })
        gui_style(info_flow, { horizontally_stretchable = true })

        label = info_flow.add({
            type = 'label',
            name = 'captain_player_info_label',
            style = 'label_with_left_padding',
            caption = { 'captain.player_info_textbox_caption' },
        })
        gui_style(label, { single_line = false })

        local textbox_flow = info_flow.add({ type = 'flow', name = 'insert', direction = 'horizontal' })
        gui_style(textbox_flow, { horizontal_spacing = 5 })

        Gui.add_pusher(textbox_flow)

        local textbox = textbox_flow.add({
            type = 'textfield',
            name = 'captain_player_info',
            text = special.player_info[player.name] or '',
            tooltip = { 'captain.player_info_textbox_tooltip' },
        })
        gui_style(textbox, { horizontally_stretchable = true, width = 380 })

        button = textbox_flow.add({
            type = 'sprite-button',
            sprite = 'utility/close_black',
            name = 'captain_player_clear_player_info',
            style = 'tool_button_red',
            tooltip = 'Clear player info',
        })

        button = textbox_flow.add({
            type = 'sprite-button',
            sprite = 'utility/check_mark',
            name = 'captain_player_confirm_player_info',
            style = 'tool_button_green',
            tooltip = 'Confirm player info',
        })

        Gui.add_pusher(textbox_flow)

        local display_flow = info_flow.add({ type = 'flow', name = 'display', direction = 'horizontal' })
        gui_style(display_flow, { horizontally_stretchable = true, vertical_align = 'center' })

        Gui.add_pusher(display_flow)

        button = display_flow.add({
            type = 'button',
            name = 'captain_player_info',
            caption = special.player_info[player.name] or '',
            style = 'partially_accessible_station_in_station_selection',
        })
        button.ignored_by_interaction = true
        gui_style(button, { horizontally_stretchable = true, width = 380 + (28 + 5) * 2, left_padding = 3 })

        Gui.add_pusher(display_flow)
    end

    line = main_frame.add({ type = 'line' })

    do -- Community pick UI
        local flow = main_frame.add({ type = 'flow', name = 'community_pick_flow', direction = 'vertical' })
        captain_player_gui_header(flow, 'community_pick_title', 'utility/slot_icon_inserter_hand', 'COMMUNITY PICK')
        local label = flow.add({
            type = 'label',
            name = 'community_pick_label',
            caption = 'Please choose a pick order for all players.',
        })
        button = flow.add({
            type = 'button',
            name = 'captain_community_pick_confirm',
            caption = "I'm happy with the pick order below",
            style = 'confirm_button',
            tooltip = 'Pick all players below before confirming',
        })
        gui_style(button, { natural_width = 200, height = 28, horizontal_align = 'left', font = 'heading-3' })

        label.style.single_line = false
        local scroll = flow.add({
            type = 'scroll-pane',
            name = 'community_pick_scroll',
            direction = 'vertical',
            style = 'scroll_pane_under_subheader',
        })
        gui_style(scroll, { maximal_height = 600, vertically_squashable = false })
    end

    do -- Player table
        local pick_flow = main_frame.add({ type = 'flow', name = 'pick_flow', direction = 'vertical' })
        captain_player_gui_header(
            pick_flow,
            'player_table_title',
            'utility/slot_icon_inserter_hand',
            'CAPTAINS PICK LIST'
        )

        local scroll = pick_flow.add({
            type = 'scroll-pane',
            name = 'player_table_scroll',
            direction = 'vertical',
            style = 'scroll_pane_under_subheader',
        })
        gui_style(scroll, { maximal_height = 600, vertically_squashable = false })
    end

    Public.update_captain_player_gui(player, main_frame)
end

function Public.draw_captain_referee_gui(player, main_frame)
    if is_test_player(player) then
        return
    end
    if not main_frame then
        if player.gui.screen.captain_referee_gui then
            player.gui.screen.captain_referee_gui.destroy()
        end
        main_frame = ClosableFrame.create_draggable_frame(player, 'captain_referee_gui', 'Referee')
        main_frame.style.maximal_width = 800
    end
    main_frame.add({ type = 'flow', name = 'scroll', direction = 'vertical' })
    Public.update_captain_referee_gui(player, main_frame)
end

function Public.draw_captain_manager_gui(player, main_frame)
    if is_test_player(player) then
        return
    end
    if not main_frame then
        if player.gui.screen.captain_manager_gui then
            player.gui.screen.captain_manager_gui.destroy()
        end
        main_frame = ClosableFrame.create_draggable_frame(player, 'captain_manager_gui', 'Team Permissions')
    end

    main_frame.add({ type = 'label', name = 'diff_vote_duration' })
    main_frame.add({ type = 'button', name = 'captain_is_ready' })
    main_frame.add({
        type = 'label',
        caption = '[font=heading-1][color=purple]Management for science throwing[/color][/font]',
    })
    main_frame.add({ type = 'button', name = 'captain_toggle_throw_science' })
    local t = main_frame.add({ type = 'table', name = 'captain_manager_root_table', column_count = 2 })
    t.add({
        type = 'button',
        name = 'captain_add_someone_to_throw_trustlist',
        caption = 'Add to throw trustlist',
        tooltip = 'Add someone to be able to throw science when captain disabled throwing science from their team',
    })
    t.add({ name = 'captain_add_trustlist_playerlist', type = 'drop-down', width = 140 })
    t.add({
        type = 'button',
        name = 'captain_remove_someone_to_throw_trustlist',
        caption = 'Remove from throw trustlist',
        tooltip = 'Remove someone to be able to throw science when captain disabled throwing science from their team',
    })
    t.add({ name = 'captain_remove_trustlist_playerlist', type = 'drop-down', width = 140 })

    main_frame.add({ type = 'label', name = 'throw_science_label' })

    main_frame.add({ type = 'label', name = 'trusted_to_throw_list_label' })
    main_frame.add({ type = 'label', caption = '' })
    main_frame.add({
        type = 'label',
        caption = '[font=heading-1][color=purple]Management for your players[/color][/font]',
    })
    local t2 = main_frame.add({ type = 'table', name = 'captain_manager_root_table_two', column_count = 3 })
    t2.add({
        type = 'button',
        name = 'captain_eject_player',
        caption = 'Eject a player of your team',
        tooltip = "If you don't want someone to be in your team anymore, use this button (used for griefers, players not listening and so on..)",
    })
    t2.add({ name = 'captain_eject_playerlist', type = 'drop-down', width = 140 })

    Public.update_captain_manager_gui(player, main_frame)
end

function Public.draw_captain_organization_gui(player, main_frame)
    if is_test_player(player) then
        return
    end
    CaptainTaskGroup.draw_captain_organization_gui(player, main_frame)
end

function Public.draw_captain_tournament_gui(player)
    if is_test_player(player) then
        return
    end

    local main_frame = Gui.get_left_element(player, 'captain_tournament_gui')
    if main_frame then
        main_frame.destroy()
    end

    local main_frame =
        Gui.add_left_element(player, { type = 'frame', name = 'captain_tournament_gui', direction = 'vertical' })
    gui_style(main_frame, { maximal_width = 220, maximal_height = 600 })

    local flow = main_frame.add({ type = 'flow', name = 'flow', style = 'vertical_flow', direction = 'vertical' })
    local inner_frame = flow.add({
        type = 'frame',
        name = 'inner_frame',
        style = 'window_content_frame_packed',
        direction = 'vertical',
    })

    -- == SUBHEADER =================================================================
    local subheader = inner_frame.add({ type = 'frame', name = 'subheader', style = 'subheader_frame' })
    gui_style(subheader, { horizontally_stretchable = true, horizontally_squashable = true, maximal_height = 40 })

    local label = subheader.add({ type = 'label', caption = 'Tournament Menu' })
    gui_style(label, { font = 'heading-3', font_color = { 165, 165, 165 }, left_margin = 4 })

    -- == MAIN FRAME ================================================================
    local sp = inner_frame
        .add({ type = 'frame', name = 'qbip', style = 'quick_bar_inner_panel' })
        .add({ type = 'scroll-pane', name = 'qbsp', style = 'shortcut_bar_selection_scroll_pane' })

    local function add_shortcut_selection_row(parent, p)
        local frame =
            parent.add({ type = 'frame', name = p.name, style = 'shortcut_selection_row', direction = 'horizontal' })
        gui_style(frame, {
            height = 36,
            left_padding = 4,
            right_padding = 4,
            use_header_filler = false,
            horizontally_stretchable = true,
            vertically_stretchable = false,
        })

        local icon = frame.add({
            type = 'sprite-button',
            style = 'transparent_slot',
            sprite = p.sprite,
            hovered_sprite = p.hovered_sprite,
        })
        gui_style(icon, { padding = -2, size = 24, right_margin = 4 })

        local label = frame.add({ type = 'label', style = 'heading_3_label', caption = p.caption })
        gui_style(label, { font_color = { 165, 165, 165 } })

        Gui.add_pusher(frame)

        local button = frame.add({
            type = 'sprite-button',
            name = 'tournament_subheader_toggle',
            style = 'slot_button',
            sprite = 'utility/expand',
            hovered_sprite = 'utility/expand_dark',
            tooltip = '[font=default-bold]' .. p.caption .. '[/font]\n' .. p.tooltip,
        })
        gui_style(button, { size = 22, padding = -2, left_margin = 6 })
    end

    for _, params in pairs(tournament_pages) do
        add_shortcut_selection_row(sp, params)
    end

    -- == SUBFOOTER ===============================================================
    local subfooter =
        inner_frame.add({ type = 'frame', name = 'subfooter', style = 'subfooter_frame', direction = 'horizontal' })
    gui_style(subfooter, { horizontally_stretchable = true, horizontally_squashable = true, maximal_height = 36 })

    Gui.add_pusher(subfooter)

    Public.update_captain_tournament_gui(player)
end

-- == UPDATE GUI ===============================================================
function Public.update_captain_player_gui(player, frame)
    if not frame then
        frame = Public.get_active_tournament_frame(player, 'captain_player_gui')
    end
    if not (frame and frame.visible) then
        return
    end
    local special = global.special_games_variables.captain_mode
    local waiting_to_be_picked = table_contains(special.listPlayers, player.name)

    do -- title flow
        if not special.prepaPhase then
            frame.title_flow.inner_flow.title.caption = 'A CAPTAINS GAME IS CURRENTLY ACTIVE!'
        end
    end
    do -- Preparation flow
        local prepa_flow = frame.prepa_flow
        if special.prepaPhase then
            local want_to_play = prepa_flow.want_to_play_players_list
            local cpt_volunteers = prepa_flow.captain_volunteers_list
            cpt_volunteers.visible = false
            local confirmed_picks_label = prepa_flow.confirmed_picks_label
            confirmed_picks_label.visible = false
            local rem = prepa_flow.remaining_players_list
            if not special.initialPickingPhaseStarted then
                want_to_play.visible = true
                want_to_play.caption = 'Players (' .. #special.listPlayers .. '): ' .. get_player_list_with_groups()
                rem.visible = false
                if special.communityPickingMode then
                    confirmed_picks_label.visible = true
                    local confirmed_pick_players = {}
                    for player, _ in pairs(special.communityPicksConfirmed) do
                        table.insert(confirmed_pick_players, player)
                    end
                    confirmed_picks_label.caption = 'Players that have confirmed pick orders ('
                        .. #confirmed_pick_players
                        .. '): '
                        .. pretty_print_player_list(confirmed_pick_players)
                else
                    cpt_volunteers.visible = true
                    cpt_volunteers.caption = 'Captain volunteers ('
                        .. #special.captainList
                        .. '): '
                        .. pretty_print_player_list(special.captainList)
                end
            else
                want_to_play.visible = false
                rem.visible = true
                rem.caption = 'Players remaining to be picked ('
                    .. #special.listPlayers
                    .. '): '
                    .. pretty_print_player_list(special.listPlayers)
            end
        end
        prepa_flow.visible = special.prepaPhase
    end

    do -- Status & Join buttons
        local status_strings = {}

        local join_table = frame.join_flow.table
        join_table.captain_player_want_to_play.visible = false
        join_table.captain_player_do_not_want_to_play.visible = false
        join_table.captain_player_want_to_be_captain.visible = false
        join_table.captain_player_do_not_want_to_be_captain.visible = false

        if global.chosen_team[player.name] then
            insert(
                status_strings,
                'On team '
                    .. global.chosen_team[player.name]
                    .. ': '
                    .. Functions.team_name_with_color(global.chosen_team[player.name])
            )
        elseif special.kickedPlayers[player.name] then
            insert(
                status_strings,
                'You were kicked from a team, talk to the Referee about joining if you want to play.'
            )
        elseif special.pickingPhase and waiting_to_be_picked then
            insert(status_strings, 'Currently waiting to be picked by a captain.')
        elseif special.pickingPhase then
            insert(
                status_strings,
                'A picking phase is currently active, wait until it is done before you can indicate that you want to play.'
            )
        end

        if
            not global.chosen_team[player.name]
            and not special.pickingPhase
            and not special.kickedPlayers[player.name]
        then
            join_table.captain_player_want_to_play.visible = true
            join_table.captain_player_want_to_play.enabled = not waiting_to_be_picked
            join_table.captain_player_do_not_want_to_play.visible = true
            join_table.captain_player_do_not_want_to_play.enabled = waiting_to_be_picked
                and not special.communityPickingMode
            if special.prepaPhase and not special.initialPickingPhaseStarted then
                if special.captainGroupAllowed then
                    insert(
                        status_strings,
                        string_format(
                            'Groups of players: ENABLED, group name must start with "%s"',
                            ComfyPanelGroup.COMFY_PANEL_CAPTAINS_GROUP_PREFIX
                        )
                    )
                    insert(status_strings, string_format('Max players allowed in a group: %d', special.groupLimit))
                else
                    insert(status_strings, 'Groups of players: DISABLED')
                end
                if not special.communityPickingMode then
                    join_table.captain_player_want_to_be_captain.visible = true
                    join_table.captain_player_do_not_want_to_be_captain.visible = true
                    if table_contains(special.captainList, player.name) then
                        insert(status_strings, 'You are willing to be a captain! Thank you!')
                        join_table.captain_player_want_to_be_captain.enabled = false
                        join_table.captain_player_do_not_want_to_be_captain.enabled = true
                    else
                        insert(status_strings, 'You are not currently willing to be captain.')
                        join_table.captain_player_want_to_be_captain.enabled = waiting_to_be_picked
                        join_table.captain_player_do_not_want_to_be_captain.enabled = false
                    end
                end
            end
        end
        if not special.prepaPhase then
            -- waiting for next picking phase (with time remaining)
            local ticks_until_autopick = special.nextAutoPickTicks - Functions.get_ticks_since_game_start()
            if ticks_until_autopick < 0 then
                ticks_until_autopick = 0
            end
            insert(status_strings, string_format('Next auto picking phase in %ds.', ticks_until_autopick / 60))
        end
        frame.status_label.caption = concat(status_strings, '\n')
    end

    do -- Player info
        local info_flow = frame.info_flow
        info_flow.visible = (waiting_to_be_picked and not special.pickingPhase)
        info_flow.display.visible = special.player_info[player.name] and #special.player_info[player.name] > 0
    end

    do -- Community pick UI
        local flow = frame.community_pick_flow
        local scroll = flow.community_pick_scroll
        flow.visible = special.communityPickingMode
        if special.communityPickingMode then
            flow.visible = true
            scroll.clear()

            local cols = { '', 'Player', 'Playtime', 'Notes' }
            local tab = scroll.add({
                type = 'table',
                name = 'player_table',
                column_count = #cols,
                draw_horizontal_line_after_headers = true,
                style = 'mods_table',
            })
            gui_style(tab, { horizontally_stretchable = true })

            for i, col in pairs(cols) do
                local label = tab.add({ type = 'label', caption = col, style = 'heading_3_label' })
                gui_style(label, { top_margin = 4, bottom_margin = 4 })
            end
            local function add_common_cols(tab, player_name)
                tab.add({
                    type = 'label',
                    caption = player_name,
                    style = 'valid_mod_label',
                })
                tab.add({
                    type = 'label',
                    caption = Functions.format_ticks_as_time(Public.get_total_playtime_of_player(player_name)),
                    style = 'valid_mod_label',
                })
                tab.add({
                    type = 'label',
                    caption = special.player_info[player_name] or '',
                    style = 'valid_mod_label',
                })
            end
            local pick_order = special.communityPickOrder[player.name] or {}
            ---@type table<string, boolean>
            local included_players = {}
            for position, player_name in ipairs(pick_order) do
                included_players[player_name] = true
                local buttons_flow = tab.add({ type = 'flow', direction = 'horizontal' })
                -- add a small up-arrow button
                local up_button = buttons_flow.add({
                    type = 'button',
                    name = 'captains_community_pick_move_up_' .. player_name,
                    tags = { player_name = player_name, old_position = position },
                    caption = '↑',
                    style = 'tool_button',
                    tooltip = 'Move player up in the pick order, shift-click to move to top, right-click to move 5',
                })
                if position == 1 then
                    up_button.enabled = false
                end
                local down_button = buttons_flow.add({
                    type = 'button',
                    name = 'captains_community_pick_move_down_' .. player_name,
                    tags = { player_name = player_name, old_position = position },
                    caption = '↓',
                    style = 'tool_button',
                    tooltip = 'Move player down in the pick order, shift-click to move to bottom, right-click to move 5',
                })
                if position == #pick_order then
                    down_button.enabled = false
                end
                buttons_flow.add({ type = 'label', caption = tostring(position) })
                add_common_cols(tab, player_name)
            end
            local any_unpicked_players = false
            for _, player_name in ipairs(special.listPlayers) do
                if not included_players[player_name] then
                    any_unpicked_players = true
                    tab.add({
                        type = 'button',
                        name = 'captains_community_pick_add_player_' .. player_name,
                        tags = { player_name = player_name },
                        caption = 'Pick Next',
                        tooltip = 'Add player to the pick order',
                    })
                    add_common_cols(tab, player_name)
                end
            end
            flow.captain_community_pick_confirm.enabled = not any_unpicked_players
            flow.captain_community_pick_confirm.visible = not special.communityPicksConfirmed[player.name]
        else
            flow.visible = false
        end
    end

    do -- Player table
        local player_info = {}
        for player_name, force_name in pairs(global.chosen_team) do
            local info = {
                force = force_name,
                status = {},
                playtime = Public.get_total_playtime_of_player(player_name),
                picked_at = special.playerPickedAtTicks[player_name],
            }
            player_info[player_name] = info
            local player = cpt_get_player(player_name)
            if player_name == special.refereeName then
                insert(info.status, 'Referee')
            end
            if table_contains(special.captainList, player_name) then
                insert(info.status, 'Captain')
            end
            if player and not player.connected then
                insert(info.status, 'Disconnected')
            elseif player and player.force.name == 'spectator' then
                insert(info.status, 'Spectating')
            end
        end
        if global.captains_add_silly_test_players_to_list then
            local forces = { 'north', 'south' }
            for i = 1, 10 do
                local status = (i % 2 == 0) and { 'Spectating' } or {}
                for index, player_name in pairs({ 'alice', 'bob', 'charlie', 'dave', 'eve' }) do
                    if index % 2 == 0 then
                        insert(status, 'Disconnected')
                    end
                    player_info[player_name .. tostring(i)] = {
                        force = forces[index % 2 + 1],
                        status = status,
                        playtime = i * 60 * 60 * 10,
                        picked_at = i * 60 * 60 * 1,
                    }
                end
            end
            insert(player_info.alice1.status, 'Captain')
            insert(player_info.alice1.status, 'Referee')
        end
        local sorted_players = {}
        for player_name, _ in pairs(player_info) do
            insert(sorted_players, player_name)
        end
        sort(sorted_players, function(a, b)
            local info_a = player_info[a]
            local info_b = player_info[b]
            if info_a.force ~= info_b.force then
                return info_a.force == 'north'
            end
            if info_a.playtime ~= info_b.playtime then
                return info_a.playtime > info_b.playtime
            end
            return a < b
        end)
        local pick_flow = frame.pick_flow
        local scroll = pick_flow.player_table_scroll
        if #sorted_players > 0 then
            pick_flow.visible = true
            scroll.clear()

            local tab = scroll.add({
                type = 'table',
                name = 'player_table',
                column_count = 5,
                draw_horizontal_line_after_headers = true,
                style = 'mods_table',
            })
            gui_style(tab, { horizontally_stretchable = true })

            local label
            label = tab.add({ type = 'label', caption = 'Player', style = 'heading_3_label' })
            gui_style(label, { top_margin = 4, bottom_margin = 4 })
            label = tab.add({ type = 'label', caption = 'Team', style = 'heading_3_label' })
            gui_style(label, { top_margin = 4, bottom_margin = 4 })
            label = tab.add({ type = 'label', caption = 'PickedAt', style = 'heading_3_label' })
            gui_style(label, { top_margin = 4, bottom_margin = 4 })
            label = tab.add({
                type = 'label',
                caption = 'Playtime [img=info]',
                tooltip = 'Amount of time actively on their team (fraction of time, since being picked, that the player is online and not spectating)',
                style = 'heading_3_label',
            })
            gui_style(label, { top_margin = 4, bottom_margin = 4 })
            label = tab.add({ type = 'label', caption = 'Status', style = 'heading_3_label' })
            gui_style(label, { top_margin = 4, bottom_margin = 4 })

            local now_tick = Functions.get_ticks_since_game_start()
            for _, player_name in pairs(sorted_players) do
                local info = player_info[player_name]
                local pick_duration = info.picked_at and (now_tick - info.picked_at) or 0
                local playtime_frac = pick_duration > 0 and info.playtime / pick_duration or 1
                label = tab.add({ type = 'label', caption = player_name, style = 'valid_mod_label' })
                label = tab.add({
                    type = 'label',
                    caption = Functions.team_name_with_color(info.force),
                    style = 'valid_mod_label',
                })
                label = tab.add({
                    type = 'label',
                    caption = info.picked_at and Functions.format_ticks_as_time(info.picked_at) or '',
                    style = 'valid_mod_label',
                })
                label = tab.add({
                    type = 'label',
                    caption = string_format(
                        '%s (%d%%)',
                        Functions.format_ticks_as_time(info.playtime),
                        100 * playtime_frac
                    ),
                    style = 'valid_mod_label',
                })
                label = tab.add({ type = 'label', caption = concat(info.status, ', '), style = 'valid_mod_label' })
            end
        else
            pick_flow.visible = false
        end
    end
end

function Public.update_captain_referee_gui(player, frame)
    if not frame then
        frame = Public.get_active_tournament_frame(player, 'captain_referee_gui')
    end
    if not (frame and frame.visible) then
        return
    end
    local special = global.special_games_variables.captain_mode
    local scroll = frame.scroll
    -- Technically this would be more efficient if we didn't do the full clear here, and
    -- instead made elements visible/invisible as needed. But this is simpler and I don't
    -- think that performance really matters.
    scroll.clear()

    -- if game hasn't started, and at least one captain isn't ready, show a button to force both captains to be ready
    if special.prepaPhase and special.initialPickingPhaseStarted and not special.pickingPhase then
        if #special.listTeamReadyToPlay < 2 then
            scroll.add({
                type = 'label',
                caption = 'Teams ready to play: ' .. concat(special.listTeamReadyToPlay, ', '),
            })
            local b = scroll.add({
                type = 'button',
                name = 'captain_force_captains_ready',
                caption = 'Force all captains to be ready',
                style = 'red_button',
            })
        end
    end

    local ticks_until_autopick = special.nextAutoPickTicks - Functions.get_ticks_since_game_start()
    if ticks_until_autopick < 0 then
        ticks_until_autopick = 0
    end
    local caption = special.pickingPhase and 'Players remaining to be picked' or 'Players waiting for next join poll'
    local l = scroll.add({
        type = 'label',
        caption = #special.listPlayers .. ' ' .. caption .. ': ' .. get_player_list_with_groups(),
        ', ',
    })
    l.style.single_line = false

    scroll.add({ type = 'label', caption = string_format('Next auto picking phase in %ds', ticks_until_autopick / 60) })
    if
        #special.listPlayers > 0
        and not special.pickingPhase
        and not special.prepaPhase
        and ticks_until_autopick > 0
    then
        local button = scroll.add({
            type = 'button',
            name = 'captain_start_join_poll',
            caption = 'Start poll for players to join the game (instead of waiting)',
        })
    end

    if #special.listPlayers > 0 and special.pickingPhase then
        local button = scroll.add({
            type = 'button',
            name = 'referee_force_picking_to_stop',
            caption = 'Force the current round of picking to stop (only useful if changing captains)',
            style = 'red_button',
        })
    end

    if special.prepaPhase and not special.initialPickingPhaseStarted then
        scroll.add({ type = 'label', caption = 'Captain volunteers: ' .. pretty_print_player_list(special.captainList) })
        -- turn listPlayers into a map for efficiency
        local players = {}
        for _, player in pairs(special.listPlayers) do
            players[player] = true
        end
        local spectators = {}
        for _, player in pairs(game.connected_players) do
            if not players[player.name] then
                insert(spectators, player.name)
            end
        end
        sort(spectators)
        scroll.add({ type = 'label', caption = string_format('Everyone else: ', concat(spectators, ' ,')) })
        ---@type LuaGuiElement
        local b = scroll.add({
            type = 'button',
            name = 'captain_force_end_event',
            caption = 'Cancel captains event',
            style = 'red_button',
        })
        b.style.font = 'heading-2'
        caption = 'Confirm captains and start the picking phase'
        local tooltip = ''
        if special.communityPickingMode then
            caption = 'Instantly assign players to teams (community pick mode)'
            tooltip = 'Requires enough players to have confirmed their community picks'
        end
        b = scroll.add({
            type = 'button',
            name = 'captain_start_initial_picking',
            caption = caption,
            style = 'confirm_button',
            enabled = ternary(special.communityPickingMode, have_enough_community_picks(), #special.captainList == 2),
            tooltip = tooltip,
        })
        b.style.font = 'heading-2'
        b.style.minimal_width = 540
        b.style.horizontal_align = 'center'
        for index, captain in ipairs(special.captainList) do
            b = scroll.add({
                type = 'button',
                name = 'captain_remove_captain_' .. tostring(index),
                caption = 'Remove ' .. captain .. ' as a captain',
                style = 'red_button',
                tags = { captain = captain },
            })
            b.style.font = 'heading-2'
        end
        scroll.add({
            type = 'switch',
            name = 'captain_enable_groups_switch',
            switch_state = special.captainGroupAllowed and 'left' or 'right',
            left_label_caption = 'Groups allowed',
            right_label_caption = 'Groups not allowed',
            enabled = not special.communityPickingMode,
        })

        local flow = scroll.add({ type = 'flow', direction = 'horizontal' })
        flow.add({ type = 'label', caption = string_format('Max players in a group (%d): ', special.groupLimit) })

        local slider = flow.add({
            type = 'slider',
            name = 'captain_group_limit_slider',
            minimum_value = 2,
            maximum_value = 5,
            value = special.groupLimit,
            discrete_slider = true,
        })
    end

    if special.prepaPhase and not special.initialPickingPhaseStarted then
        scroll.add({ type = 'label', caption = 'The below logic is used for the initial picking phase!' })
        scroll.add({
            type = 'label',
            caption = 'North will be the first (non-rejected) captain in the list of captain volunteers above.',
        })
    end
    for _, force in pairs({ 'north', 'south' }) do
        local flow = scroll.add({ type = 'flow', direction = 'horizontal', name = force })
        local favor = special.nextAutoPicksFavor[force]
        flow.add({
            type = 'label',
            caption = string_format('Favor %s with next picking phase preference %d times. ', force, favor),
        })
        local button = flow.add({ type = 'button', name = 'captain_favor_plus', caption = '+1' })
        gui_style(button, { width = 40, padding = -2 })
        if favor > 0 then
            button = flow.add({ type = 'button', name = 'captain_favor_minus', caption = '-1' })
            gui_style(button, { width = 40, padding = -2 })
        end
    end
    if not special.initialPickingPhaseStarted then
        scroll.add({
            type = 'switch',
            name = 'captain_community_picking_mode',
            switch_state = special.communityPickingMode and 'left' or 'right',
            left_label_caption = 'Community picking',
            right_label_caption = 'Captain picking',
        })
    end
end

function Public.update_captain_manager_gui(player, frame)
    if not frame then
        frame = Public.get_active_tournament_frame(player, 'captain_manager_gui')
    end
    if not (frame and frame.visible) then
        return
    end
    local special = global.special_games_variables.captain_mode
    local force_name = global.chosen_team[player.name]
    local button = nil
    frame.diff_vote_duration.visible = false
    frame.captain_is_ready.visible = false
    if special.prepaPhase and not table_contains(special.listTeamReadyToPlay, force_name) then
        frame.captain_is_ready.visible = true
        frame.captain_is_ready.caption = 'Team is Ready!'
        frame.captain_is_ready.style = 'green_button'
        if game.ticks_played < global.difficulty_votes_timeout then
            frame.diff_vote_duration.visible = true
            frame.diff_vote_duration.caption = {
                'captain.difficulty_vote_duration',
                math_floor((global.difficulty_votes_timeout - game.ticks_played) / 60),
            }
            frame.captain_is_ready.caption = 'Mark team as ready even though difficulty vote is ongoing!'
            frame.captain_is_ready.style = 'red_button'
        end
    end
    local throwScienceSetting = special.northEnabledScienceThrow
    if special.captainList[2] == player.name then
        throwScienceSetting = special.southEnabledScienceThrow
    end
    local caption = throwScienceSetting and 'Click to disable throwing science for the team'
        or 'Click to enable throwing science for the team'
    frame.captain_toggle_throw_science.caption = caption
    frame.throw_science_label.caption = 'Can anyone throw science ? : '
        .. (throwScienceSetting and '[color=green]YES[/color]' or '[color=red]NO[/color]')

    local tablePlayerListThrowAllowed = special.northThrowPlayersListAllowed
    if player.name == special.captainList[2] then
        tablePlayerListThrowAllowed = special.southThrowPlayersListAllowed
    end
    frame.trusted_to_throw_list_label.caption = 'List of players trusted to throw : '
        .. concat(tablePlayerListThrowAllowed, ' | ')
    local team_players = {}
    for name, force in pairs(global.chosen_team) do
        if force == force_name then
            insert(team_players, name)
        end
    end
    local allowed_team_players = {}
    for _, name in pairs(tablePlayerListThrowAllowed) do
        insert(allowed_team_players, name)
    end
    sort(team_players)
    insert(team_players, 1, 'Select Player')
    sort(allowed_team_players)
    insert(allowed_team_players, 1, 'Select Player')
    local t = frame.captain_manager_root_table
    update_dropdown(t.captain_add_trustlist_playerlist, team_players)
    update_dropdown(t.captain_remove_trustlist_playerlist, allowed_team_players)
    local t2 = frame.captain_manager_root_table_two
    local allow_kick = (not special.prepaPhase and special.captainKick)
    t2.visible = allow_kick

    if allow_kick then
        local dropdown = t2.captain_eject_playerlist
        update_dropdown(dropdown, team_players)
    end
end

function Public.update_captain_organization_gui(player, frame)
    CaptainTaskGroup.update_captain_organization_gui(player, frame)
end

function Public.update_captain_tournament_gui(player)
    local frame = Gui.get_left_element(player, 'captain_tournament_gui')
    if not frame then
        return
    end
    local menu = frame.flow.inner_frame.qbip.qbsp
    for _, data in pairs(tournament_pages) do
        local gui_name = data.name
        local action = cpt_ui_visibility[gui_name]
        if menu[gui_name] and action then
            menu[gui_name].visible = action(player)
        elseif not menu[gui_name] then
            error('Missing menu[' .. gui_name .. ']')
        else
            error('Missing cpt_ui_visibility[' .. gui_name .. ']')
        end
    end
end

function Public.update_all_captain_player_guis()
    if not global.special_games_variables.captain_mode then
        return
    end
    for _, player in pairs(game.connected_players) do
        Public.update_captain_player_gui(player)
        Public.update_captain_referee_gui(player)
        Public.update_captain_manager_gui(player)
        Public.update_captain_tournament_gui(player)
    end
end

-- == MISC ====================================================================
function Public.get_active_tournament_frame(player, frame_name)
    return player.gui.screen[frame_name]
end

function Public.generate(config, player)
    local refereeName = ternary(config.refereeName.text == '', player.name, config.refereeName.text)
    local autoTrustSystem = config.autoTrust.switch_state
    local captainCanKick = config.captainKickPower.switch_state
    local specialEnabled = config.specialEnabled.switch_state
    generate_captain_mode(refereeName, autoTrustSystem, captainCanKick, specialEnabled)
end

function Public.reset_special_games()
    if global.active_special_games.captain_mode then
        global.tournament_mode = false
    end
end

function Public.get_total_playtime_of_player(playerName)
    local playtime = 0
    local stats = global.special_games_variables.captain_mode.stats
    local playerPlaytimes = stats.playerPlaytimes
    if playerPlaytimes[playerName] then
        playtime = playerPlaytimes[playerName]
    end
    if stats.playerSessionStartTimes[playerName] then
        local sessionTime = Functions.get_ticks_since_game_start() - stats.playerSessionStartTimes[playerName]
        playtime = playtime + sessionTime
    end
    return playtime
end

function Public.captain_log_end_time_player(player)
    if
        global.special_games_variables.captain_mode ~= nil
        and not global.special_games_variables.captain_mode.prepaPhase
    then
        local stats = global.special_games_variables.captain_mode.stats
        if stats.playerSessionStartTimes[player.name] then
            local sessionTime = Functions.get_ticks_since_game_start() - stats.playerSessionStartTimes[player.name]
            if stats.playerPlaytimes[player.name] then
                stats.playerPlaytimes[player.name] = stats.playerPlaytimes[player.name] + sessionTime
            else
                stats.playerPlaytimes[player.name] = sessionTime
            end
            stats.playerSessionStartTimes[player.name] = nil
        end
    end
end

function Public.clear_gui_special()
    clear_gui_captain_mode()
end

function Public.captain_is_player_prohibited_to_throw(player)
    if global.active_special_games.captain_mode then
        local throwScienceSetting = global.special_games_variables.captain_mode.northEnabledScienceThrow
        local throwList = global.special_games_variables.captain_mode.northThrowPlayersListAllowed
        if player.force.name == 'south' then
            throwScienceSetting = global.special_games_variables.captain_mode.southEnabledScienceThrow
            throwList = global.special_games_variables.captain_mode.southThrowPlayersListAllowed
        end
        if throwScienceSetting == false and table_contains(throwList, player.name) == false then
            return true
        end
    end
    return false
end

-- == COMMANDS ================================================================

commands.add_command('replaceCaptainNorth', 'Referee can decide to change the captain of north team', function(cmd)
    safe_wrap_cmd(cmd, change_captain, cmd, 'north')
end)

commands.add_command('replaceCaptainSouth', 'Referee can decide to change the captain of south team', function(cmd)
    safe_wrap_cmd(cmd, change_captain, cmd, 'south')
end)

commands.add_command('replaceReferee', 'Admin or referee can decide to change the referee', function(cmd)
    if not cmd.player_index then
        return
    end
    local playerOfCommand = cpt_get_player(cmd.player_index)
    if not playerOfCommand then
        return
    end
    if not global.active_special_games.captain_mode then
        return playerOfCommand.print({ 'captain.cmd_only_captain_mode' }, Color.red)
    end
    if global.special_games_variables.captain_mode.prepaPhase then
        return playerOfCommand.print({ 'captain.cmd_only_after_prepa_phase' }, Color.red)
    end
    if
        global.special_games_variables.captain_mode.refereeName ~= playerOfCommand.name and not playerOfCommand.admin
    then
        return playerOfCommand.print({ 'captain.cmd_only_admin' }, Color.red)
    end

    if global.special_games_variables.captain_mode.refereeName == nil then
        return playerOfCommand.print('Something broke, no refereeName in the refereeName variable..', Color.red)
    end
    if cmd.parameter then
        local victim = cpt_get_player(cmd.parameter)
        if victim and victim.valid then
            if not victim.connected then
                return playerOfCommand.print('You can only use this command on a connected player.', Color.red)
            end

            local special = global.special_games_variables.captain_mode
            local refPlayer = cpt_get_player(special.refereeName)

            if refPlayer.gui.screen.captain_referee_gui then
                refPlayer.gui.screen.captain_referee_gui.destroy()
            end
            game.print({
                'captain.replace_referee_announcement',
                playerOfCommand.name,
                victim.name,
                special.refereeName,
            })
            special.refereeName = victim.name
            refPlayer = victim
            generate_vs_text_rendering()
            Public.update_all_captain_player_guis()
        else
            playerOfCommand.print('Invalid name', Color.warning)
        end
    else
        playerOfCommand.print('Usage: /replaceReferee <playerName>', Color.warning)
    end
end)

commands.add_command(
    'captainDisablePicking',
    'Convert to a normal game, disable captain event and tournament mode',
    function(cmd)
        if not cmd.player_index then
            return
        end
        local playerOfCommand = cpt_get_player(cmd.player_index)
        if not playerOfCommand then
            return
        end
        if not global.active_special_games.captain_mode then
            return playerOfCommand.print({ 'captain.cmd_only_captain_mode' }, Color.red)
        end
        if global.special_games_variables.captain_mode.prepaPhase then
            return playerOfCommand.print({ 'captain.cmd_only_after_prepa_phase' }, Color.red)
        end
        if
            global.special_games_variables.captain_mode.refereeName ~= playerOfCommand.name
            and not playerOfCommand.admin
        then
            return playerOfCommand.print({ 'captain.cmd_only_admin' }, Color.red)
        end

        if global.special_games_variables.captain_mode.refereeName == nil then
            return playerOfCommand.print('Something broke, no refereeName in the refereeName variable..', Color.red)
        end
        playerOfCommand.print('You disabled tournament mode and captain event, now players can freely join', Color.red)

        global.active_special_games.captain_mode = false
        global.tournament_mode = false
        game.print({ 'captain.disable_picking_announcement', playerOfCommand.name }, Color.green)
        clear_gui_captain_mode()
    end
)

commands.add_command('cpt-test-func', 'Run some test-only code for captains games', function(event)
    if game.is_multiplayer() then
        game.print(
            'This command is only for testing, and should only be run when there is exactly one player in the game.',
            Color.red
        )
        return
    end
    local refereeName = game.player.name
    local autoTrustSystem = 'left'
    local captainCanKick = 'left'
    local specialEnabled = 'left'
    generate_captain_mode(refereeName, autoTrustSystem, captainCanKick, specialEnabled)
    local special = global.special_games_variables.captain_mode
    special.test_players = {}
    special.test_mode = true
    for _, playerName in pairs({
        'alice',
        'bob',
        'charlie',
        'eve1',
        'eve2',
        'eve3',
        'fredrick_longname',
        'greg1',
        'greg2',
        'hilary',
        'iacob',
        'james',
        'kelly',
        'lana',
        'manny',
        'niles',
        'oratio',
        'pan',
        'quasil',
        'reidd',
        'sil',
        'tina',
        'ustav',
        'vince',
        'winny',
        'xetr',
        'yamal',
        'zin',
    }) do
        local group_name = ''
        if starts_with(playerName, 'eve') then
            group_name = '[cpt_eve]'
        end
        if starts_with(playerName, 'greg') then
            group_name = '[cpt_greg]'
        end
        special.test_players[playerName] = { name = playerName, tag = group_name, color = Color.white }
        insert(special.listPlayers, playerName)
    end
    special.player_info.alice = 'I am a test player'
    special.player_info.charlie = string.rep('This is a really long description. ', 5)
    special.minTotalPlaytimeToPlay = 0

    insert(special.captainList, game.player.name)
    insert(special.captainList, game.player.name)
    Public.update_all_captain_player_guis()
end)

-- == HANDLERS ================================================================
Event.on_nth_tick(300, every_5sec)
Event.add(defines.events.on_gui_click, on_gui_click)
Event.add(defines.events.on_gui_switch_state_changed, on_gui_switch_state_changed)
Event.add(defines.events.on_gui_text_changed, on_gui_text_changed)
Event.add(defines.events.on_gui_value_changed, on_gui_value_changed)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_player_left_game, on_player_left_game)
Event.add(defines.events.on_player_changed_force, on_player_changed_force)

return Public
