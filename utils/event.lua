---luacheck: globals script
---
---This Module allows for registering multiple handlers to the same event, overcoming the limitation of script.register.
---
---To create custom events, use script.generate_event_name and use its return value as an event name.
---To raise that event, use script.raise_event

local EventCore = require('utils.event_core')
local Global = require('utils.global')
local Token = require('utils.token')

local table_remove = table.remove
local core_add = EventCore.add
local core_on_init = EventCore.on_init
local core_on_load = EventCore.on_load
local core_on_nth_tick = EventCore.on_nth_tick
local stage_load = _STAGE.load
local script_on_event = script.on_event
local script_on_nth_tick = script.on_nth_tick
local generate_event_name = script.generate_event_name

local Event = {}

local handlers_added = false -- set to true after the removable event handlers have been added.

---@alias EventName defines.events | int

---@type { [EventName]: { handler: fun(), priority: number }[] }
local event_handlers = EventCore.get_event_handlers()

---@type { [int]: { handler: fun(), priority: number }[] }
local on_nth_tick_event_handlers = EventCore.get_on_nth_tick_event_handlers()

---@type { [EventName]: { token: int, priority: number }[] }
local token_handlers = {}

---@type { [int]: { token: int, priority: number }[] }
local token_nth_tick_handlers = {}

---@type { [string]: { event_name: EventName, func_string: string, handler: fun(), priority: number }[] }
local function_handlers = {}

---@type { [string]: { tick: int, func_string: string, handler: fun(), priority: number }[] }
local function_nth_tick_handlers = {}

---@type int
local removable_function_uid = 0

Global.register({
    token_handlers = token_handlers,
    token_nth_tick_handlers = token_nth_tick_handlers,
    function_handlers = function_handlers,
    function_nth_tick_handlers = function_nth_tick_handlers,
    removable_function_uid = removable_function_uid,
}, function(tbl)
    token_handlers = tbl.token_handlers
    token_nth_tick_handlers = tbl.token_nth_tick_handlers
    function_handlers = tbl.function_handlers
    function_nth_tick_handlers = tbl.function_nth_tick_handlers
    removable_function_uid = tbl.removable_function_uid
end)

---@param tbl { handler: fun() }[] | { token: int }[]
---@param v fun() | int
local function remove(tbl, v)
    if tbl == nil then
        return
    end

    -- the handler we are looking for is more likely to be at the back of the array.
    for i = #tbl, 1, -1 do
        if tbl[i].handler == v or tbl[i].token == v then
            table_remove(tbl, i)
            break
        end
    end
end

---Register a handler for the event_name event, can only be used during control, init or load cycles.</br>
---Handlers added with Event.add cannot be removed.</br>
---For handlers that need to be removed or added at runtime use Event.add_removable.
---@param event_name EventName
---@param handler fun(event: EventData)
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.add(event_name, handler, priority)
    if _LIFECYCLE == 8 then -- Runtime
        error('Calling Event.add after on_init() or on_load() has run is a desync risk.', 2)
    end

    core_add(event_name, handler, priority)
end

---Register a handler for the on_init event, can only be used during control, init or load cycles.</br>
---Remember that for each player, on_init or on_load is run, never both. So if you can't add the handler in the
---control stage add the handler in both on_init and on_load.
---@param handler fun()
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.on_init(handler, priority)
    if _LIFECYCLE == 8 then -- Runtime
        error('Calling Event.on_init after on_init() or on_load() has run is a desync risk.', 2)
    end

    core_on_init(handler, priority)
end

---Register a handler for the on_load event, can only be used during control, init or load cycles.</br>
---Remember that for each player, on_init or on_load is run, never both. So if you can't add the handler in the
---control stage add the handler in both on_init and on_load.
---@param handler fun()
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.on_load(handler, priority)
    if _LIFECYCLE == 8 then -- Runtime
        error('Calling Event.on_load after on_init() or on_load() has run is a desync risk.', 2)
    end

    core_on_load(handler, priority)
end

---Register a handler for the on_nth_tick event, can only be used during control, init or load cycles.</br>
---@param tick int The handler will be called every nth tick
---@param handler fun(event: NthTickEventData)
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.on_nth_tick(tick, handler, priority)
    if _LIFECYCLE == 8 then -- Runtime
        error('Calling Event.on_nth_tick after on_init() or on_load() has run is a desync risk.', 2)
    end

    core_on_nth_tick(tick, handler, priority)
end

---For conditional event handlers. Event.add_removable can be safely called at runtime without desync risk.
---Only use this if you need to add the handler at runtime or need to remove the handler, otherwise use Event.add
---
---Event.add_removable can be safely used at the control stage or in Event.on_init.
---If used in on_init you don't need to also add in on_load (unlike Event.add).
---Event.add_removable cannot be called in on_load, doing so will crash the game on loading.
---Token is used because it's a desync risk to store closures inside the global table.
---
---@usage
---local Token = require 'utils.token'
---local Event = require 'utils.event'
---
---Token.register must not be called inside an event handler.
---local handler =
---    Token.register(
---    function(event)
---        game.print(serpent.block(event)) -- prints the content of the event table to console.
---    end
---)
---
---The below code would typically be inside another event or a custom command.
---Event.add_removable(defines.events.on_built_entity, handler)
---
---When you no longer need the handler.
---Event.remove_removable(defines.events.on_built_entity, handler)
---
---It's not an error to register the same token multiple times to the same event, however when
---removing only the first occurrence is removed.
---@param event_name EventName
---@param token int
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.add_removable(event_name, token, priority)
    if not priority then priority = 0 end
    if type(token) ~= 'number' then
        error('token must be a number', 2)
    end
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end

    local tokens = token_handlers[event_name]
    if not tokens then
        token_handlers[event_name] = {{ token = token, priority = priority }}
    else
        tokens[#tokens + 1] = { token = token, priority = priority }
    end

    if handlers_added then
        local handler = Token.get(token)
        core_add(event_name, handler, priority)
    end
end

---Removes a token handler for the given event_name previously registered with Event.add_removable.
---Do NOT call this method during on_load.
---@param event_name EventName
---@param token int
function Event.remove_removable(event_name, token)
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end
    local tokens = token_handlers[event_name]

    if not tokens then
        return
    end

    local handler = Token.get(token)
    local handlers = event_handlers[event_name]

    remove(tokens, token)
    remove(handlers, handler)

    if #handlers == 0 then
        script_on_event(event_name, nil)
    end
end

---Only use this function if you can't use Event.add_removable. i.e you are registering the handler at the console.
---Register a handler that can be safely added and removed at runtime, cannot be used during on_load.
-- The same restrictions that apply to Event.add_removable also apply to Event.add_removable_function.
---
---The second parameter (func) has to be a function contained inside a string.
---This is necessary for the scenario to be multiplayer and save/load safe.
---func cannot be a closure, as there is no safe way to store closures in the global table.
---A closure is a function that uses a local variable not defined in the function.
---
---The third parameter is used to remove the function later.
---It can either be a string, in which case the function will be removed
---when Event.remove_removable_function is called with that name,
---or it can be an event name, in which case, the function will be removed on that event.
---
---The first option should NOT be used (unless it is necessary)
---as the function may not be removed because of a coding mistake
---(for example because of a spelling mistake of the name), as it has already happened.
---Nevertheless I didn't removed this option so that we don't have to rewrite all current specials.
---@overload fun(event_name: EventName, func: string, name: string)
---@overload fun(event_name: EventName, func: string, remove_event_name: EventName)
---@param event_name EventName
---@param func_string string
---@param remove_token string | EventName
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.add_removable_function(event_name, func_string, remove_token, priority)
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end

    if not event_name or not func_string or not remove_token then
        return
    end
    if not priority then priority = 0 end

    local name = remove_token
    if type(remove_token) ~= 'string' then
        local remove_event_name = remove_token
        removable_function_uid = removable_function_uid + 1
        name = tostring(removable_function_uid)

        Event.add_removable_function(
            remove_event_name,
            'function()'
                .. 'local Event = require("utils.event")'
                .. 'Event.remove_removable_function('
                .. event_name
                .. ', "'
                .. name
                .. '")'
                .. 'Event.remove_removable_function('
                .. remove_event_name
                .. ', "'
                .. name
                .. '")'
                .. 'end',
            name
        )
    end
    ---@cast name string

    local handler = assert(load('return ' .. func_string))()

    if type(handler) ~= 'function' then
        error('func must be a function contained in a string.', 2)
    end

    local funcs = function_handlers[name]
    if not funcs then
        function_handlers[name] = {}
        funcs = function_handlers[name]
    end

    funcs[#funcs + 1] = { event_name = event_name, func_string = func_string, handler = handler, priority = priority }

    if handlers_added then
        core_add(event_name, handler, priority)
    end
end

---Removes a handler previously registered with Event.add_removable_function for the given event_name and name.
---Do NOT call this method during on_load.
---@param event_name EventName
---@param name string
function Event.remove_removable_function(event_name, name)
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end

    if not event_name or not name then
        return
    end

    local funcs = function_handlers[name]

    if not funcs then
        return
    end

    local handlers = event_handlers[event_name]

    for k, v in pairs(funcs) do
        local n = v.event_name
        if n == event_name then
            funcs[k] = nil
            remove(handlers, v.handler)
        end
    end

    if #handlers == 0 then
        script_on_event(event_name, nil)
    end

    if #funcs == 0 then
        function_handlers[name] = nil
    end
end

---See Event.add_removable comments
---@param tick int
---@param token int
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.add_removable_nth_tick(tick, token, priority)
    if not priority then priority = 0 end
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end
    if type(token) ~= 'number' then
        error('token must be a number', 2)
    end

    local tokens = token_nth_tick_handlers[tick]
    if not tokens then
        token_nth_tick_handlers[tick] = {{ token = token, priority = priority }}
    else
        tokens[#tokens + 1] = { token = token, priority = priority }
    end

    if handlers_added then
        local handler = Token.get(token)
        core_on_nth_tick(tick, handler, priority)
    end
end

---See Event.remove_removable comments
---@param tick int
---@param token int
function Event.remove_removable_nth_tick(tick, token)
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end
    local tokens = token_nth_tick_handlers[tick]

    if not tokens then
        return
    end

    local handler = Token.get(token)
    local handlers = on_nth_tick_event_handlers[tick]

    remove(tokens, token)
    remove(handlers, handler)

    if #handlers == 0 then
        script_on_nth_tick(tick, nil)
    end
end

---see Event.add_removable_function comment.
---@overload fun(tick: int, func: string, name: string)
---@overload fun(tick: int, func: string, remove_event_name: EventName)
---@param tick int
---@param func_string string
---@param remove_token string | EventName
---@param priority number? -- Handlers with the hightest priority are always called first, can be negative. Defaults to 0.
function Event.add_removable_nth_tick_function(tick, func_string, remove_token, priority)
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end

    if not tick or not func_string or not remove_token then
        return
    end
    if not priority then priority = 0 end

    local name = remove_token
    if type(remove_token) ~= 'string' then
        local remove_event_name = remove_token
        removable_function_uid = removable_function_uid + 1
        name = tostring(removable_function_uid)

        Event.add_removable_function(
            remove_event_name,
            'function()'
                .. 'local Event = require("utils.event")'
                .. 'Event.remove_removable_nth_tick_function('
                .. tick
                .. ', "'
                .. name
                .. '")'
                .. 'Event.remove_removable_function('
                .. remove_event_name
                .. ', "'
                .. name
                .. '")'
                .. 'end',
            name
        )
    end
    ---@cast name string

    local handler = assert(load('return ' .. func_string))()

    if type(handler) ~= 'function' then
        error('func must be a function contained in a string.', 2)
    end

    local funcs = function_nth_tick_handlers[name]
    if not funcs then
        function_nth_tick_handlers[name] = {}
        funcs = function_nth_tick_handlers[name]
    end

    funcs[#funcs + 1] = { tick = tick, func_string = func_string, handler = handler, priority = priority }

    if handlers_added then
        core_on_nth_tick(tick, handler, priority)
    end
end

---See Event.remove_removable_function comments
---@param tick int
---@param name string
function Event.remove_removable_nth_tick_function(tick, name)
    if _LIFECYCLE == stage_load then
        error('cannot call during on_load', 2)
    end

    if not tick or not name then
        return
    end

    local funcs = function_nth_tick_handlers[name]

    if not funcs then
        return
    end

    local handlers = on_nth_tick_event_handlers[tick]

    for k, v in pairs(funcs) do
        local t = v.tick
        if t == tick then
            funcs[k] = nil
            remove(handlers, v.handler)
        end
    end

    if #funcs == 0 then
        function_nth_tick_handlers[name] = nil
    end

    if #handlers == 0 then
        script_on_nth_tick(tick, nil)
    end
end

--- Generate a new, unique event ID.
-- @param <string> name of the event/variable that is exposed
function Event.generate_event_name(name)
    local event_id = generate_event_name()

    return event_id
end

function Event.on_configuration_changed(func)
    if type(func) == 'function' then
        script.on_configuration_changed(func)
    end
end

function Event.add_event_filter(event, filter)
    local current_filters = script.get_event_filter(event)

    if not current_filters then
        current_filters = { filter }
    else
        table.insert(current_filters, filter)
    end

    script.set_event_filter(event, current_filters)
end

local function add_handlers()
    for event_name, tokens in pairs(token_handlers) do
        for i = 1, #tokens do
            local handler = Token.get(tokens[i].token)
            core_add(event_name, handler, tokens[i].priority)
        end
    end

    for name, funcs in pairs(function_handlers) do
        for i, func in pairs(funcs) do
            local e_name = func.event_name
            local func_string = func.func_string
            local handler = assert(load('return ' .. func_string))()
            func.handler = handler
            core_add(e_name, handler, func.priority)
        end
    end

    for tick, tokens in pairs(token_nth_tick_handlers) do
        for i = 1, #tokens do
            local handler = Token.get(tokens[i].token)
            core_on_nth_tick(tick, handler, tokens[i].priority)
        end
    end

    for name, funcs in pairs(function_nth_tick_handlers) do
        for i, func in pairs(funcs) do
            local tick = func.tick
            local func_string = func.func_string
            local handler = assert(load('return ' .. func_string))()
            func.handler = handler
            core_on_nth_tick(tick, handler, func.priority)
        end
    end

    handlers_added = true
end

core_on_init(add_handlers)
core_on_load(add_handlers)

return Event
