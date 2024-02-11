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
    -- TODO: Write logic to parse aliases, and general org text
    --
    -- a b c would be three separate aliases
    -- "a b c" would be a single alias
    -- a "b c" d would be three separate aliases
    return {}
end

---Parses a collection of tags separated by colons into a list of tags.
---@param tags string
---@return string[]
function M.parse_tags(tags)
    return vim.split(tags, ":", { trimempty = true })
end

return M
