-- Stack implementation
-- All objects are stored directly in arrays and do not touch the hashmap
-- Arrays are allocated 1024 spots at a time, the max for arrays
local pool = require "maps.biter_battles_v2.pool"

stack = {}

function stack.new()
    return {id = 0, table_id = 1, tables = {pool.malloc(1024), table = tables[1]}}
end

function stack.reset(self)
    self.id = 0
    self.table_id = 1
    self.tables = {pool.malloc(1024)} -- GC
    self.table = self.tables[1]
end

function stack.empty(self)
    return self.table_id == 1 and self.id == 0
end

function stack.push(self,val)
    local id = self.id + 1

    if id == 1025 then
        id = 1
        local table_id = self.table_id + 1
        self.tables[table_id] = pool.malloc(1024)
        self.table = self.tables[table_id]
        self.table_id = table_id
    end

    self.table[id] = val
    self.id = id
end

function stack.pop(self)
    local id = self.id
    local ref = self.table[id]

    if id == 1 then
        id = 1025
        local table_id = self.table_id
        self.tables[table_id] = nil
        table_id = table_id - 1
        self.table = self.tables[table_id]
        self.table_id = table_id
    end

    self.id = id - 1

    return ref
end

function stack.peek(self)
    return self.table[self.id]
end

function stack.length(self)
    return 1024 * (self.table_id - 1) + self.id - 1
end

return stack