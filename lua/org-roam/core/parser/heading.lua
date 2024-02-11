-------------------------------------------------------------------------------
-- HEADING.LUA
--
-- Abstraction for an org heading.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.Heading
---@field range org-roam.core.parser.Range
---@field stars integer
---@field item? org-roam.core.parser.Slice
---@field tags? org-roam.core.parser.Slice
local M = {}
M.__index = M

---@class org-roam.core.parser.Heading.NewOpts
---@field range org-roam.core.parser.Range
---@field stars integer
---@field item org-roam.core.parser.Slice|nil
---@field tags org-roam.core.parser.Slice|nil

---Creates a new heading.
---@param opts org-roam.core.parser.Heading.NewOpts
---@return org-roam.core.parser.Heading
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.stars = opts.stars
    instance.item = opts.item
    instance.tags = opts.tags

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
