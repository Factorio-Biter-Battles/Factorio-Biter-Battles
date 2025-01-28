-- This module exists to break the circular dependency between event.lua and storage.lua.
-- It is not expected that any user code would require this module instead event.lua should be required.

local Public = {}

local init_event_name = -1
local load_event_name = -2

-- map of event_name to handlers[]
local event_handlers = {}
---@type table<defines.events, {profiler: LuaProfiler, count: int}>
local event_profilers = {}

-- map of nth_tick to handlers[]
local on_nth_tick_event_handlers = {}
---@type table<defines.events, {profiler: LuaProfiler, count: int}>
local on_nth_tick_event_profilers = {}
local event_names = {}
for k, v in pairs(defines.events) do
    event_names[v] = k
end

--[[ local interface = {
    get_handler = function()
        return event_handlers
    end
}

if not remote.interfaces['interface'] then
    remote.add_interface('interface', interface)
end ]]
local xpcall = xpcall
local debug_getinfo = debug.getinfo
local log = log
local script_on_event = script.on_event
local script_on_nth_tick = script.on_nth_tick

local function errorHandler(err)
    log('Error caught: ' .. err)
    -- Print the full stack trace
    log(debug.traceback())
end

-- loop backwards to allow handlers to safely self-remove themselves
local function call_handlers(handlers, event)
    for i = #handlers, 1, -1 do
        xpcall(handlers[i], errorHandler, event)
    end
end

local function on_event(event)
    local handlers = event_handlers[event.name]
    if not handlers then
        handlers = event_handlers[event.input_name]
    end
    local profiler = event_profilers[event.name]
    if not profiler then
        profiler = { profiler = game.create_profiler(), count = 1 }
        event_profilers[event.name] = profiler
    else
        profiler.profiler.restart()
        profiler.count = profiler.count + 1
    end
    call_handlers(handlers, event)
    profiler.profiler.stop()
end

local function on_init()
    _LIFECYCLE = 5 -- on_init
    local handlers = event_handlers[init_event_name]
    call_handlers(handlers)

    event_handlers[init_event_name] = nil
    event_handlers[load_event_name] = nil

    _LIFECYCLE = 8 -- Runtime
end

local function on_load()
    _LIFECYCLE = 6 -- on_load
    local handlers = event_handlers[load_event_name]
    call_handlers(handlers)

    event_handlers[init_event_name] = nil
    event_handlers[load_event_name] = nil

    _LIFECYCLE = 8 -- Runtime
end

local function on_nth_tick_event(event)
    local handlers = on_nth_tick_event_handlers[event.nth_tick]
    local profiler = on_nth_tick_event_profilers[event.nth_tick]
    if not profiler then
        profiler = { profiler = game.create_profiler(), count = 1 }
        on_nth_tick_event_profilers[event.nth_tick] = profiler
    else
        profiler.profiler.restart()
        profiler.count = profiler.count + 1
    end
    call_handlers(handlers, event)
    profiler.profiler.stop()
end

--- Do not use this function, use Event.add instead as it has safety checks.
function Public.add(event_name, handler)
    if event_name == defines.events.on_entity_damaged then
        error('on_entity_damaged is managed outside of the event framework.')
    end
    local handlers = event_handlers[event_name]
    if not handlers then
        event_handlers[event_name] = { handler }
        script_on_event(event_name, on_event)
    else
        table.insert(handlers, 1, handler)
        if #handlers == 1 then
            script_on_event(event_name, on_event)
        end
    end
end

--- Do not use this function, use Event.on_init instead as it has safety checks.
function Public.on_init(handler)
    local handlers = event_handlers[init_event_name]
    if not handlers then
        event_handlers[init_event_name] = { handler }
        script.on_init(on_init)
    else
        table.insert(handlers, 1, handler)
        if #handlers == 1 then
            script.on_init(on_init)
        end
    end
end

--- Do not use this function, use Event.on_load instead as it has safety checks.
function Public.on_load(handler)
    local handlers = event_handlers[load_event_name]
    if not handlers then
        event_handlers[load_event_name] = { handler }
        script.on_load(on_load)
    else
        table.insert(handlers, 1, handler)
        if #handlers == 1 then
            script.on_load(on_load)
        end
    end
end

--- Do not use this function, use Event.on_nth_tick instead as it has safety checks.
function Public.on_nth_tick(tick, handler)
    local handlers = on_nth_tick_event_handlers[tick]
    if not handlers then
        on_nth_tick_event_handlers[tick] = { handler }
        script_on_nth_tick(tick, on_nth_tick_event)
    else
        table.insert(handlers, 1, handler)
        if #handlers == 1 then
            script_on_nth_tick(tick, on_nth_tick_event)
        end
    end
end

function Public.get_event_handlers()
    return event_handlers
end

function Public.get_on_nth_tick_event_handlers()
    return on_nth_tick_event_handlers
end

local function update_profilers()
    local profiler
    for event_name, profiler in pairs(event_profilers) do
        log({ '', 'event_handlers[', event_names[event_name], ']: ', profiler.count, ' times, ', profiler.profiler })
    end
    for nth_tick, profiler in pairs(on_nth_tick_event_profilers) do
        log({ '', 'on_nth_tick_event_handlers[', nth_tick, ']: ', profiler.count, ' times, ', profiler.prfiler })
    end
    log('connected players: ' .. #game.connected_players .. ' game speed: ' .. game.speed)
    event_profilers = {}
    on_nth_tick_event_profilers = {}
end

Public.on_nth_tick(60 * 5, update_profilers)

return Public
