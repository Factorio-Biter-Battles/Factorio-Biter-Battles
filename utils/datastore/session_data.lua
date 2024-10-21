local Global = require('utils.global')
local Game = require('utils.game')
local Token = require('utils.token')
local Task = require('utils.task')
local Server = require('utils.server')
local Event = require('utils.event')
local table = require('utils.table')

local set_timeout_in_ticks = Task.set_timeout_in_ticks
local session_data_set = 'sessions'
local session = {}
local online_track = {}
local trusted = {}
local settings = {
    nth_tick = 54000, --15min
}
local set_data = Server.set_data
local try_get_data = Server.try_get_data
local concat = table.concat

Global.register({
    session = session,
    online_track = online_track,
    trusted = trusted,
    settings = settings,
}, function(tbl)
    session = tbl.session
    online_track = tbl.online_track
    trusted = tbl.trusted
    settings = tbl.settings
end)

local Public = {}

local nth_tick_token = Token.register(function(data)
    local player = data.player
    if player and player.valid then
        Server.upload_time_played(player)
        Public.autotrust_player(player.name)
    end
end)

--- Uploads each connected players play time to the dataset
local function upload_data()
    local players = game.connected_players
    local count = 0
    for i = 1, #players do
        count = count + 1
        local player = players[i]
        local random_timing = count * 5
        set_timeout_in_ticks(random_timing, nth_tick_token, { player = player })
    end
end

-- Trust player automatically after a certain amount of times
function Public.autotrust_player(playerName)
    local playtimeRequiredForAutoTrust = 5184000 -- 24h
    if
        not trusted[playerName]
        and storage.total_time_online_players[playerName] ~= nil
        and storage.total_time_online_players[playerName] >= playtimeRequiredForAutoTrust
    then
        trusted[playerName] = true
    end
end

--- Prints out game.tick to real hour/minute
---@param int
function Public.format_time(ticks, h, m)
    local seconds = ticks / 60
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    local min = math.floor(minutes - 60 * hours)
    if h and m then
        return string.format('%dh:%02dm', hours, minutes, min)
    elseif h then
        return string.format('%dh', hours)
    elseif m then
        return string.format('%02dm', minutes, min)
    end
end
--- Returns the table of session
-- @return <table>
function Public.get_session_table()
    return session
end

--- Returns the table of trusted
-- @return <table>
function Public.get_trusted_table()
    return trusted
end

Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    Server.set_total_time_played(player)
    Public.autotrust_player(player.name)
end)

Event.add(defines.events.on_player_left_game, function(event)
    local player = game.get_player(event.player_index)
    if not player or not player.valid then
        return
    end
    Server.upload_time_played(player)
end)

Event.on_nth_tick(settings.nth_tick, upload_data)

return Public
