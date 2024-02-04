-------------------------------------------------------------------------------
-- QUEUE.LUA
--
-- Abstraction for a general-purpose queue.
-------------------------------------------------------------------------------

---@class org-roam.utils.Queue
---@field private __front integer #pointer to position of first element
---@field private __back integer #pointer to position of last element
---@field private __data { [integer]: any }
---@overload fun(data?:any[]):org-roam.utils.Queue
local M = setmetatable({}, {
    __call = function(tbl, ...)
        return tbl:new(...)
    end,
})
M.__index = M

---Creates a new queue.
---@param data? any[] #optional list of data to populate the queue
---@return org-roam.utils.Queue
function M:new(data)
    local instance = {}
    setmetatable(instance, M)
    instance.__data = {}
    instance.__front = 0
    instance.__back = -1

    -- Populate if given some data as a list
    for _, value in ipairs(data or {}) do
        instance:push_back(value)
    end

    return instance
end

---Returns the length of the queue's data.
---@return integer
function M:len()
    return self.__back - self.__front + 1
end

---Returns true if the queue is empty.
---@return boolean
function M:is_empty()
    return self.__front > self.__back
end

---Pushes a value to the front of the queue.
---@param value any
function M:push_front(value)
    local front = self.__front - 1
    self.__front = front
    self.__data[front] = value
end

---Removes value from the front of the queue.
---Will throw an error if the queue is empty.
---@return any
function M:pop_front()
    local front = self.__front
    if front > self.__back then
        error("queue is empty")
    end

    local value = self.__data[front]
    self.__data[front] = nil
    self.__front = front + 1
    return value
end

---Returns the value at the front of the queue.
---Will throw an error if the queue is empty.
---@return any
function M:peek_front()
    local front = self.__front
    if front > self.__back then
        error("queue is empty")
    end
    return self.__data[front]
end

---Pushes a value to the back of the queue.
---@param value any
function M:push_back(value)
    local back = self.__back + 1
    self.__back = back
    self.__data[back] = value
end

---Removes value from the front of the queue.
---Will throw an error if the queue is empty.
---@return any
function M:pop_back()
    local back = self.__back
    if self.__front > back then
        error("queue is empty")
    end

    local value = self.__data[back]
    self.__data[back] = nil
    self.__back = back - 1
    return value
end

---Returns the value at the back of the queue.
---Will throw an error if the queue is empty.
---@return any
function M:peek_back()
    local back = self.__back
    if self.__front > back then
        error("queue is empty")
    end
    return self.__data[back]
end

---Returns an iterator over the queue's contents from front to back.
---@return org-roam.utils.Iterator
function M:iter()
    local i = self.__front
    local back = self.__back

    -- Keep a reference to the data table (not a full copy)
    local data = self.__data

    local next = function()
        if i <= back then
            local value = data[i]
            i = i + 1
            return value
        end
    end

    return require("org-roam.utils.iterator"):new(next, { allow_nil = true })
end

---Returns a copy of the queue's contents from front to back as a list.
---@return any[]
function M:contents()
    return self:iter():collect()
end

return M
