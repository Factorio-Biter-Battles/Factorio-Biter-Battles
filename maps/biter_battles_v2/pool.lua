local precomputed = require('maps.biter_battles_v2.precomputed.pool')
-- A pool memory allocator.
local mod = {}

function mod.malloc(size)
    -- Force allocates an array with hard size limit, then
    -- returns reference to it. The 'memory' here is just a representation
    -- layer that emulates cells within RAM.
    if size < 1025 then
        return precomputed[size]()
    else
        local memory = precomputed[1024]()
        for i = 1025, size, 1 do
            memory[i] = 0
        end
        return memory
    end
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

return mod
