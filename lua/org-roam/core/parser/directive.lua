-------------------------------------------------------------------------------
-- DIRECTIVE.LUA
--
-- Abstraction for an org directive.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.Directive
---@field range org-roam.core.parser.Range
---@field name org-roam.core.parser.Slice
---@field value org-roam.core.parser.Slice
local M = {}
M.__index = M

---@class org-roam.core.parser.Directive.NewOpts
---@field range org-roam.core.parser.Range
---@field name org-roam.core.parser.Slice
---@field value org-roam.core.parser.Slice

---Creates a new property.
---@param opts org-roam.core.parser.Directive.NewOpts
---@return org-roam.core.parser.Directive
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.name = opts.name
    instance.value = opts.value

    return instance
end

return M
