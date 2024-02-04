-------------------------------------------------------------------------------
-- HEADING.LUA
--
-- Abstraction for an org heading.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.Heading
---@field range org-roam.core.parser.Range
---@field stars integer
---@field tags? org-roam.core.parser.Slice
local M = {}
M.__index = M

---Creates a new heading.
---@param range org-roam.core.parser.Range
---@param stars integer
---@param tags org-roam.core.parser.Slice|nil
---@return org-roam.core.parser.Heading
function M:new(range, stars, tags)
    local instance = {}
    setmetatable(instance, M)

    instance.range = range
    instance.stars = stars
    instance.tags = tags

    return instance
end

---Returns a list of tags as they appear in the heading, or empty list if no tags.
---@return string[]
function M:tag_list()
    if not self.tags then
        return {}
    end

    return vim.split(self.tags:text(), ":", { trimempty = true })
end

return M
