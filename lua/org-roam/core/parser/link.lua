-------------------------------------------------------------------------------
-- LINK.LUA
--
-- Abstraction for some org link.
-------------------------------------------------------------------------------

---@alias org-roam.core.parser.LinkKind
---| "angle"
---| "plain"
---| "radio"
---| "regular"

---@class org-roam.core.parser.Link
---@field kind org-roam.core.parser.LinkKind
---@field range org-roam.core.parser.Range
---@field path string
---@field description? string
local M = {}
M.__index = M

---@class org-roam.core.parser.Link.NewOpts
---@field kind org-roam.core.parser.LinkKind
---@field range org-roam.core.parser.Range
---@field path string
---@field description? string

---Creates a new link.
---@param opts org-roam.core.parser.Link.NewOpts
---@return org-roam.core.parser.PropertyDrawer
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.kind = opts.kind
    instance.range = opts.range
    instance.path = opts.path
    instance.description = opts.description

    return instance
end

return M
