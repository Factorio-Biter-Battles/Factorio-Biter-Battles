local Color = require('utils.color_presets')
local ComfyPanelGroup = require('comfy_panel.group')
local Functions = require('maps.biter_battles_v2.functions')
local player_utils = require('utils.player')
local Session = require('utils.datastore.session_data')
local starts_with = require('utils.string').starts_with
local Table = require('utils.table')
local TeamManager = require('maps.biter_battles_v2.team_manager')
local insert, concat, contains = table.insert, table.concat, Table.contains
local table_remove_element = Table.remove_element

local CaptainUtils = {}

local get_special = function()
    return storage.special_games_variables.captain_mode
end
CaptainUtils.get_special = get_special

---@param playerName string
function CaptainUtils.add_to_trust(playerName)
    local special = get_special()
    if special and special.autoTrust then
        local trusted = Session.get_trusted_table()
        if not trusted[playerName] then
            trusted[playerName] = true
        end
    end
end

---@param playerName string
function CaptainUtils.add_to_playerList(playerName)
    local special = get_special()
    if not special then
        return
    end
    if contains(special.listPlayers, playerName) then
        return
    end
    insert(special.listPlayers, playerName)
end

---@param playerName string
function CaptainUtils.remove_from_playerList(playerName)
    local special = get_special()
    if not special then
        return
    end
    table_remove_element(special.listPlayers, playerName)
end

---@param player LuaPlayer
---@return boolean
function CaptainUtils.check_if_enough_playtime_to_play(player)
    local special = get_special()
    if not special then
        return true
    end
    return (storage.total_time_online_players[player.name] or 0) >= (special.minTotalPlaytimeToPlay or 0)
end

---@param playerName string|integer
---@return LuaPlayer?
function CaptainUtils.cpt_get_player(playerName)
    if not playerName then
        return nil
    end
    local special = get_special()
    if special and special.test_players and special.test_players[playerName] then
        local res = table.deepcopy(special.test_players[playerName])
        res.print = function(msg, options)
            game.print({ '', { 'info.dummy_print', playerName }, msg }, options)
        end
        res.force = { name = (storage.chosen_team[playerName] or 'spectator') }
        return res
    end
    return game.get_player(playerName)
end

function CaptainUtils.is_it_automatic_captain()
    local special = get_special()
    return special and (special.refereeName == '$@BotReferee')
end

function CaptainUtils.is_player_the_referee(playerName)
    local special = get_special()
    return (special and special.refereeName == playerName) or false
end

---@param player string
---@return boolean
function CaptainUtils.is_player_a_captain(playerName)
    local special = get_special()
    return (special ~= nil) and (special.captainList[1] == playerName or special.captainList[2] == playerName)
end

---@param playerName string
---@return boolean
function CaptainUtils.is_player_in_group_system(playerName)
    -- function used to balance team when a team is picked
    local special = get_special()
    if sspecial and special.captainGroupAllowed then
        local playerChecked = CaptainUtils.cpt_get_player(playerName)
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

---@param player LuaPlayer
---@return boolean
function CaptainUtils.is_test_player(player)
    return not player.gui
end

---@param player_name string
---@return boolean
function CaptainUtils.is_test_player_name(player_name)
    local special = get_special()
    return special.test_players and special.test_players[player_name]
end

---@param player string
---@return boolean
function CaptainUtils.player_has_captain_authority(player)
    local special = get_special()
    local force_name = storage.chosen_team[player]
    if force_name ~= 'north' and force_name ~= 'south' then
        return false
    end
    return special.captainList[1] == player
        or special.captainList[2] == player
        or special.viceCaptains[force_name][player]
end

---@param names string[]
---@return string
function CaptainUtils.pretty_print_player_list(names)
    return concat(player_utils.get_colored_player_list(player_utils.get_lua_players_from_player_names(names)), ', ')
end

---@param playerName string
---@param playerForceName string
function CaptainUtils.switch_team_of_player(playerName, playerForceName)
    if storage.chosen_team[playerName] then
        if storage.chosen_team[playerName] ~= playerForceName then
            game.print(
                { 'captain.change_player_team_err', playerName, storage.chosen_team[playerName], playerForceName },
                { color = Color.red }
            )
        end
        return
    end

    local special = get_special()
    local player = CaptainUtils.cpt_get_player(playerName)
    if special and (not player or CaptainUtils.is_test_player(player) or not player.connected) then
        storage.chosen_team[playerName] = playerForceName
    else
        TeamManager.switch_force(playerName, playerForceName)
    end

    local forcePickName = playerForceName .. 'Picks'
    if special then
        insert(special.stats[forcePickName], playerName)
        if not special.playerPickedAtTicks[playerName] then
            special.playerPickedAtTicks[playerName] = Functions.get_ticks_since_game_start()
        end
    end
    CaptainUtils.add_to_trust(playerName)
end

return CaptainUtils
