-------------------------------------------------------------------------------
-- HEADING.LUA
--
-- Abstraction for an org heading.
-------------------------------------------------------------------------------

---@class org-roam.parser.Heading
---@field range org-roam.parser.Range
---@field stars integer
---@field tags? org-roam.parser.Slice
local M = {}
M.__index = M

---Creates a new heading.
---@param range org-roam.parser.Range
---@param stars integer
---@param tags org-roam.parser.Slice|nil
---@return org-roam.parser.Heading
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
