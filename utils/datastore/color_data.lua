local Token = require('utils.token')
local Color = require('utils.color_presets')
local Server = require('utils.server')
local Event = require('utils.event')

local color_data_set = 'colors'
local set_data = Server.set_data
local try_get_data = Server.try_get_data

local Public = {}

local color_table = {
    default = {},
    red = {},
    green = {},
    blue = {},
    orange = {},
    yellow = {},
    pink = {},
    purple = {},
    white = {},
    black = {},
    gray = {},
    brown = {},
    cyan = {},
    acid = {},
}

local fetch = Token.register(function(data)
    local key = data.key
    local value = data.value
    local player = game.get_player(key)
    if not player then
        return
    end
    if value then
        player.color = value.color[1]
        player.chat_color = value.chat[1]
    end
end)

--- Tries to get data from the webpanel and applies the value to the player.
-- @param data_set player token
function Public.fetch(key)
    local secs = Server.get_current_time()
    if secs == nil then
        return
    else
        try_get_data(color_data_set, key, fetch)
    end
end

local fetcher = Public.fetch

Event.add(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not player then
        return
    end

    fetcher(player.name)
end)

Event.add(defines.events.on_console_command, function(event)
    local player_index = event.player_index
    if not player_index or event.command ~= 'color' then
        return
    end

    local player = game.get_player(player_index)
    if not player or not player.valid then
        return
    end

    local secs = Server.get_current_time()
    if not secs then
        return
    end

    local param = event.parameters
    local color = player.color
    local chat = player.chat_color
    param = string.lower(param)
    if param then
        for word in param:gmatch('%S+') do
            if color_table[word] then
                set_data(color_data_set, player.name, { color = { color }, chat = { chat } })
                player.print('Your color has been saved.', Color.success)
                return true
            end
        end
    end
end)

return Public
