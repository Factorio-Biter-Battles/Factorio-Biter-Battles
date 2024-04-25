local Event = require 'utils.event_core'
local Token = require 'utils.token'

local Global = {}
local concat = table.concat

local names = {}
Global.names = names

---Registers a function persistently for the `on_load` event (loading from a saved game).
---@see EventData.on_load
---@param tbl table Data-only table that will be persistently stored in `global` using given token.
---@param callback fun(registered_as_token: number)
function Global.register(tbl, callback)
    if _LIFECYCLE ~= _STAGE.control then
        error('can only be called during the control stage', 2)
    end

    local filepath = debug.getinfo(2, 'S').source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
    local token = Token.register_global(tbl)

    names[token] = concat {token, ' - ', filepath}

    Event.on_load(
        function()
            callback(Token.get_global(token))
        end
    )

    return token
end

---Registers a function persistently for the `on_load` event (loading from a saved game) and `on_init` (when started for the first time).
---Otherwise identical to Global.register
---@see EventData.on_load
---@see EventData.on_init
---@param tbl table Data-only table that will be persistently stored in `global` using given token.
---@param init_handler fun(tbl: table)
---@param callback fun(registered_as_token: number) | fun(tbl: table) # in on_init, both functions will receive the passed tbl table
function Global.register_init(tbl, init_handler, callback)
    if _LIFECYCLE ~= _STAGE.control then
        error('can only be called during the control stage', 2)
    end
    local filepath = debug.getinfo(2, 'S').source:match('^.+/currently%-playing/(.+)$'):sub(1, -5)
    local token = Token.register_global(tbl)

    names[token] = concat {token, ' - ', filepath}

    Event.on_init(
        function()
            init_handler(tbl)
            callback(tbl)
        end
    )

    Event.on_load(
        function()
            callback(Token.get_global(token))
        end
    )

    return token
end

return Global
