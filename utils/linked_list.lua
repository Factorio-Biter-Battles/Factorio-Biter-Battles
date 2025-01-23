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

---@return boolean
function LinkedList:isEmpty()
    return self._head == nil
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

----Removes the first occruenace of the value.
----@param value any
----@return nil
function LinkedList:remove(value)
    if value == self._head.value then
        self._head = self._head.next
    end
    local node = self._head
    while node do
        local prev = node
        node = node._next
        if value == node.value then
            prev._next = node._next
            return nil
        end
    end
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

return LinkedList
