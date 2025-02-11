local NewProfiler = require('utils.profiler_new')
local OldProfiler = require('utils.profiler')
local session = require('utils.datastore.session_data')
local EventCore = require('utils.event_core')
local Event = require('utils.event')

---@param cmd CustomCommandData
local function startCommand(cmd)
    local player = game.get_player(cmd.player_index)
    if not player then
        return
    end
    if not player.valid then
        return
    end

    if OldProfiler.isProfilingSupported() then
        player.print('Turning on OldProfiler')
        local trusted = session.get_trusted_table()
        if not trusted[player.name] then
            player.print(
                'You have not grown accustomed to this technology yet.',
                { color = { r = 0.22, g = 0.99, b = 0.99 } }
            )
            return
        end
        OldProfiler.Start(cmd.parameter ~= nil, player.admin, cmd.tick)
    else
        if not player.admin then
            player.print('This is admin-only command.', { color = { r = 0.22, g = 0.99, b = 0.99 } })
            return
        end
        if storage.profiler_new and storage.profiler_new.enabled then
            player.print('Profiler is already running')
            return
        end
        storage.profiler_new = { enabled = true, player = cmd.player_index }
        NewProfiler.construct_profiler_data()
        Event.add_removable(defines.events.on_tick, NewProfiler.measure_tick_duration)
        game.print('====ProfilerNew started====\n')
    end
end

---@param cmd CustomCommandData
local function stopCommand(cmd)
    if OldProfiler.isProfilingSupported() then
        OldProfiler.Stop(cmd.parameter ~= nil, nil)
    else
        local player = game.get_player(cmd.player_index)
        if not player.admin then
            player.print('This is admin-only command.')
            return
        end
        if not storage.profiler_new.enabled then
            player.print("Profiler isn't running")
            return
        end
        NewProfiler.dump_all_profiler_data()
        Event.remove_removable(defines.events.on_tick, NewProfiler.measure_tick_duration)
        storage.profiler_new.enabled = false
        game.print('====Profiler stopped====\n Check logs in script-output/profiler \n')
    end
end

commands.add_command('startProfiler', 'Starts profiling', startCommand)
commands.add_command('stopProfiler', 'Stops profiling', stopCommand)
