-------------------------------------------------------------------------------
-- SECTION.LUA
--
-- Abstraction for an org section.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.Section
---@field range org-roam.core.parser.Range
---@field property_drawer org-roam.core.parser.PropertyDrawer
local M = {}
M.__index = M

---Creates a new section.
---@param range org-roam.core.parser.Range
---@param property_drawer org-roam.core.parser.PropertyDrawer
---@return org-roam.core.parser.Section
function M:new(range, property_drawer)
    local instance = {}
    setmetatable(instance, M)

    instance.range = range
    instance.property_drawer = property_drawer

    return instance
end

return M
