-- This module exists to break the circular dependency between event.lua and global.lua.
-- It is not expected that any user code would require this module instead event.lua should be required.

local Public = {}

local init_event_name = -1
local load_event_name = -2

---@type { [EventName]: { handler: fun(), priority: number }[] }
local event_handlers = {}

---@type { [int]: { handler: fun(), priority: number }[] }
local on_nth_tick_event_handlers = {}

--[[ local interface = {
    get_handler = function()
        return event_handlers
    end
}

if not remote.interfaces['interface'] then
    remote.add_interface('interface', interface)
end ]]
local pcall = pcall
local debug_getinfo = debug.getinfo
local log = log
local script_on_event = script.on_event
local script_on_nth_tick = script.on_nth_tick

local function errorHandler(err)
    log('Error caught: ' .. err)
    -- Print the full stack trace
    log(debug.traceback())
end

---@param handlers { handler: fun(...: any), priority: number }[]
---@param event any
local function call_handlers(handlers, event)
	if not handlers then
		return log('Handlers was nil!')
	end
	local handlers_copy = table.deepcopy(handlers)
	for i = 1, #handlers_copy do
		local handler = handlers_copy[i]
		if handler ~= nil then
			xpcall(handler.handler, errorHandler, event)
		else
			log('nil handler')
		end
	end
end

local function on_event(event)
    local handlers = event_handlers[event.name]
    if not handlers then
        handlers = event_handlers[event.input_name]
    end
    call_handlers(handlers, event)
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
    call_handlers(handlers, event)
end

---A binary search that sorts in reversed order (highest first, lower last).
---It also doesn't stop when the index is found to ensure that
---handlers with the same priority will be called in order of insertion.
---@param handlers { priority: number }[]
---@param target number
---@return int
local function priority_binary_search(handlers, target)
    local lower = 1
    local upper = #handlers

    while lower <= upper do
        local i = math.floor((lower + upper) / 2)
        if target > handlers[i].priority then
            upper = i - 1
        else
            lower = i + 1
        end
    end

    return lower
end

---Do not use this function, use Event.add instead as it has safety checks.
---@param event_name EventName
---@param handler fun(event: EventData)
---@param priority number?
function Public.add(event_name, handler, priority)
    if not priority then priority = 0 end
    if event_name == defines.events.on_entity_damaged then
        error('on_entity_damaged is managed outside of the event framework.')
    end
    local handlers = event_handlers[event_name]
    if not handlers then
        event_handlers[event_name] = {}
    end

    table.insert(handlers, priority_binary_search(handlers, priority), { handler = handler, priority = priority })
    if #handlers == 1 then
        script_on_event(event_name, on_event)
    end
end

---Do not use this function, use Event.on_init instead as it has safety checks.
---@param handler fun(event: EventData)
---@param priority number?
function Public.on_init(handler, priority)
    if not priority then priority = 0 end
    local handlers = event_handlers[init_event_name]
    if not handlers then
        event_handlers[init_event_name] = {}
    end

    table.insert(handlers, priority_binary_search(handlers, priority), { handler = handler, priority = priority })
    if #handlers == 1 then
        script.on_init(on_init)
    end
end

---Do not use this function, use Event.on_init instead as it has safety checks.
---@param handler fun(event: EventData)
---@param priority number?
function Public.on_load(handler, priority)
    if not priority then priority = 0 end
    local handlers = event_handlers[load_event_name]
    if not handlers then
        event_handlers[load_event_name] = {}
    end

    table.insert(handlers, priority_binary_search(handlers, priority), { handler = handler, priority = priority })
    if #handlers == 1 then
        script.on_load(on_load)
    end
end

---Do not use this function, use Event.on_nth_tick instead as it has safety checks.
---@param tick int
---@param handler fun(event: EventData)
---@param priority number?
function Public.on_nth_tick(tick, handler, priority)
    if not priority then priority = 0 end
    local handlers = on_nth_tick_event_handlers[tick]
    if not handlers then
        on_nth_tick_event_handlers[tick] = {{ handler = handler, priority = priority }}
    end

    table.insert(handlers, priority_binary_search(handlers, priority), { handler = handler, priority = priority })
    if #handlers == 1 then
        script_on_nth_tick(tick, on_nth_tick_event)
    end
end

function Public.get_event_handlers()
    return event_handlers
end

function Public.get_on_nth_tick_event_handlers()
    return on_nth_tick_event_handlers
end

return Public
