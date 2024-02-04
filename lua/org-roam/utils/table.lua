-------------------------------------------------------------------------------
-- TABLE.LUA
--
-- Utilities for table operations.
-------------------------------------------------------------------------------

---@class org-roam.utils.Table
local M = {}

---@param ...unknown
---@return {n:integer, [integer]:unknown}
function M.pack(...)
    if type(table.pack) == "function" then
        return table.pack(...)
    else
        --NOTE: pack was not introduced until Lua 5.2,
        --      so we have to polyfill it instead.
        local results = { ... }
        results.n = select("#", ...)
        return results
    end
end

---@param tbl table
---@return ...
function M.unpack(tbl)
    if type(table.unpack) == "function" then
        return table.unpack(tbl)
    else
        ---@diagnostic disable-next-line:undefined-global
        return unpack(tbl)
    end
end

return M
