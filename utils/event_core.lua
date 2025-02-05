-- This module exists to break the circular dependency between event.lua and storage.lua.
-- It is not expected that any user code would require this module instead event.lua should be required.

local Public = {}

--- translate EventName (int) into string
--- example: defines.events.on_tick -> "on_tick"
---@type table<EventName, string>
local event_name_to_human_readable_name = {}
for event_name, event_id in pairs(defines.events) do
    event_name_to_human_readable_name[event_id] = event_name
end

--- path to log file for each handler
--- conventionally there's only one handler for given event per lua file, so one log file per lua file is sufficient
---example: event_handlers_paths[defines.events.on_tick][1] = 'profiler/on_tick/maps-biter_battles_v2-main.txt'
---@type table<EventName, string[]>
local event_handlers_paths = {}
---@param event_name EventName
---@param index integer?
function Public.remove_event_handler_path(event_name, index)
    if index then
        log({"","Removed \t ", table.remove(event_handlers_paths[event_name],index), " at index ", index})
    end
end
---example: nth_tick_event_handlers_paths[60][1] = 'profiler/on_60th_tick/maps-biter_battles_v2-main.txt'
---@type table<integer, string[]>
local nth_tick_event_handlers_paths = {}
function Public.remove_nth_tick_event_handler_path(tick, index)
    if index then
        log({"","Removed \t ", table.remove(nth_tick_event_handlers_paths[tick],index), " at index ", index})
    end
end
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
    local path = event_handlers_paths[event_name]
    for i = #handlers, 1, -1 do
        local profiler = helpers.create_profiler()
        xpcall(handlers[i], errorHandler, event)
        profiler.stop()
        
        helpers.write_file(path[i], {"", game_tick, "\t", profiler, "\n"}, true, storage.profiler_new.player)
    end
end

local function call_nth_tick_handlers_profiled(handlers, event)
    local event_tick = event.nth_tick
    local game_tick = game.tick
    local path = nth_tick_event_handlers_paths[event_tick]
    for i = #handlers, 1, -1 do
        local profiler = helpers.create_profiler()
        xpcall(handlers[i], errorHandler, event)
        profiler.stop()
        helpers.write_file(path[i], {"", game_tick,  "\t", profiler, "\n"}, true, storage.profiler_new.player)
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

    --- save profiler log location for this handler
    if not event_handlers_paths[event_name] then event_handlers_paths[event_name] = {} end
    local info = debug_getinfo(handler, "S")
    table.insert(
        event_handlers_paths[event_name], 
        1, 
        table.concat{
            "profiler/", 
            event_name_to_human_readable_name[event_name], 
            "/",
            string.gsub(string.sub(info.short_src, 11, -5), "/", "-"),
            "@",
            info.linedefined,
            ".txt"
        }
    )
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

    if not nth_tick_event_handlers_paths[tick] then nth_tick_event_handlers_paths[tick] = {} end
    local info = debug_getinfo(handler, "S")
    table.insert(
        nth_tick_event_handlers_paths[tick], 
        1, 
        table.concat{
            "profiler/on_", 
            tick, 
            "th_tick/",
            string.gsub(string.sub(info.short_src, 11, -5), "/", "-"),
            "@",
            info.linedefined,
            ".txt"
        }
    )
end

function Public.get_event_handlers()
    return event_handlers
end

function Public.get_on_nth_tick_event_handlers()
    return on_nth_tick_event_handlers
end

return Public