-------------------------------------------------------------------------------
-- NODE.LUA
--
-- Abstraction for an org-roam node.
-------------------------------------------------------------------------------

---@class org-roam.node.Node
local M = {}
M.__index = M

---Creates a new node.
---@param opts? {}
---@return org-roam.node.Node
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    return instance
end

return M
