local Range = require("org-roam.core.parser.range")
local Ref = require("org-roam.core.parser.ref")

-------------------------------------------------------------------------------
-- SLICE.LUA
--
-- Abstraction for some slice of content, containing the text and a range.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.Slice
---@field private __full org-roam.core.parser.Ref<string> #reference to full text
---@field private __cache string #cache to the text represented by this slice
---@field private __range org-roam.core.parser.Range
local M = {}
M.__index = M

---Creates a new slice for the given text using the provided range as the subset.
---@param text org-roam.core.parser.Ref<string> #full text comprising the slice
---@param range org-roam.core.parser.Range
---@param opts? {cache?:string}
---@return org-roam.core.parser.Slice
function M:new(text, range, opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    instance.__full = text
    instance.__cache = opts.cache
    instance.__range = range

    return instance
end

---Creates a new slice for the given range using the same contents.
---@param range org-roam.core.parser.Range
---@return org-roam.core.parser.Slice
function M:slice(range)
    return M:new(self.__full, range)
end

---Creates a new slice encompassing an entire string reference.
---@param ref org-roam.core.parser.Ref<string>
---@return org-roam.core.parser.Slice
function M:from_ref(ref)
    -- Calculate the range of the string by checking how
    -- many lines it has and how many characters on the
    -- last line to serve as the ending column.
    --
    -- Keep in mind that our range is INCLUSIVE for the end!
    local text_len = string.len(ref.value)

    ---@type integer|nil
    local newline_offset
    local line_cnt = 1

    ---@type integer|nil
    local i = 0
    while true do
        i = string.find(ref.value, "\n", i + 1)
        if i == nil then break end

        -- Adjust offset to be zero-indexed
        newline_offset = i - 1

        -- Increment total lines since we found another newline
        line_cnt = line_cnt + 1
    end

    local range = Range:new({
        row = 0,
        column = 0,
        -- NOTE: We have to handle empty string as a special case
        --       where the offset is -1 to match how vim reports
        --       the byte offset of an empty file, otherwise the
        --       starting offset is 0 to indicate the beginning.
        offset = text_len > 0 and 0 or -1,
    }, {
        -- Final row (line) in text, zero-indexed
        row = line_cnt - 1,
        -- Final column in last line of text, zero-indexed
        column = newline_offset and (text_len - newline_offset - 2) or (text_len - 1),
        -- Final byte offset of text, zero-indexed
        offset = text_len - 1,
    })

    -- NOTE: If column ends up being negative, this means that our text
    --       ended with a newline, so we reset to a column of 0 to match
    --       how the vim cursor would appear (minus the 1-based indexing).
    if range.end_.column < 0 then
        range.end_.column = 0
    end

    return M:new(ref, range)
end

---Creates a new slice encompassing an entire string.
---@param text string
---@return org-roam.core.parser.Slice
function M:from_string(text)
    local ref = Ref:new(text)
    return M:from_ref(ref)
end

---Returns copy of text represented by the slice.
---Note that this is cached after first calculation, unless an option is provided to force refresh.
---@param opts? {refresh?:boolean}
---@return string
function M:text(opts)
    opts = opts or {}

    -- Calculate the actual text if not cached or forcing refresh
    if not self.__cache or opts.refresh then
        -- NOTE: Range values are zero-indexed, so we need to transform them
        --       into Lua's one-indexed version!
        self.__cache = string.sub(
            self.__full.value,
            self.__range.start.offset + 1,
            self.__range.end_.offset + 1
        )
    end

    return self.__cache
end

---Returns a copy of the range represented by the slice.
---@return org-roam.core.parser.Range
function M:range()
    return vim.deepcopy(self.__range)
end

---Returns a copy of the start position of the slice.
---@return org-roam.core.parser.Position
function M:start_position()
    return vim.deepcopy(self.__range.start)
end

---Returns a copy of the end position of the slice.
---@return org-roam.core.parser.Position
function M:end_position()
    return vim.deepcopy(self.__range.end_)
end

---Returns the start row (zero-indexed) of the slice.
---@return integer
function M:start_row()
    return self.__range.start.row
end

---Returns the start column (zero-indexed) of the slice.
---@return integer
function M:start_column()
    return self.__range.start.column
end

---Returns the start byte offset (zero-indexed) of the slice.
---@return integer
function M:start_byte_offset()
    return self.__range.start.offset
end

---Returns the end row (zero-indexed) of the slice.
---@return integer
function M:end_row()
    return self.__range.end_.row
end

---Returns the end column (zero-indexed) of the slice.
---@return integer
function M:end_column()
    return self.__range.end_.column
end

---Returns the end byte offset (zero-indexed) of the slice.
---@return integer
function M:end_byte_offset()
    return self.__range.end_.offset
end

return M
