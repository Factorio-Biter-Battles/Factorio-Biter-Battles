local Event = require('utils.event')
local Token = require('utils.token')

storage.profiler_new = {
    enabled = false,
    player = 0,
}
--- starting at index 2, as first entry is a constant empty string
local row = 2
local column = 2
---preallocate array of log entries
-- stylua: ignore
local tick_durations = {
    '',
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
    {'',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n',0,helpers.create_profiler(true),'\n'},
}

--- Measure duration of each tick update.
--- Dumping on every 19th tick to minimize number of write_file() calls
local measure_tick_duration = Token.register(function(event)
    -- stop the profiler started in previous tick and log its data
    tick_durations[row][column] = event.tick - 1
    tick_durations[row][column+1].stop()
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
            storage.profiler_new.player
        )
        row=2
        column=2
    end
    ---start timer for this tick
    tick_durations[row][column+1].reset()
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

    tick_durations[2][3].restart()
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
    tick_durations[row][column] = cmd.tick-1
    tick_durations[row][column + 1].stop()
    for i = 2,row, 1 do
        if i == row then
            -- construct sub array of partially filled row
            local t = {''}
            for j = 2, column+2, 1 do
                t[j] = tick_durations[row][column]
            end
            helpers.write_file('profiler/cumulative/total_tick_duration.txt', t, true, storage.profiler_new.player)
        else
            helpers.write_file('profiler/cumulative/total_tick_duration.txt', tick_durations[i], true, storage.profiler_new.player)
        end
    end
    row = 2
    column = 2
    storage.profiler_new.enabled = false

    Event.remove_removable(defines.events.on_tick, measure_tick_duration)
    game.print('====Profiler stopped====\n Check logs in script-output/profiler \n')
end

commands.add_command(
    'StartProfilerNew',
    'Start NewProfiler. Logs are written to script-output/profiler of the player that started the profiler.',
    profiler_start
)
commands.add_command('StopProfilerNew', 'Stop NewProfiler', profiler_stop)
