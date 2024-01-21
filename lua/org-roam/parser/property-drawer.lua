-------------------------------------------------------------------------------
-- PROPERTY-DRAWER.LUA
--
-- Abstraction for an org property drawer.
-------------------------------------------------------------------------------

---@class org-roam.parser.PropertyDrawer
---@field heading? org-roam.parser.Heading
---@field properties org-roam.parser.Property[]
local M = {}
M.__index = M

---Creates a new property drawer.
---@param properties org-roam.parser.Property[]
---@param heading? org-roam.parser.Heading
---@return org-roam.parser.PropertyDrawer
function M:new(properties, heading)
    local instance = {}
    setmetatable(instance, M)

    instance.properties = properties
    instance.heading = heading

    return instance
end

return M
