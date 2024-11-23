local Server = require('utils.server')
local Color = require('utils.color_presets')
local Token = require('utils.token')
local Task = require('utils.task')
local Event = require('utils.event')
local Gui = require('utils.gui')
local gui_style = require('utils.utils').gui_style

---@return success_percent number [0-1] yes/total
---@return yes_count number
---@return no_count number
local function get_suspend_stats()
    local total_votes = table.size(storage.suspend_target_info.suspend_votes_by_player)
    if total_votes == 0 then
        return 0, 0, 0
    end

    local yes_votes = 0
    for _, vote in pairs(storage.suspend_target_info.suspend_votes_by_player) do
        yes_votes = yes_votes + vote
    end
    return math.floor(100 * yes_votes / total_votes), yes_votes, total_votes - yes_votes
end

---@param player LuaPlayer
local function draw_suspend_gui(player)
    if Gui.get_top_element(player, 'suspend_frame') then
        return
    end
    if storage.suspend_target_info == nil or storage.suspend_target_info.suspendee_player_name == player.name then
        return
    end

    local frame = Gui.add_top_element(player, { type = 'frame', name = 'suspend_frame', style = 'subheader_frame' })
    gui_style(frame, { minimal_height = 36, maximal_height = 36, padding = 0, vertical_align = 'center' })

    local f = frame.add({ type = 'flow', name = 'flow', direction = 'horizontal' })
    local line = f.add({ type = 'line', direction = 'vertical' })

    do -- buttons
        local t = f.add({ type = 'table', name = 'suspend_table', column_count = 3, vertical_centering = true })
        gui_style(t, { top_margin = 2, left_margin = 8, right_margin = 8 })

        local l = t.add({
            type = 'label',
            caption = {
                'gui.suspend_caption',
                storage.suspend_target_info.suspendee_player_name,
                storage.suspend_time_left,
            },
        })
        gui_style(l, {
            minimal_width = 120 + 6 * string.len(storage.suspend_target_info.suspendee_player_name),
            font_color = { r = 0.88, g = 0.55, b = 0.11 },
            font = 'heading-2',
        })

        local b = t.add({ type = 'sprite-button', caption = 'No', name = 'suspend_no', style = 'red_back_button' })
        gui_style(b, { minimal_width = 56, maximal_width = 56, font = 'heading-2' })

        local b = t.add({
            type = 'sprite-button',
            caption = 'Yes',
            name = 'suspend_yes',
            style = 'confirm_button_without_tooltip',
        })
        gui_style(b, { minimal_width = 56, maximal_width = 56, font = 'heading-2' })
    end

    local line = f.add({ type = 'line', direction = 'vertical' })

    do -- stats
        local percent, yes_votes, no_votes = get_suspend_stats()

        local l = f.add({
            type = 'label',
            name = 'suspend_stats',
            caption = { 'gui.suspend_stats', no_votes, yes_votes, percent },
        })
        gui_style(
            l,
            { font = 'heading-2', right_padding = 4, left_padding = 4, top_margin = 6, font_color = { 165, 165, 165 } }
        )
    end
end

local suspend_buttons_token = Token.register(
    -- create buttons for joining players
    function(event)
        local player = game.get_player(event.player_index)
        draw_suspend_gui(player)
        Sounds.notify_player(player, 'utility/new_objective')
    end
)

local function leave_corpse(player)
    if not player.character then
        return
    end

    local inventories = {
        player.character.get_inventory(defines.inventory.character_main),
        player.character.get_inventory(defines.inventory.character_guns),
        player.character.get_inventory(defines.inventory.character_ammo),
        player.character.get_inventory(defines.inventory.character_armor),
        player.character.get_inventory(defines.inventory.character_vehicle),
        player.character.get_inventory(defines.inventory.character_trash),
    }

    local corpse = false
    for _, i in pairs(inventories) do
        for index = 1, #i, 1 do
            if not i[index].valid then
                break
            end
            corpse = true
            break
        end
        if corpse then
            player.character.die()
            break
        end
    end

    if player.character then
        player.character.destroy()
    end
    player.character = nil
    player.set_controller({ type = defines.controllers.god })
    player.create_character()
end

local function punish_player(playerSuspended)
    if playerSuspended.controller_type ~= defines.controllers.character then
        playerSuspended.set_controller({
            type = defines.controllers.character,
            character = playerSuspended.surface.create_entity({
                name = 'character',
                force = playerSuspended.force,
                position = playerSuspended.position,
            }),
        })
    end
    if playerSuspended.controller_type == defines.controllers.character then
        leave_corpse(playerSuspended)
    end
    spectate(playerSuspended, false, false)
end

local suspend_token = Token.register(function()
    storage.suspend_token_running = false
    -- disable suspend buttons creation for joining players
    Event.remove_removable(defines.events.on_player_joined_game, suspend_buttons_token)
    -- remove existing buttons
    for _, player in pairs(game.players) do
        local frame = Gui.get_top_element(player, 'suspend_frame')
        if frame then
            frame.destroy()
        end
    end
    -- count votes
    local suspend_info = storage.suspend_target_info
    local result = 0
    if suspend_info ~= nil then
        local total_votes = table.size(suspend_info.suspend_votes_by_player)
        if total_votes > 0 then
            for _, vote in pairs(suspend_info.suspend_votes_by_player) do
                result = result + vote
            end
            result = math.floor(100 * result / total_votes)
            if result >= 75 and total_votes > 1 then
                game.print(suspend_info.suspendee_player_name .. ' suspended... (' .. result .. '%)')
                Server.to_banned_embed(table.concat({
                    suspend_info.suspendee_player_name
                        .. ' was suspended ( '
                        .. result
                        .. ' %)'
                        .. ', vote started by '
                        .. suspend_info.suspender_player_name,
                }))
                storage.suspended_players[suspend_info.suspendee_player_name] = game.ticks_played
                local playerSuspended = game.get_player(suspend_info.suspendee_player_name)
                storage.suspend_target_info = nil
                if playerSuspended and playerSuspended.valid and playerSuspended.surface.name ~= 'gulag' then
                    punish_player(playerSuspended)
                end
                return
            end
        end
        if total_votes == 1 and result == 100 then
            game.print(
                'Vote to suspend '
                    .. suspend_info.suspendee_player_name
                    .. ' has failed because only 1 player voted, need at least 2 votes'
            )
            Server.to_banned_embed(table.concat({
                suspend_info.suspendee_player_name
                    .. ' was not suspended and vote failed, only 1 player voted, need at least 2 votes, vote started by '
                    .. suspend_info.suspender_player_name,
            }))
        else
            game.print('Vote to suspend ' .. suspend_info.suspendee_player_name .. ' has failed (' .. result .. '%)')
            Server.to_banned_embed(table.concat({
                suspend_info.suspendee_player_name
                    .. ' was not suspended and vote failed ( '
                    .. result
                    .. ' %)'
                    .. ', vote started by '
                    .. suspend_info.suspender_player_name,
            }))
        end
        storage.suspend_target_info = nil
    end
end)

local decrement_timer_token = Token.get_counter() + 1 -- predict what the token will look like
decrement_timer_token = Token.register(function()
    local suspend_time_left = storage.suspend_time_left - 1
    for _, player in pairs(game.connected_players) do
        local frame = Gui.get_top_element(player, 'suspend_frame')
        if frame and frame.valid and storage.suspend_target_info ~= nil then
            frame.flow.suspend_table.children[1].caption =
                { 'gui.suspend_caption', storage.suspend_target_info.suspendee_player_name, storage.suspend_time_left }

            local percent, yes_votes, no_votes = get_suspend_stats()
            frame.flow.suspend_stats.caption = { 'gui.suspend_stats', no_votes, yes_votes, percent }
        end
    end
    if suspend_time_left > 0 and storage.suspend_target_info ~= nil then
        Task.set_timeout_in_ticks(60, decrement_timer_token)
        storage.suspend_time_left = suspend_time_left
    end
end)

---@param cmd CustomCommandData
local function suspend_player(cmd)
    if not cmd.player_index then
        return
    end
    local killer = game.get_player(cmd.player_index)
    if not killer then
        return
    end
    if storage.suspend_target_info then
        killer.print(
            'You cant suspend 2 players at same time, wait for previous vote to end',
            { color = Color.warning }
        )
        return
    end
    if cmd.parameter then
        local victim = game.get_player(cmd.parameter)
        if victim and victim.valid then
            if victim.force.name == 'spectator' then
                killer.print('You cant suspend a spectator', { color = Color.warning })
                return
            end
            if victim.surface.name == 'gulag' then
                killer.print('You cant suspend a player in jail', { color = Color.warning })
                return
            end
            if killer.surface.name == 'gulag' then
                killer.print('You cant suspend a player while you are in jail', { color = Color.warning })
                return
            end
            if storage.suspend_token_running then
                killer.print(
                    'A suspend was just started before restart, please wait 60s maximum to avoid bugs',
                    { color = Color.warning }
                )
                return
            end
            local victim_name = victim.name
            local killer_name = killer.name
            storage.suspend_target_info = {
                suspendee_player_name = victim_name,
                suspendee_force_name = victim.force.name,
                suspender_player_name = killer_name,
                target_force_name = victim.force.name,
                suspend_votes_by_player = { [killer_name] = 1 },
            }
            game.print(killer.name .. ' has started a vote to suspend ' .. victim_name .. ' , vote in top of screen')
            storage.suspend_token_running = true
            Task.set_timeout_in_ticks(storage.suspend_time_limit, suspend_token)
            Event.add_removable(defines.events.on_player_joined_game, suspend_buttons_token)
            storage.suspend_time_left = storage.suspend_time_limit / 60
            for _, player in pairs(game.connected_players) do
                draw_suspend_gui(player)
                Sounds.notify_all('utility/new_objective')
            end
            Task.set_timeout_in_ticks(60, decrement_timer_token)
        else
            killer.print('Invalid name', { color = Color.warning })
        end
    else
        killer.print('Usage: /suspend <name>', { color = Color.warning })
    end
end

commands.add_command(
    'suspend',
    'Force a player to stay in spectator for 10 minutes : /suspend playerName',
    function(cmd)
        suspend_player(cmd)
    end
)

local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    if
        storage.suspended_players[player.name]
        and (game.ticks_played - storage.suspended_players[player.name]) < storage.suspended_time
    then
        punish_player(player)
    end
end

Event.add(defines.events.on_player_joined_game, on_player_joined_game)
