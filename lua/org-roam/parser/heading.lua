-------------------------------------------------------------------------------
-- HEADING.LUA
--
-- Abstraction for an org heading.
-------------------------------------------------------------------------------

---@class org-roam.parser.Heading
---@field range org-roam.parser.Range
---@field stars integer
local M = {}
M.__index = M

---Creates a new heading.
---@param range org-roam.parser.Range
---@param stars integer
---@return org-roam.parser.Heading
function M:new(range, stars)
    local instance = {}
    setmetatable(instance, M)

    instance.range = range
    instance.stars = stars

    return instance
end

return M
