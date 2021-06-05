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
