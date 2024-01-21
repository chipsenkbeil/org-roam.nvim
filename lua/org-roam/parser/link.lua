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

---Creates a new link.
---@param kind org-roam.parser.LinkKind
---@param range org-roam.parser.Range
---@param path string
---@param description? string
---@return org-roam.parser.PropertyDrawer
function M:new(kind, range, path, description)
    local instance = {}
    setmetatable(instance, M)

    instance.kind = kind
    instance.range = range
    instance.path = path
    instance.description = description

    return instance
end

return M
