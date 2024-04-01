-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- Utility functions to help streamline parsing orgmode node contents.
-------------------------------------------------------------------------------

local M = {}

---Parses the value of a property, properly handling double-quoted content,
---
---Supports escaping quotes using \" as this appears to be what org-roam does.
---returning a list of entries.
---@param value string
---@return string[]
function M.parse_property_value(value)
    local items = {}
    local QUOTE = string.byte("\"")
    local SPACE = string.byte(" ")
    local BACKSLASH = string.byte("\\")

    local i = 1
    local j = 0

    ---Adds an item using the current i & j
    local function add_item()
        if i > j then return end
        local item = vim.trim(string.sub(value, i, j))
        if item ~= "" then
            table.insert(items, item)
        end
    end

    local within_quote = false
    for idx = 1, string.len(value) do
        local b = string.byte(value, idx)

        -- Unescaped quote is a " not preceded by \
        local unescaped_quote = b == QUOTE and (
            idx == 1
            or string.byte(value, idx - 1) ~= BACKSLASH
        )

        if unescaped_quote or (b == SPACE and not within_quote) then
            add_item()

            -- Adjust start to be after quote or space
            i = idx + 1

            -- Update whether or not we are inside a quote
            if unescaped_quote then
                within_quote = not within_quote
            end
        end

        -- Grow current item
        j = idx
    end

    -- If we didn't add an item for the last part, do so
    if i <= j then
        add_item()
    end

    -- Remove any escaped quotes \" from the items
    return vim.tbl_map(function(item)
        item = string.gsub(item, "\\\"", "\"")
        return item
    end, items)
end

return M
