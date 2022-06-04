-- A pool memory allocator.
local mod = {}

function mod.malloc(size)
	-- Force allocates an array with hard size limit, then
	-- returns reference to it. The 'memory' here is just a representation
	-- layer that emulates cells within RAM.
	-- Size preferably should be a power of 2 and MUST be less than 1024.
	local memory = {}

	memory[size] = 0

	return memory
end

function mod.enlarge(memory, offset, bytes)
	-- Resizes memory from offset by bytes. The offset should point at
	-- last cell of allocated region to prevent overwriting.
	-- offset times a power of 2 should equal bytes, including 2^0.
	if memory[offset + bytes] ~= nil then
		log("pool::enlarge: writing over allocated region!")
		local detail_fmt = "pool::enlarge: offset = %d, request = %d"
		log(string.format(detail_fmt, offset, bytes))
	end

	memory[offset + bytes] = 0

	return memory
end

return mod
