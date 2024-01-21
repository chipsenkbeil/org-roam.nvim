-------------------------------------------------------------------------------
-- SLICE.LUA
--
-- Abstraction for some slice of content, containing the text and a range.
-------------------------------------------------------------------------------

---@class org-roam.parser.Slice
---@field text string #text represented by the range (not full text)
---@field range org-roam.parser.Range
local M = {}
M.__index = M

---Creates a new slice.
---@param text string
---@param range org-roam.parser.Range
---@return org-roam.parser.Slice
function M:new(text, range)
    local instance = {}
    setmetatable(instance, M)

    instance.text = text
    instance.range = range

    return instance
end

return M
