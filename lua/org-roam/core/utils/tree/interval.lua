-------------------------------------------------------------------------------
-- INTERVAL.LUA
--
-- Abstraction of an interval tree.
-------------------------------------------------------------------------------

---@alias org-roam.core.utils.tree.interval.Interval {[1]: integer, [2]: integer}

---@class org-roam.core.utils.tree.IntervalTree
---@field data any
---@field start integer
---@field end_ integer
---@field max_end integer
---@field left? org-roam.core.utils.tree.IntervalTree
---@field right? org-roam.core.utils.tree.IntervalTree
local M = {}
M.__index = M

---Creates a new instance of the tree.
---@param interval org-roam.core.utils.tree.interval.Interval
---@param data any
---@return org-roam.core.utils.tree.IntervalTree
function M:new(interval, data)
    local instance = {}
    setmetatable(instance, M)
    instance.data = data
    instance.start = interval[1]
    instance.end_ = interval[2]
    instance.max_end = interval[2]
    return instance
end

---@param interval org-roam.core.utils.tree.interval.Interval
---@param data any
---@return org-roam.core.utils.tree.IntervalTree
function M:insert(interval, data)
end

return M
