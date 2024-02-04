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

---@generic T
---@param list T[]
---@param i? integer
---@param j? integer
---@return T ...
---@nodiscard
function M.unpack(list, i, j)
    if type(table.unpack) == "function" then
        return table.unpack(list, i, j)
    else
        ---@diagnostic disable-next-line:undefined-global
        return unpack(list, i, j)
    end
end

return M
