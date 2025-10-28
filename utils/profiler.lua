local table_sort = table.sort
local string_rep = string.rep
local string_format = string.format
local debug_getinfo = debug and debug.getinfo
local Event = require('utils.event')
local session = require('utils.datastore.session_data')
local admin_autostop = 60 * 60 -- 1 min
local player_autostop = 60 * 10 -- 10 s

local ignoredFunctions = {}

local Profiler = {
    --	Call
    CallTree = nil,
    IsRunning = false,
    AutoStopTick = nil,
}

local WARNING_MESSAGE_DISABLED = (
    'The profiler cannot work in this version of Factorio by default,'
    .. ' downgrade to 1.1.106 or start the game with --enable-unsafe-lua-debug-api.'
)

function Profiler.isProfilingSupported()
    if debug and debug.getinfo and debug.sethook then
        -- running <1.1.107, the required functions are available
        return true
    else
        return false
    end
end
ignoredFunctions[Profiler.isProfilingSupported] = true

if Profiler.isProfilingSupported() then
    ignoredFunctions[debug.sethook] = true
end

local namedSources = {
    ['[string "local n, v = "serpent", "0.30" -- (C) 2012-17..."]'] = 'serpent',
}

local function startCommand(command)
    local player = game.get_player(command.player_index)
    game.print({
        '',
        '\n====\n',
        player.name,
        " is trying to turn on the profiler.\nIf you don't know what that means, then you don't have to worry about it.\n Further info will be available in logs ONLY.",
        '\n====\n',
    })
    log({ '', '\n====\n', player.name, ' is trying to turn on the profiler.', '\n====\n' })

    if not Profiler.isProfilingSupported() then
        log(WARNING_MESSAGE_DISABLED)
        return
    end

    local trusted = session.get_trusted_table()
    if not trusted[player.name] then
        log(player.name .. ' has not grown accustomed to this technology yet.')
        return
    end
    Profiler.Start(command.parameter ~= nil, is_admin(player), command.tick)
end
local function stopCommand(command)
    Profiler.Stop(command.parameter ~= nil, nil)
end
ignoredFunctions[startCommand] = true
ignoredFunctions[stopCommand] = true

commands.add_command('startProfiler', 'Starts profiling', startCommand)
commands.add_command('stopProfiler', 'Stops profiling', stopCommand)

--local assert_raw = assert
--function assert(expr, ...)
--	if not expr then
--		Profiler.Stop(false, "Assertion failed")
--	end
--	assert_raw(expr, ...)
--end
local error_raw = error
if Profiler.isProfilingSupported() then
    function error(...)
        Profiler.Stop(false, 'Error raised')
        error_raw(...)
    end
end

function Profiler.Start(excludeCalledMs, admin, tick)
    if not Profiler.isProfilingSupported() then
        log(
            'WARNING in Biterbattle profiler.lua: Profiler.Start was called directly by a script although it is unavailable.'
        )
        log('WARNING ... ' .. WARNING_MESSAGE_DISABLED)
        return
    end

    if Profiler.IsRunning then
        return
    end
    if admin then
        Profiler.AutoStopTick = tick + admin_autostop
        log(
            string_format(
                '====Profiler started====\nIt will be automatically stopped in %d seconds if no action is performed',
                admin_autostop / 60
            )
        )
    else
        Profiler.AutoStopTick = tick + player_autostop
        log(
            string_format(
                '====Profiler started====\nIt will be automatically stopped in %d seconds if no action is performed',
                player_autostop / 60
            )
        )
    end
    local create_profiler = helpers.create_profiler

    Profiler.IsRunning = true

    Profiler.CallTree = {
        name = 'root',
        calls = 0,
        profiler = create_profiler(),
        next = {},
    }

    --	Array of Call
    local stack = { [0] = Profiler.CallTree }
    local stack_count = 0

    debug.sethook(function(event)
        local info = debug_getinfo(2, 'nSf')

        if ignoredFunctions[info.func] then
            return
        end

        if event == 'call' or event == 'tail call' then
            local prevCall = stack[stack_count]
            if excludeCalledMs then
                prevCall.profiler.stop()
            end

            local what = info.what
            local name
            if what == 'C' then
                name = string_format('C function %q', info.name or 'anonymous')
            else
                local source = info.short_src
                local namedSource = namedSources[source]
                if namedSource ~= nil then
                    source = namedSource
                elseif string.sub(source, 1, 1) == '@' then
                    source = string.sub(source, 1)
                end
                name = string_format('%q in %q, line %d', info.name or 'anonymous', source, info.linedefined)
            end

            local prevCall_next = prevCall.next
            if prevCall_next == nil then
                prevCall_next = {}
                prevCall.next = prevCall_next
            end

            local currCall = prevCall_next[name]
            local profilerStartFunc
            if currCall == nil then
                local prof = create_profiler()
                currCall = {
                    name = name,
                    calls = 1,
                    profiler = prof,
                }
                prevCall_next[name] = currCall
                profilerStartFunc = prof.reset
            else
                currCall.calls = currCall.calls + 1
                profilerStartFunc = currCall.profiler.restart
            end

            stack_count = stack_count + 1
            stack[stack_count] = currCall

            profilerStartFunc()
        end

        if event == 'return' or event == 'tail call' then
            if stack_count > 0 then
                stack[stack_count].profiler.stop()
                stack[stack_count] = nil
                stack_count = stack_count - 1

                if excludeCalledMs then
                    stack[stack_count].profiler.restart()
                end
            end
        end
    end, 'cr')
end
ignoredFunctions[Profiler.Start] = true

local function DumpTree(averageMs)
    local function sort_Call(a, b)
        return a.calls > b.calls
    end
    local fullStr = { '' }
    local str = fullStr
    local line = 1

    local function recurse(curr, depth)
        local sort = {}
        local i = 1
        for k, v in pairs(curr) do
            sort[i] = v
            i = i + 1
        end
        table_sort(sort, sort_Call)

        for i = 1, #sort do
            local call = sort[i]

            if line >= 19 then --Localised string can only have up to 20 parameters
                local newStr = { '' } --So nest them!
                str[line + 1] = newStr
                str = newStr
                line = 1
            end

            if averageMs then
                call.profiler.divide(call.calls)
            end

            str[line + 1] = string_format(
                '\n%s%dx %s. %s ',
                string_rep('\t', depth),
                call.calls,
                call.name,
                averageMs and 'Average' or 'Total'
            )
            str[line + 2] = call.profiler
            line = line + 2

            local next = call.next
            if next ~= nil then
                recurse(next, depth + 1)
            end
        end
    end
    if Profiler.CallTree.next ~= nil then
        recurse(Profiler.CallTree.next, 0)
        return fullStr
    end
    return 'No calls'
end

function Profiler.Stop(averageMs, message)
    if not Profiler.IsRunning then
        return
    end

    debug.sethook()

    local text = {
        '',
        '\n\n----------PROFILER DUMP----------\n',
        DumpTree(averageMs),
        '\n\n----------PROFILER STOPPED----------\n',
    }
    if message ~= nil then
        text[#text + 1] = string.format('Reason: %s\n', message)
    end
    log(text)
    --game.write_file("profiler_output.txt", text, true)
    Profiler.CallTree = nil
    Profiler.IsRunning = false
    Profiler.AutoStopTick = nil
    log('====Profiler stopped====')
end
ignoredFunctions[Profiler.Stop] = true

local function on_tick(event)
    --if not Profiler.IsRunning then return end
    if not (event.tick == Profiler.AutoStopTick) then
        return
    end
    Profiler.Stop(false, 'AutoStop')
end

if Profiler.isProfilingSupported() then
    Event.add(defines.events.on_tick, on_tick)
end
return Profiler
