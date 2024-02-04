-------------------------------------------------------------------------------
-- PROPERTY.LUA
--
-- Abstraction for an org property within a property drawer.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.Property
---@field range org-roam.core.parser.Range
---@field name org-roam.core.parser.Slice #slice representing inside of colons
---@field value org-roam.core.parser.Slice #slice representing value
local M = {}
M.__index = M

---@class org-roam.core.parser.Property.NewOpts
---@field range org-roam.core.parser.Range
---@field name org-roam.core.parser.Slice
---@field value org-roam.core.parser.Slice

---Creates a new property.
---@param opts org-roam.core.parser.Property.NewOpts
---@return org-roam.core.parser.Property
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.name = opts.name
    instance.value = opts.value

    return instance
end

return M
