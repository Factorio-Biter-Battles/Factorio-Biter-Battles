-- Stack implementation
-- All objects are stored directly in arrays and do not touch the hashmap
-- Arrays are allocated 1024 spots at a time, the max for arrays
local pool = require "maps.biter_battles_v2.pool"

stack = {}

function stack.new()
    local new_obj = {}
    new_obj.id = 0
    new_obj.table_id = 1
    new_obj.tables = {}
    new_obj.tables[1] = pool.malloc(1024)
    return new_obj
end

function stack.reset(self)
    self.id = 0
    self.table_id = 1
    self.tables = {} -- GC
    self.tables[1] = pool.malloc(1024)
end

function stack.empty(self)
    return self.table_id == 1 and self.id == 0
end

function stack.push(self,val)
    self.id = self.id + 1

    if self.id == 1025 then
        self.id = 1
        self.table_id = self.table_id + 1
        self.tables[self.table_id] = pool.malloc(1024)
    end

    self.tables[self.table_id][self.id] = val
end

function stack.pop(self)
    local ref = self.tables[self.table_id][self.id]

    self.id = self.id - 1

    if self.id == 0 then
        self.id = 1024
        self.table_id = self.table_id - 1
        self.tables[self.table_id] = nil
    end

    return ref
end

function stack.peek(self)
    return self.tables[self.table_id][self.id]
end

function stack.length(self)
    return 1024 * (self.table_id - 1) + self.id - 1
end

return stack