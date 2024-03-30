-------------------------------------------------------------------------------
-- LINK.LUA
--
-- Abstraction for some org-roam node link.
-------------------------------------------------------------------------------

---@alias org-roam.core.nodes.LinkKind
---| "angle"
---| "plain"
---| "radio"
---| "regular"

---@class org-roam.core.nodes.Link
---@field kind org-roam.core.nodes.LinkKind
---@field range org-roam.core.nodes.Range
---@field path string
---@field description? string
local M = {}
M.__index = M

---@class org-roam.core.nodes.Link.NewOpts
---@field kind org-roam.core.nodes.LinkKind
---@field range org-roam.core.nodes.Range
---@field path string
---@field description? string

---Creates a new link.
---@param opts org-roam.core.nodes.Link.NewOpts
---@return org-roam.core.nodes.Link
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
