-------------------------------------------------------------------------------
-- LINK.LUA
--
-- Abstraction for some org-roam node link.
-------------------------------------------------------------------------------

---@alias org-roam.core.file.LinkKind
---| "angle"
---| "plain"
---| "radio"
---| "regular"

---@class org-roam.core.file.Link
---@field kind org-roam.core.file.LinkKind
---@field range org-roam.core.file.Range
---@field path string
---@field description? string
local M = {}
M.__index = M

---@class org-roam.core.file.Link.NewOpts
---@field kind org-roam.core.file.LinkKind
---@field range org-roam.core.file.Range
---@field path string
---@field description? string

---Creates a new link.
---@param opts org-roam.core.file.Link.NewOpts
---@return org-roam.core.file.Link
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
