local Event = require('utils.event_core')
local Token = require('utils.token')

local Global = {}
local concat = table.concat

local names = {}
Global.names = names

function Global.register(tbl, callback)
    if _LIFECYCLE ~= _STAGE.control then
        error('can only be called during the control stage', 2)
    end

    local filepath = debug.getinfo(2, 'S').source:match('^@__level__/(.+)$'):sub(1, -5)
    local token = Token.register_global(tbl)

    names[token] = concat({ token, ' - ', filepath })

    Event.on_load(function()
        callback(Token.get_global(token))
    end)

    return token
end

function Global.register_init(tbl, init_handler, callback)
    if _LIFECYCLE ~= _STAGE.control then
        error('can only be called during the control stage', 2)
    end
    local filepath = debug.getinfo(2, 'S').source:match('^@__level__/(.+)$'):sub(1, -5)
    local token = Token.register_global(tbl)

    names[token] = concat({ token, ' - ', filepath })

    Event.on_init(function()
        init_handler(tbl)
        callback(tbl)
    end)

    Event.on_load(function()
        callback(Token.get_global(token))
    end)

    return token
end

return Global
