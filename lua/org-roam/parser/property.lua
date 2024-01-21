-------------------------------------------------------------------------------
-- PROPERTY.LUA
--
-- Abstraction for an org property within a property drawer.
-------------------------------------------------------------------------------

---@class org-roam.parser.Property
---@field range org-roam.parser.Range
---@field name org-roam.parser.Slice #slice representing inside of colons
---@field value org-roam.parser.Slice #slice representing value
local M = {}
M.__index = M

---@class org-roam.parser.Property.NewOpts
---@field range org-roam.parser.Range
---@field name org-roam.parser.Slice
---@field value org-roam.parser.Slice

---Creates a new property.
---@param opts org-roam.parser.Property.NewOpts
---@return org-roam.parser.PropertyDrawer
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.name = opts.name
    instance.value = opts.value

    return instance
end

return M
