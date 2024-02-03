-------------------------------------------------------------------------------
-- DIRECTIVE.LUA
--
-- Abstraction for an org directive.
-------------------------------------------------------------------------------

---@class org-roam.parser.Directive
---@field range org-roam.parser.Range
---@field name org-roam.parser.Slice
---@field value org-roam.parser.Slice
local M = {}
M.__index = M

---@class org-roam.parser.Directive.NewOpts
---@field range org-roam.parser.Range
---@field name org-roam.parser.Slice
---@field value org-roam.parser.Slice

---Creates a new property.
---@param opts org-roam.parser.Directive.NewOpts
---@return org-roam.parser.Directive
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.name = opts.name
    instance.value = opts.value

    return instance
end

return M
