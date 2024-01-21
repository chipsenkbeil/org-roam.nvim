-------------------------------------------------------------------------------
-- PROPERTY.LUA
--
-- Abstraction for an org property within a property drawer.
-------------------------------------------------------------------------------

---@class org-roam.parser.Property
---@field key org-roam.parser.Slice #slice representing inside of a :KEY:
---@field value org-roam.parser.Slice #slice representing value tied to key
local M = {}
M.__index = M

---Creates a new property.
---@param key org-roam.parser.Slice
---@param value org-roam.parser.Slice
---@return org-roam.parser.PropertyDrawer
function M:new(key, value)
    local instance = {}
    setmetatable(instance, M)

    instance.key = key
    instance.value = value

    return instance
end

return M
