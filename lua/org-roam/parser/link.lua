-------------------------------------------------------------------------------
-- LINK.LUA
--
-- Abstraction for some org link.
-------------------------------------------------------------------------------

---@alias org-roam.parser.LinkKind
---| "angle"
---| "plain"
---| "radio"
---| "regular"

---@class org-roam.parser.Link
---@field kind org-roam.parser.LinkKind
---@field range org-roam.parser.Range
---@field path string
---@field description? string
local M = {}
M.__index = M

---@class org-roam.parser.Link.NewOpts
---@field kind org-roam.parser.LinkKind
---@field range org-roam.parser.Range
---@field path string
---@field description? string

---Creates a new link.
---@param opts org-roam.parser.Link.NewOpts
---@return org-roam.parser.PropertyDrawer
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
