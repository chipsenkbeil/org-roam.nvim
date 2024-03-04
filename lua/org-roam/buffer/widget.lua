-------------------------------------------------------------------------------
-- WIDGET.LUA
--
-- Base interface for an org-roam buffer widget.
-------------------------------------------------------------------------------

---@class org-roam.buffer.Widget
local M = {}
M.__index = M

---Creates a new widget.
---@return org-roam.buffer.Widget
function M:new()
    local instance = {}
    setmetatable(instance, M)
    return instance
end

---@class org-roam.buffer.widget.ApplyOpts
---@field buffer integer
---@field database org-roam.core.database.Database
---@field node org-roam.core.database.Node

---@param opts org-roam.buffer.widget.ApplyOpts
---@diagnostic disable-next-line:unused-local
function M:apply(opts) end

return M
