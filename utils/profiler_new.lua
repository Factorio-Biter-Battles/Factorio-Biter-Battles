local Token = require('utils.token')
local pool = require('maps.biter_battles_v2.pool')
local debug_getinfo = debug.getinfo

storage.new_profiler = {
    --- This variable is synced with all clients.
    --- Everybody will agree if the NewProfiler is running or not
    is_running = false,
    clients_joined_midrun = {},
    --- Globalised index of the player that started the profiler.
    --- Needed for autostopping when he leaves the game.
    player_index = 0,
}

local NewProfiler = {
    --- Every joining player will get this variable set to false.
    --- Only clients that witnessed the NewProfiler being started will have this set to true.
    --- This way we can filter players that have the profiler_data constructed from those who don't
    enabled = false,
    --- player that started the NewProfiler, and will have the logs written
    player_index = 0,
}

local function errorHandler(err)
    log('Error caught: ' .. err)
    -- Print the full stack trace
    log(debug.traceback())
end

--- ====================================
--- EVENTS PROFILERS
--- ====================================

--- translate EventName (int) into string
--- example: defines.events.on_tick -> "on_tick"
---@type table<EventName, string>
local event_name_to_human_readable_name = {}
for event_name, event_id in pairs(defines.events) do
    event_name_to_human_readable_name[event_id] = event_name
end

--- path to log file for each handler
--- format: script-output/profiler/<event name>/<file defined @ line defined>
---@type table<EventName, string[]>
local event_handlers_paths = {}

--- remove removable event path so that lists stay in sync
---@param event_name EventName
---@param index integer?
function NewProfiler.remove_event_handler_path(event_name, index)
    if index then
        log({ '', 'Removed \t ', table.remove(event_handlers_paths[event_name], index), ' at index ', index })
    end
end

--- path to log file for each handler
--- format: script-output/profiler/<nth tick>/<file defined @ line defined>
---@type table<integer, string[]>
local nth_tick_event_handlers_paths = {}

--- remove removable event path so that lists stay in sync
---@param tick uint
---@param index integer
function NewProfiler.remove_nth_tick_event_handler_path(tick, index)
    if index then
        log({ '', 'Removed \t ', table.remove(nth_tick_event_handlers_paths[tick], index), ' at index ', index })
    end
end

--- current row for each handler, waiting to be filled
---@type table<EventName, integer[]>
local rows = {}

--- index pointing to tick field in a row, waiting to be filled
---@type table<EventName, integer[]>
local columns = {}

---@type table<EventName, ProfilerBuffer[]>
local profiler_data = {}

--- Dump partially filled ProfilerBuffer for given handler.
--- Doesn't drop the table.
---@param event_name EventName
---@param handler_index int
local function dump_profiler_data(event_name, handler_index)
    local data = profiler_data[event_name][handler_index]
    local row = rows[event_name][handler_index]
    local column = columns[event_name][handler_index]
    local path = event_handlers_paths[event_name][handler_index]
    if row == 2 and column == 2 then
        --- skip empty log dumping
        return
    end
    for i = 2, row, 1 do
        if i == row then
            -- construct sub array of partially filled row
            ---@type LocalisedString
            local t = { '' }
            for j = 2, column - 3 + 2, 1 do --the entry with [column] index is from the future, hence the -3; +2 to get LuaProfiler and '\n' as well
                t[j] = data[row][j]
            end
            helpers.write_file(path, t, true, NewProfiler.player_index)
        else
            helpers.write_file(path, data[i], true, NewProfiler.player_index)
        end
    end
end

--- Dump all profiler data and remove buffer
function NewProfiler.dump_all_profiler_data()
    --- Block clients that don't have profiler data from entering this code
    if not NewProfiler.enabled then
        return
    end

    for event_name, handlers in pairs(profiler_data) do
        for handler_index, _ in pairs(handlers) do
            dump_profiler_data(event_name, handler_index)
        end
    end
    profiler_data = {}
    rows = {}
    columns = {}
end

--- Construct ProfilerBuffer for each handler for each event,
--- that have been registered before `/startProfiler` was run.
--- Add entries in `rows` and `columns` arrays as well
function NewProfiler.construct_profiler_data()
    for event_name, handlers in pairs(NewProfiler.event_handlers) do
        profiler_data[event_name] = {}
        rows[event_name] = {}
        columns[event_name] = {}
        for i, _ in pairs(handlers) do
            profiler_data[event_name][i] = pool.profiler_malloc()
            rows[event_name][i] = 2
            columns[event_name][i] = 2
        end
    end
end

---Same as `call_handlers` in EventCore but with profiling wrapped around it
---@param handlers fun(event: EventData)[]
---@param event EventData
function NewProfiler.call_handlers_profiled(handlers, event)
    local event_name = event.name
    local game_tick = game.tick
    local path = event_handlers_paths[event_name]
    local data = profiler_data[event_name]

    local rows_e = rows[event_name]
    local columns_e = columns[event_name]
    for i = #handlers, 1, -1 do
        --- those are values, not references to entries in actual tables
        --- kinda weird, might skip that all together
        local row = rows_e[i]
        local column = columns_e[i]
        data[i][row][column] = game_tick
        data[i][row][column + 1].reset()
        xpcall(handlers[i], errorHandler, event)
        data[i][row][column + 1].stop()

        columns_e[i] = column + 3
        -- move to the next row when this one is full
        if columns_e[i] == 20 then
            rows_e[i] = row + 1
            columns_e[i] = 2
        end
        -- dump data when LocalisedString limit size is reached
        if rows_e[i] == 21 then
            helpers.write_file(path[i], data[i], true, NewProfiler.player_index)
            rows_e[i] = 2
            columns_e[i] = 2
        end
    end
end

--- Insert handler's path to event_handlers_path array
--- Construct ProfilerBuffer for removable handlers added while the profiler is running
--- @param event_name EventName
---@param handler fun(event: EventData)
function NewProfiler.add(event_name, handler)
    --- save profiler log location for this handler
    if not event_handlers_paths[event_name] then
        event_handlers_paths[event_name] = {}
    end
    local info = debug_getinfo(handler, 'S')
    table.insert(
        event_handlers_paths[event_name],
        1,
        table.concat({
            'profiler/',
            event_name_to_human_readable_name[event_name],
            '/',
            string.gsub(string.sub(info.short_src, 11, -5), '/', '-'),
            '@',
            info.linedefined,
            '.txt',
        })
    )
    -- construct profiler structure for handlers added after the profiler was started
    if NewProfiler.enabled then
        table.insert(profiler_data[event_name], 1, pool.profiler_malloc())
        table.insert(rows[event_name], 1, 2)
        table.insert(columns[event_name], 1, 2)
    end
end

--- Insert handler's path to event_handlers_path array
--- @param tick uint
--- @param handler fun(event: EventData)
function NewProfiler.on_nth_tick(tick, handler)
    if not nth_tick_event_handlers_paths[tick] then
        nth_tick_event_handlers_paths[tick] = {}
    end
    local info = debug_getinfo(handler, 'S')
    table.insert(
        nth_tick_event_handlers_paths[tick],
        1,
        table.concat({
            'profiler/on_',
            tick,
            'th_tick/',
            string.gsub(string.sub(info.short_src, 11, -5), '/', '-'),
            '@',
            info.linedefined,
            '.txt',
        })
    )
end

--- Since nth_tick_event are called relatively rarelly, we're writting the logs directly, skipping the buffer
---@param handlers fun(event: NthTickEventData)[]
---@param event NthTickEventData
function NewProfiler.call_nth_tick_handlers_profiled(handlers, event)
    local event_tick = event.nth_tick
    local game_tick = game.tick
    local path = nth_tick_event_handlers_paths[event_tick]
    for i = #handlers, 1, -1 do
        local profiler = helpers.create_profiler()
        xpcall(handlers[i], errorHandler, event)
        profiler.stop()
        helpers.write_file(path[i], { '', game_tick, profiler, '\n' }, true, NewProfiler.player_index)
    end
end

--- ====================================
--- TICK DURATION PROFILERS
--- ====================================

--- starting at index 2, as first entry is a constant empty string
local row = 2
local column = 2

---@type ProfilerBuffer
local tick_durations = {}

function NewProfiler.counstruct_tick_durations_data()
    tick_durations = pool.profiler_malloc()
end

--- Measure duration of each tick update.
--- Dumping on every 114th tick to minimize number of write_file() calls
NewProfiler.measure_tick_duration = Token.register(function(event)
    if not NewProfiler.enabled then
        return
    end
    -- stop the profiler started in previous tick and log its data
    tick_durations[row][column] = event.tick - 1
    tick_durations[row][column + 1].stop()
    -- move to next column
    column = column + 3
    -- move to the next row when this one is full
    if column == 20 then
        row = row + 1
        column = 2
    end
    -- dump data when LocalisedString limit size is reached
    if row == 21 then
        helpers.write_file(
            'profiler/cumulative/total_tick_duration.txt',
            tick_durations,
            true,
            NewProfiler.player_index
        )
        row = 2
        column = 2
    end
    ---start timer for this tick
    tick_durations[row][column + 1].reset()
end)

---Dump the data from partially filled tick_duration array
function NewProfiler.dump_tick_durations_data()
    if not NewProfiler.enabled then
        return
    end
    tick_durations[row][column] = game.tick - 1
    tick_durations[row][column + 1].stop()
    for i = 2, row, 1 do
        if i == row then
            -- construct sub array of partially filled row
            ---@type LocalisedString
            local t = { '' }
            for j = 2, column + 2, 1 do
                t[j] = tick_durations[row][j]
            end
            helpers.write_file('profiler/cumulative/total_tick_duration.txt', t, true, NewProfiler.player_index)
        else
            helpers.write_file(
                'profiler/cumulative/total_tick_duration.txt',
                tick_durations[i],
                true,
                NewProfiler.player_index
            )
        end
    end
    tick_durations = {}
    row = 2
    column = 2
end

return NewProfiler
