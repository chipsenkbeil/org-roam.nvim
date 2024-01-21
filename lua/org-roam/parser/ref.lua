-------------------------------------------------------------------------------
-- REF.LUA
--
-- Abstraction for some value wrapped in a table to pass-by-reference.
--
-- NOTE: This exists because Lua passes strings by value, which can be
--       expensive, but passes tables by reference. So this table object
--       serves to hold onto a string and can be passed around to avoid
--       copying the string.
-------------------------------------------------------------------------------

---@class org-roam.parser.Ref<T>: { value: T }
local M = {}
M.__index = M

---Creates a new reference for the provided value.
---Note that in the case of nil, boolean, number, and string, this value is copied.
---@generic T
---@param value T
---@return org-roam.parser.Ref<T>
function M:new(value)
    local instance = {}
    setmetatable(instance, M)

    instance.value = value

    return instance
end

return M
