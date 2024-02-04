-------------------------------------------------------------------------------
-- PROPERTY-DRAWER.LUA
--
-- Abstraction for an org property drawer.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.PropertyDrawer
---@field range org-roam.core.parser.Range
---@field heading? org-roam.core.parser.Heading
---@field properties org-roam.core.parser.Property[]
local M = {}
M.__index = M

---@class org-roam.core.parser.PropertyDrawer.NewOpts
---@field range org-roam.core.parser.Range
---@field properties org-roam.core.parser.Property[]
---@field heading? org-roam.core.parser.Heading

---Creates a new property drawer.
---@param opts org-roam.core.parser.PropertyDrawer.NewOpts
---@return org-roam.core.parser.PropertyDrawer
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.properties = opts.properties
    instance.heading = opts.heading

    return instance
end

return M
