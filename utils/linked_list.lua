-- copied from https://www.whoop.ee/post/linked-list.html
---@class Node
---@field value any
---@field next Node | nil
local Node = {}
Node.__index = Node

---@param value any
---@param next? Node | nil
---@return Node
function Node:new(value, next)
    return setmetatable({
        value = value,
        next = next,
    }, self)
end

---@class LinkedList
---@field private _head Node | nil
---@field private _size number
local LinkedList = {}
LinkedList.__index = LinkedList

---@return LinkedList
function LinkedList:new()
    local t = {
        _head = nil,
        _size = 0,
    }
    return setmetatable(t, self)
end

---@return Node | nil
function LinkedList:head()
    return self._head
end

---Complexity O(n)
---@return Node | nil
function LinkedList:tail()
    local tail = nil
    self:traverse(function(node)
        tail = node
    end)
    return tail
end

---@return number
function LinkedList:size()
    return self._size
end

---@return boolean
function LinkedList:isEmpty()
    return self._size == 0
end

---Prepends the node with a value to the beginning of the list.
---@param value any
---@return Node
function LinkedList:prepend(value)
    self._size = self._size + 1
    self._head = Node:new(value, self._head)
    return self._head
end

---Appends the node with a value to the end of the list.
---@param value any
---@return Node
function LinkedList:append(value)
    local node = Node:new(value)
    if self._head == nil then
        self._head = node
    else
        local ptr = self._head
        while ptr and ptr.next do
            ptr = ptr.next
        end
        ptr.next = node
    end
    self._size = self._size + 1
    return self._head
end

---Inserts a new node with value after given node. If after node is nil,
---then it will be inserted at the beginning of the list.
---@param after Node
---@param value any
---@return Node | nil
function LinkedList:insertAfter(after, value)
    if after == nil then
        return nil
    end
    self._size = self._size + 1
    local node = Node:new(value, after.next)
    after.next = node
    return node
end

---Removes and returns the head. Pointer moves to next node. If next node is
---not exists nil is returned.
---@return Node | nil
function LinkedList:removeHead()
    local tmp = self._head
    if not tmp then
        return nil
    end
    self._head = self._head.next
    return tmp
end

---Removes and returns a node after given node. If given node not found nil is
---returned.
---@param node Node
---@return Node | nil
function LinkedList:removeAfter(node)
    local tmp = node.next
    node.next = tmp and tmp.next
    return tmp
end

function LinkedList:remove(value)
    if value == self._head.value then
        self._head = self._hed.next
    end
    local node = self._head
    while node do
        local prev = node
        node = node._next
        if value == node.value then
            prev._next = node._next
        end
    end
end

---Chekcs if the list contins a give value.
---@param value any
---@return boolean
function LinkedList:contains(value)
    return self:findByValue(value) ~= nil
end

---Finds the first occurrence of the value.
---@param value any
---@return Node | nil
function LinkedList:findByValue(value)
    local node = self._head
    while node do
        if node.value == value then
            return node
        end
        node = node.next
    end
    return nil
end

---Traversal of a linked list.
---@param fn fun(node: Node)
function LinkedList:traverse(fn)
    local node = self._head
    while node do
        fn(node)
        node = node.next
    end
end

---@param sep? string
---@return string
function LinkedList:toString(sep)
    sep = sep or ' -> '
    local t = {}
    self:traverse(function(node)
        t[#t + 1] = tostring(node.value)
    end)
    return table.concat(t, sep)
end

return LinkedList
