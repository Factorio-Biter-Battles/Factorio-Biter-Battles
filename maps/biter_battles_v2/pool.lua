-- A pool memory allocator.
local mod = {}

function mod.malloc(size)
    -- Force allocates an array with hard size limit, then
    -- returns reference to it. The 'memory' here is just a representation
    -- layer that emulates cells within RAM.
    local memory = {}

    for i = 1, size, 1 do
        memory[i] = 0
    end

    return memory
end

function mod.enlarge(memory, offset, bytes)
    -- Resizes memory from offset by bytes. The offset should point at
    -- last cell of allocated region to prevent overwriting.
    if memory[offset + 1] ~= nil then
        log('pool::enlarge: writing over allocated region!')
        local detail_fmt = 'pool::enlarge: offset = %d, request = %d'
        log(string.format(detail_fmt, offset, bytes))
    end

    for i = offset + 1, offset + bytes, 1 do
        memory[i] = 0
    end

    return memory
end
-- stylua: ignore start

---@alias ProfilerRow ['',0,LuaProfiler,'\\n',0,LuaProfiler,'\\n',0,LuaProfiler,'\\n',0,LuaProfiler,'\\n',0,LuaProfiler,'\\n',0,LuaProfiler,'\\n']
--- Nested LocalisedString with 19x6 LuaProfilers
---@alias ProfilerBuffer ['', ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow,ProfilerRow]

---@return ProfilerBuffer
function mod.profiler_malloc()
    return {
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
end
-- stylua: ignore end
return mod
