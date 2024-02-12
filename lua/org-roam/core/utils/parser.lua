-------------------------------------------------------------------------------
-- PARSER.LUA
--
-- Utilities for parsing portions of an org roam file.
-------------------------------------------------------------------------------

---@class org-roam.core.utils.Parser
local M = {}

---Parses the value of a property, properly handling double-quoted content,
---returning a list of entries.
---@param value string
---@return string[]
function M.parse_property_value(value)
    local items = {}
    local QUOTE = string.byte("\"")
    local SPACE = string.byte(" ")

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
    for idx = 1, #value do
        local b = string.byte(value, idx)

        if b == QUOTE or (b == SPACE and not within_quote) then
            add_item()

            -- Adjust start to be after quote or space
            i = idx + 1

            -- Update whether or not we are inside a quote
            if b == QUOTE then
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

    return items
end

---Parses a collection of tags separated by colons into a list of tags.
---@param tags string
---@return string[]
function M.parse_tags(tags)
    return vim.split(tags, ":", { trimempty = true })
end

return M
