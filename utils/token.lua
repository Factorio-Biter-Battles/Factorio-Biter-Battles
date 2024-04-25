local Token = {}

local tokens = {}

local counter = 0

--- Assigns a unique id for the given var and LOCALLY stores the var.
-- This function cannot be called after on_init() or on_load() has run as that is a desync risk.
-- Typically this is used to register functions, so the id can be stored in the global table
-- instead of the function. This is becasue closures cannot be safely stored in the global table.
-- NOTE:
-- This function is mostly useless, because you can only store effectively immutable data that's loaded from code when the map/scenario is loaded for the first time.
-- In most cases you can drop its usage and refer to the "var" directly in code.
-- The only useful scenario: you need a unique serializable key to be stored in Factorio's persistent "global" - then this approach gives you a unique key that will be valid for the entire playthrough of the current map... until your code updates for the current game save and causes a SHIFT in values due to changing the order in which this function was called.
-- @param  var<any>
-- @return number the unique token for the variable.
function Token.register(var)
    if _LIFECYCLE == 8 then -- Runtime
        error('Calling Token.register after on_init() or on_load() has run is a desync risk.', 2)
    end

    counter = counter + 1

    tokens[counter] = var

    return counter
end
---Returns how many variables were stored locally so far.
---@return number
function Token.get_counter()
    return counter
end

---Returns locally stored variable
---@param token_id number
---@see Token.register
function Token.get(token_id)
    return tokens[token_id]
end

global.tokens = {}

---Stores a var to persist across save/load and returns the token it was saved under.
---This is different from Token.register and uses a different token namespace.
---@param var serializable Any type that's allowed inside Factorio's "global" table. Excludes functions; tables will lose their metatables on load/player join
---@return number
function Token.register_global(var)
    local c = #global.tokens + 1

    global.tokens[c] = var

    return c
end

---Returns the variable that was saved using Token.register_global
---@param token_id number A global token
---@return var serializable
function Token.get_global(token_id)
    return global.tokens[token_id]
end

---Sets the variable under token_id that was previously saved using Token.register_global
---@param token_id number A global token
---@param var serializable
function Token.set_global(token_id, var)
    global.tokens[token_id] = var
end

local uid_counter = 100

---Returns a unique, immutable ID on each call
---@return number
function Token.uid()
    uid_counter = uid_counter + 1

    return uid_counter
end

return Token
