-- This module exists to break the circular dependency between event.lua and global.lua.
-- It is not expected that any user code would require this module instead event.lua should be required.

local EventCore = {}

local init_event_name = -1
local load_event_name = -2

---@type table<event_name, function[]> # each event_name stores an array of handlers
local event_handlers = {}
---@type table<uint, function[]> # each Nth tick stores an array of handlers
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

---Prints error and stacktrace to Factorio log.
local function errorHandler(err)
    log("Error caught: " .. err)
    -- Print the full stack trace
    log(debug.traceback())
end

-- This is a cursed local function definition
local call_handlers
---Safely executes all functions handling current event.
---@param handlers ( fun(event: EventData): nil )[]
---@param event EventData # The respective event data type
function call_handlers(handlers, event)
	if not handlers then
		return log('Handlers was nil!')
	end
	local handlers_copy = table.deepcopy(handlers)
	for i = 1, #handlers do
		local handler = handlers[i]
		if handler == nil and handlers_copy[i] ~= nil then
			if table.contains(handlers, handlers_copy[i]) then
				handler = handlers_copy[i]
			end
		end
		if handler ~= nil then
			xpcall(handler, errorHandler, event)
		else
			log('nil handler')
		end
	end
end

---Runs the event handlers registered to current event's name.
---@return nil
local function on_event(event)
    local handlers = event_handlers[event.name]
    if not handlers then
        -- https://lua-api.factorio.com/latest/events.html#CustomInputEvent
        -- "The prototype name of the custom input that was activated."
        handlers = event_handlers[event.input_name]
    end
    call_handlers(handlers, event)
end

---Runs all registered on_init functions (on new game) and transitions to Runtime stage.
local function on_init()
    _LIFECYCLE = 5 -- on_init
    local handlers = event_handlers[init_event_name]
    call_handlers(handlers)

    event_handlers[init_event_name] = nil
    event_handlers[load_event_name] = nil

    _LIFECYCLE = 8 -- Runtime
end


---Runs all registered on_load functions (on save loaded/joined) and transitions to Runtime stage.
local function on_load()
    _LIFECYCLE = 6 -- on_load
    local handlers = event_handlers[load_event_name]
    call_handlers(handlers)

    event_handlers[init_event_name] = nil
    event_handlers[load_event_name] = nil

    _LIFECYCLE = 8 -- Runtime
end

---Runs all event handlers registered to current Nth tick.
---The game can register any amount of Nth ticks but only one function for them all.
---Therefore this is a generic handler for all registered ticks,
---that decides which actual Nth tick it is to run its respective handlers.
---@param event NthTickEventData
local function on_nth_tick_event(event)
    local handlers = on_nth_tick_event_handlers[event.nth_tick]
    call_handlers(handlers, event)
end

--- Do not use this function, use Event.add instead as it has safety checks.
---Registers/inserts the handler function to work with specified event.
---If it is the first handler, register the orchestrator handler with the game
---@param event_name string # event.name or event.input_name (technically any key)
---@param handler fun(event: EventData): nil # Respective event data type
function EventCore.add(event_name, handler)
    if event_name == defines.events.on_entity_damaged then
        error("on_entity_damaged is managed outside of the event framework.")
    end
    local handlers = event_handlers[event_name]
    if not handlers then
        event_handlers[event_name] = {handler}
        script_on_event(event_name, on_event)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script_on_event(event_name, on_event)
        end
    end
end

--- Do not use this function, use Event.on_init instead as it has safety checks.
---Registers/inserts the handler function to work with on_init event.
---If it is the first handler, register the orchestrator handler with the game
---@param handler fun(): nil
function EventCore.on_init(handler)
    local handlers = event_handlers[init_event_name]
    if not handlers then
        event_handlers[init_event_name] = {handler}
        script.on_init(on_init)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script.on_init(on_init)
        end
    end
end

--- Do not use this function, use Event.on_load instead as it has safety checks.
---Registers/inserts the handler function to work with on_load event.
---If it is the first handler, register the orchestrator handler with the game
---@param handler fun(): nil
function EventCore.on_load(handler)
    local handlers = event_handlers[load_event_name]
    if not handlers then
        event_handlers[load_event_name] = {handler}
        script.on_load(on_load)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script.on_load(on_load)
        end
    end
end

--- Do not use this function, use Event.on_nth_tick instead as it has safety checks.
---Registers/inserts the handler function to work for Nth tick.
---If it is the first handler of its Nth kind, register the Nth ticker with the game
---@see NthTickEventData
---@param tick uint
---@param handler fun(event: NthTickEventData): nil
function EventCore.on_nth_tick(tick, handler)
    local handlers = on_nth_tick_event_handlers[tick]
    if not handlers then
        on_nth_tick_event_handlers[tick] = {handler}
        script_on_nth_tick(tick, on_nth_tick_event)
    else
        table.insert(handlers, handler)
        if #handlers == 1 then
            script_on_nth_tick(tick, on_nth_tick_event)
        end
    end
end

---Returns the table with event_handlers
---@return table<event_name, function[]> # each event_name stores an array of handlers
function EventCore.get_event_handlers()
    return event_handlers
end

---Returns the table with only Nth tick handlers
---@return table<uint, function[]> # each Nth tick stores an array of handlers
function EventCore.get_on_nth_tick_event_handlers()
    return on_nth_tick_event_handlers
end

return EventCore
