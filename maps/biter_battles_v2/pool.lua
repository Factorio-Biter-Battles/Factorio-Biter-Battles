-- A pool memory allocator.
local mod = {}

local function integer_alloc()
        return 0
end

local function array_alloc()
	return {}
end

local function _malloc(size, fn)
	-- Force allocates an array with hard size limit, then
	-- returns reference to it. The 'memory' here is just a representation
	-- layer that emulates cells within RAM.
	local memory = {}

	for i = 1, size, 1 do
		memory[i] = fn()
	end

	return memory
end

-- malloc - Malloc with array allocator
function mod.malloc_array(size)
	return _malloc(size, array_alloc)
end

-- malloc - Default malloc with integer allocator
function mod.malloc(size)
	return _malloc(size, integer_alloc)
end

function mod.enlarge(memory, offset, bytes)
	-- Resizes memory from offset by bytes. The offset should point at
	-- last cell of allocated region to prevent overwriting.
	if memory[offset + 1] ~= nil then
		log("pool::enlarge: writing over allocated region!")
		local detail_fmt = "pool::enlarge: offset = %d, request = %d"
		log(string.format(detail_fmt, offset, bytes))
	end

	for i = offset + 1, offset + bytes, 1 do
		memory[i] = 0
	end

	return memory
end

return mod
