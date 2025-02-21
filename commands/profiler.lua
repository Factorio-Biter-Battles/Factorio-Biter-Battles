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
        --- We have to make global check, to prevent a new-joining admin starting profiler while there's one already running
        if storage.new_profiler.is_running then
            player.print('Profiler is already running')
            return
        end
        storage.new_profiler.is_running = true
        NewProfiler.enabled = true
        NewProfiler.player_index = cmd.player_index
        NewProfiler.counstruct_tick_durations_data()
        NewProfiler.construct_profiler_data()
        --- Removable events are globalised, this should be fine as long as nothing is printed inside the handler
        Event.add_removable(defines.events.on_tick, NewProfiler.measure_tick_duration)
        --- This should be fine, it should be recived only by already connected players sharing the same local variables state
        game.print('\n====ProfilerNew started====\n')
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
        if not storage.new_profiler.is_running then 
            player.print("Profiler isn't running")
            return 
        end
        if storage.new_profiler.clients_joined_midrun[cmd.player_index] then
            game.print("Oopsie, " .. player.name .. " tried to stop NewProfiler but his client doesn't know it's actually running. \nWe're gonna stop him right there, in order to prevent his desync.\nAsk someone that witnessed the NewProfiler being started to stop it for you.\nHave safe, desync-free game!")
            return
        end

        NewProfiler.dump_all_profiler_data()
        Event.remove_removable(defines.events.on_tick, NewProfiler.measure_tick_duration)
        NewProfiler.dump_tick_durations_data()
        --- That's fine, we're just overwritting it withour looking at it
        NewProfiler.enabled = false
        storage.new_profiler.is_running = false
        storage.new_profiler.clients_joined_midrun = {}
        game.print('\n====ProfilerNew stopped====\n')
        player.print('Check logs in script-output/profiler. Please share them with other interested players.')
    end
end

Event.add(defines.events.on_player_joined_game, function(event)
    if not storage.new_profiler.is_running then return end
    table.insert(storage.new_profiler.clients_joined_midrun, event.player_index = true)
end)
commands.add_command('startProfiler', 'Starts profiling', startCommand)
commands.add_command('stopProfiler', 'Stops profiling', stopCommand)
