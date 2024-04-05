-------------------------------------------------------------------------------
-- RANGE.LUA
--
-- Abstraction for a range within some text.
-------------------------------------------------------------------------------

---@class org-roam.core.file.Position
---@field row integer #zero-based row position
---@field column integer #zero-based column position (within row)
---@field offset integer #zero-based byte position

---@class org-roam.core.file.Range
---@field start org-roam.core.file.Position #inclusive beginning to range
---@field end_ org-roam.core.file.Position #inclusive end to range
local M = {}
M.__index = M

---Creates a new range.
---@param start org-roam.core.file.Position
---@param end_ org-roam.core.file.Position
---@return org-roam.core.file.Range
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
---@param range org-roam.core.file.Range
---@return boolean
function M:contains(range)
    return (
        self.start.offset <= range.start.offset
        and self.end_.offset >= range.end_.offset
    )
end

---Creates a range from a treesitter node.
---@param node TSNode
---@return org-roam.core.file.Range
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

---Converts from an nvim-orgmode OrgFile and OrgRange into an org-roam Range.
---@param file OrgFile #contains lines which we use to reconstruct offsets
---@param range OrgRange #one-indexed row and column data
---@return org-roam.core.file.Range
function M:from_org_file_and_range(file, range)
    local start = {
        row = range.start_line - 1,
        column = range.start_col - 1,
        offset = range.start_col - 1,
    }

    local end_ = {
        row = range.end_line - 1,
        column = range.end_col - 1,
        offset = range.end_col - 1,
    }

    -- Reverse engineer the starting offset by adding
    -- the length of each line + a newline character
    -- up until the line we are on
    for i = 1, range.start_line - 1 do
        local line = file.lines[i]
        if not line then break end
        start.offset = start.offset + string.len(line) + 1
    end

    -- Reverse engineer the ending offset by adding
    -- the length of each line + a newline character
    -- up until the line we are on
    for i = 1, range.end_line - 1 do
        local line = file.lines[i]
        if not line then break end
        end_.offset = end_.offset + string.len(line) + 1
    end

    return M:new(start, end_)
end

return M
