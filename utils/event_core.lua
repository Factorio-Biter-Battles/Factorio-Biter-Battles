-- This module exists to break the circular dependency between event.lua and storage.lua.
-- It is not expected that any user code would require this module instead event.lua should be required.

local Public = {}

---Translate EventName (int) to file path (string)
---@type table<EventName, string>
local event_to_path = {}
for event_name, event_id in pairs(defines.events) do
    event_to_path[event_id] = "profiler/"..event_name..".txt"
end
---Translate WventNthtick (int) to file path (string)
---@type table<uint, string>
local nth_tick_to_path = {}

local init_event_name = -1
local load_event_name = -2

-- map of event_name to handlers[]
---@type table<EventName, fun(event: EventData)[]>
local event_handlers = {}

-- map of nth_tick to handlers[]
local on_nth_tick_event_handlers = {}

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

local function call_handlers_profiled(handlers, event)
    local event_name = event.name
    local game_tick = game.tick
    local path = event_to_path[event_name]
    for i = #handlers, 1, -1 do
        local profiler = helpers.create_profiler()
        xpcall(handlers[i], errorHandler, event)
        profiler.stop()
        -- conventionally there's only handler for event in each file, so short_scr is enough to identify a function
        helpers.write_file(path, {"", game_tick, "\t",debug_getinfo(handlers[i],"S").short_src, "\t", profiler, "\n"}, true, storage.profiler_new.player)
    end
end

local function call_nth_tick_handlers_profiled(handlers, event)
    local event_tick = event.nth_tick
    local game_tick = game.tick
    local path = nth_tick_to_path[event_tick]
    for i = #handlers, 1, -1 do
        local profiler = helpers.create_profiler()
        xpcall(handlers[i], errorHandler, event)
        profiler.stop()
        -- conventionally there's only handler for event in each file, so short_scr is enough to identify a function
        helpers.write_file(path, {"", game_tick, "\t",debug_getinfo(handlers[i],"S").short_src, "\t", profiler, "\n"}, true, storage.profiler_new.player)
    end
end

local function on_event(event)
    local handlers = event_handlers[event.name]
    if not handlers then
        handlers = event_handlers[event.input_name]
    end
    if storage.profiler_new.enabled then
        call_handlers_profiled(handlers, event)
    else
        call_handlers(handlers, event)
    end
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
    if storage.profiler_new.enabled then
        call_nth_tick_handlers_profiled(handlers, event)
    else
        call_handlers(handlers, event)
    end
end

--- Do not use this function, use Event.add instead as it has safety checks.
---@param event_name EventName
---@param handler fun(event: EventData)
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
    nth_tick_to_path[tick] = "profiler/"..tick ..".txt"
end

function Public.get_event_handlers()
    return event_handlers
end

function Public.get_on_nth_tick_event_handlers()
    return on_nth_tick_event_handlers
end

return Public