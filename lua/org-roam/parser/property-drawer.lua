-------------------------------------------------------------------------------
-- PROPERTY-DRAWER.LUA
--
-- Abstraction for an org property drawer.
-------------------------------------------------------------------------------

---@class org-roam.parser.PropertyDrawer
---@field range org-roam.parser.Range
---@field heading? org-roam.parser.Heading
---@field properties org-roam.parser.Property[]
local M = {}
M.__index = M

---@class org-roam.parser.PropertyDrawer.NewOpts
---@field range org-roam.parser.Range
---@field properties org-roam.parser.Property[]
---@field heading? org-roam.parser.Heading

---Creates a new property drawer.
---@param opts org-roam.parser.PropertyDrawer.NewOpts
---@return org-roam.parser.PropertyDrawer
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.properties = opts.properties
    instance.heading = opts.heading

    return instance
end

return M
