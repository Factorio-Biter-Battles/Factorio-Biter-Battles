local Event = require('utils.event')
local Token = require('utils.token')

storage.profiler_new = {
    enabled = false,
    player = 0,
}
--- starting at index 2, as first entry is a constant empty string
local index = 2
---preallocate array of log entries
local tick_durations = {
    '',
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {},
}
---preallocate array of LuaProfilers
---@type 0[]|LuaProfiler[]
local profilers = {
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
}

--- Measure duration of each tick update.
--- Dumping on every 19th tick to minimize number of write_file() calls
local measure_tick_duration = Token.register(function(event)
    ---stop the profiler started in previous tick
    profilers[index].stop()
    ---log its data
    tick_durations[index] = { '', event.tick - 1, '\t', profilers[index], '\n' }
    index = index + 1
    ---dump data when LocalisedString limit size is reached
    if index == 21 then
        helpers.write_file('profiler/cumulative/total_tick_duration.txt', tick_durations, true, storage.profiler_new.player)
        index = 2
    end
    ---start timer for this tick
    profilers[index].reset()
end)

---Start the profiler
---Logs are exported only to the player that enabled the profiler
---@param cmd CustomCommandData
local function profiler_start(cmd)
    local player = game.get_player(cmd.player_index)
    if not player.admin then
        player.print('This is admin-only command.')
        return
    end
    if storage.profiler_new.enabled then
        player.print('Profiler is already running')
        return
    end
    storage.profiler_new = { enabled = true, player = cmd.player_index }
    for i = 2, 20, 1 do
        profilers[i] = helpers.create_profiler(true)
    end
    profilers[2].restart()
    Event.add_removable(defines.events.on_tick, measure_tick_duration)
    game.print('====Profiler started====\n')
end

---Stop the profiler
---todo: dump the data from partially filled tick_duration array
---@param cmd CustomCommandData
local function profiler_stop(cmd)
    local player = game.get_player(cmd.player_index)
    if not player.admin then
        player.print('This is admin-only command.')
        return
    end
    if not storage.profiler_new.enabled then
        player.print("Profiler isn't running")
        return
    end
    for i = index, 20, 1 do
        tick_durations[i] = { '', '' }
    end
    helpers.write_file('profiler/total_tick_duration.txt', tick_durations, true, storage.profiler_new.player)
    index = 2
    storage.profiler_new.enabled = false
    profilers = {
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
    }
    Event.remove_removable(defines.events.on_tick, measure_tick_duration)
    game.print('====Profiler stopped====\n Check logs in script-output/profiler \n')
end

commands.add_command(
    'StartProfilerNew',
    'Start NewProfiler. Logs are written to script-output/profiler of the player that started the profiler.',
    profiler_start
)
commands.add_command('StopProfilerNew', 'Stop NewProfiler', profiler_stop)
