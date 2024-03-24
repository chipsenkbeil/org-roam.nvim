-------------------------------------------------------------------------------
-- RANGE.LUA
--
-- Abstraction for a range within some text.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.Position
---@field row integer #zero-based row position
---@field column integer #zero-based column position (within row)
---@field offset integer #zero-based byte position

---@class org-roam.core.parser.Range
---@field start org-roam.core.parser.Position #inclusive beginning to range
---@field end_ org-roam.core.parser.Position #inclusive end to range
local M = {}
M.__index = M

---Creates a new range.
---@param start org-roam.core.parser.Position
---@param end_ org-roam.core.parser.Position
---@return org-roam.core.parser.Range
function M:new(start, end_)
    local instance = {}
    setmetatable(instance, M)

    instance.start = start
    instance.end_ = end_

    return instance
end

---Returns total bytes represented by the range.
---@return integer
function M:size()
    return self.end_.offset - self.start.offset + 1
end

---Returns true if the `range` will fit within this range.
---@param range org-roam.core.parser.Range
---@return boolean
function M:contains(range)
    return (
        self.start.offset <= range.start.offset
        and self.end_.offset >= range.end_.offset
    )
end

---Creates a range from a treesitter node.
---@param node TSNode
---@return org-roam.core.parser.Range
function M:from_node(node)
    local start_row, start_col, start_offset = node:start()
    local end_row, end_col, end_offset = node:end_()
    return M:new(
        {
            row = start_row,
            column = start_col,
            offset = start_offset
        },
        {
            row = end_row,
            column = end_col,
            offset = end_offset
        }
    )
end

---Converts from an nvim-orgmode OrgRange into an org-roam Range.
---@param range OrgRange
---@return org-roam.core.parser.Range
function M:from_org_range(range)
end

return M
