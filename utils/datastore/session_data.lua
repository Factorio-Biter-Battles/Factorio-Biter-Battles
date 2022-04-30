local Global = require 'utils.global'
local Game = require 'utils.game'
local Token = require 'utils.token'
local Task = require 'utils.task'
local Server = require 'utils.server'
local Event = require 'utils.event'
local table = require 'utils.table'

local set_timeout_in_ticks = Task.set_timeout_in_ticks
local session_data_set = 'sessions'
local session = {}
local online_track = {}
local trusted = {}
local settings = {
    -- local trusted_value = 2592000 -- 12h
    trusted_value = 5184000, -- 24h
    nth_tick = 18000 -- nearest prime to 5 minutes in ticks
}
local set_data = Server.set_data
local try_get_data = Server.try_get_data
local concat = table.concat

Global.register(
    {
        session = session,
        online_track = online_track,
        trusted = trusted,
        settings = settings
    },
    function(tbl)
        session = tbl.session
        online_track = tbl.online_track
        trusted = tbl.trusted
        settings = tbl.settings
    end
)

local Public = {}

local try_download_data =
    Token.register(
    function(data)
        local key = data.key
        local value = data.value
        if value then
            session[key] = value
            if value > settings.trusted_value then
                trusted[key] = true
            end
        else
            session[key] = 0
            trusted[key] = false
            set_data(session_data_set, key, session[key])
        end
    end
)

local try_upload_data =
    Token.register(
    function(data)
        local key = data.key
        local value = data.value
        local player = game.get_player(key)
        if value then
            local old_time_ingame = value

            if not online_track[key] then
                online_track[key] = 0
            end

            local new_time = old_time_ingame + player.online_time - online_track[key]
            if new_time <= 0 then
                new_time = old_time_ingame + player.online_time
                online_track[key] = 0
                print('[ERROR] ' .. key .. ' had new time set as negative value: ' .. new_time)
                return
            end
            set_data(session_data_set, key, new_time)
            session[key] = new_time
            online_track[key] = player.online_time
        end
    end
)

local nth_tick_token =
    Token.register(
    function(data)
        local player = data.player
        if player and player.valid then
            Public.try_ul_data(player.name)
        end
    end
)

--- Uploads each connected players play time to the dataset
local function upload_data()
    local players = game.connected_players
    local count = 0
    for i = 1, #players do
        count = count + 1
        local player = players[i]
        local random_timing = count * 5
        set_timeout_in_ticks(random_timing, nth_tick_token, {player = player})
    end
end

--- Prints out game.tick to real hour/minute
---@param int
function Public.format_time(ticks, h, m)
    local seconds = ticks / 60
    local minutes = math.floor((seconds) / 60)
    local hours = math.floor((minutes) / 60)
    local min = math.floor(minutes - 60 * hours)
    if h and m then
        return string.format('%dh:%02dm', hours, minutes, min)
    elseif h then
        return string.format('%dh', hours)
    elseif m then
        return string.format('%02dm', minutes, min)
    end
end

--- Tries to get data from the webpanel and updates the local table with values.
-- @param data_set player token
function Public.try_dl_data(key)
    key = tostring(key)
    local secs = Server.get_current_time()
    if secs == nil then
        session[key] = game.players[key].online_time
        return
    else
        try_get_data(session_data_set, key, try_download_data)
    end
end

--- Tries to get data from the webpanel and updates the local table with values.
-- @param data_set player token
function Public.try_ul_data(key)
    key = tostring(key)
    local secs = Server.get_current_time()
    if secs == nil then
        return
    else
        try_get_data(session_data_set, key, try_upload_data)
    end
end

--- Checks if a player exists within the table
-- @param player_name <string>
-- @return <boolean>
function Public.exists(player_name)
    return session[player_name] ~= nil
end

--- Prints a list of all players in the player_session table.
function Public.print_sessions()
    local result = {}

    for k, _ in pairs(session) do
        result[#result + 1] = k
    end

    result = concat(result, ', ')
    Game.player_print(result)
end

--- Returns the table of session
-- @return <table>
function Public.get_session_table()
    return session
end

--- Returns the table of online_track
-- @return <table>
function Public.get_tracker_table()
    return online_track
end

--- Returns the table of trusted
-- @return <table>
function Public.get_trusted_table()
    return trusted
end

--- Returns the table of settings
-- @return <table>
function Public.get_settings_table()
    return settings
end

--- Clears a given player from the session tables.
-- @param LuaPlayer
function Public.clear_player(player)
    local name = player.name
    if session[name] then
        session[name] = nil
    end
    if online_track[name] then
        online_track[name] = nil
    end
    if trusted[name] then
        trusted[name] = nil
    end
end

Event.add(
    defines.events.on_player_joined_game,
    function(event)
        local player = game.get_player(event.player_index)
        if not player or not player.valid then
            return
        end

        Public.try_dl_data(player.name)
    end
)

Event.add(
    defines.events.on_player_left_game,
    function(event)
        local player = game.get_player(event.player_index)
        if not player or not player.valid then
            return
        end

        Public.try_ul_data(player.name)
    end
)

Event.on_nth_tick(settings.nth_tick, upload_data)

Server.on_data_set_changed(
    session_data_set,
    function(data)
        session[data.key] = data.value
        if data.value > settings.trusted_value then
            trusted[data.key] = true
        else
            if trusted[data.key] then
                trusted[data.key] = false
            end
        end
    end
)

return Public
