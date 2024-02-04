-------------------------------------------------------------------------------
-- ITERATOR.LUA
--
-- Abstraction for an iterator of values.
-------------------------------------------------------------------------------

local pack = require("org-roam.utils.table").pack
local unpack = require("org-roam.utils.table").unpack

---@class org-roam.utils.Iterator
---@field private __allow_nil boolean
---@field private __last {n:integer, [integer]:any}|nil
---@field private __next fun():...
---@overload fun(f:(fun():...), opts?:{allow_nil?:boolean}):org-roam.utils.Iterator
local M = setmetatable({}, {
    __call = function(tbl, ...)
        return tbl:new(...)
    end,
})
M.__index = M


---Creates a new iterator using the provided function to feed in values.
---Once the function returns nothing, the iterator will mark itself finished.
---
---Supports options to configure how the iterator behaves:
---
---    * allow_nil: if true, the iterator can return nil values as the only
--                  values for a call to next() and still continue; otherwise,
--                  once a call to next() returns only nil values, the iterator
--                  will stop. This means that setting to false will require
--                  the next() call to return nothing to properly exit versus
--                  explicitly returning nil.
---
---@param f fun():...
---@param opts? {allow_nil?:boolean}
---@return org-roam.utils.Iterator
function M:new(f, opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)
    instance.__allow_nil = opts.allow_nil or false
    instance.__last = nil
    instance.__next = f

    return instance
end

---Checks if the iterator has another value available.
---This is achieved by calling the internal `next` to see if a value is returned,
---and if so that value is cached to be supplied as the future next value.
---@return boolean
function M:has_next()
    -- If we have not checked yet for the most recent, do so now
    if not self.__last then
        self.__last = pack(self.__next())
    end

    -- If we do NOT allow nil, then we need to check last to
    -- see if it is comprised only of nil values, and if so
    -- revise the last cache to have nothing
    if not self.__allow_nil and self.__last.n > 0 then
        local has_non_nil = false

        for i = 1, self.__last.n do
            has_non_nil = self.__last[i] ~= nil
            if has_non_nil then
                break
            end
        end

        return has_non_nil
    else
        -- If we are at the end, there should be nothing returned
        return self.__last.n > 0
    end
end

---Returns the next value from the iterator, advancing its position.
---@return ...
function M:next()
    -- Invoke has_next so we populate the cache of the last value,
    -- which also ensures that the cache represents something, meaning
    -- we can clear the cache
    if self:has_next() then
        local results = assert(self.__last, "Has next, but last is nil")
        self.__last = nil
        return unpack(results, 1, results.n)
    end
end

---Transforms this iterator by mapping each value using the provided function.
---
---Note that this does NOT clone the existing iterator and invoking `next`
---on the created iterator will also advance the existing iterator.
---@param f fun(...):...
---@return org-roam.utils.Iterator
function M:map(f)
    return M:new(function()
        if self:has_next() then
            return f(self:next())
        end
    end, { allow_nil = self.__allow_nil })
end

---Collects all remaining values from the iterator by continually calling next
---until the iterator has finished.
---
---If a call to next would return more than one value, the collection of
---values are packed; otherwise, the value is made directly available within
---the returned list of results.
---
---@return (any|{n:integer, [integer]:any})[]
function M:collect()
    local results = {}

    while self:has_next() do
        ---@type {n:integer, [integer]:any}
        local values = pack(self:next())
        if values.n == 1 then
            table.insert(results, values[1])
        elseif values.n > 1 then
            table.insert(results, values)
        end
    end

    return results
end

return M
