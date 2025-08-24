-------------------------------------------------------------------------------
-- TABLE.LUA
--
-- Utilities for table operations.
-------------------------------------------------------------------------------

---@class org-roam.core.utils.Table
local M = {}

---@param ...unknown
---@return {n:integer, [integer]:unknown}
function M.pack(...)
    if type(table.pack) == "function" then
        return table.pack(...)
    else
        --NOTE: pack was not introduced until Lua 5.2,
        --      so we have to polyfill it instead.
        ---@type {n:integer, [integer]:unknown}
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

---Like `vim.tbl_get`, but supports numeric keys alongside string keys.
---@param o table Table to index
---@param ... string|number Optional strings/integers (0 or more, variadic) via which to index the table
---
---@return any Nested value indexed by key (if it exists), else nil
function M.get(o, ...)
    local keys = { ... }
    if #keys == 0 then
        return nil
    end
    for i, k in ipairs(keys) do
        o = o[k]
        if o == nil then
            return nil
        elseif type(o) ~= "table" and next(keys, i) then
            return nil
        end
    end
    return o
end

local has_v_0_10 = vim.fn.has("nvim-0.10") > 0

---Wrapper around deprecated vim.tbl_flatten.
---@param table table Table to flatten
function M.flatten(table)
    if has_v_0_10 then
        return vim.iter(table):flatten():totable()
    else
        return vim.tbl_flatten(table)
    end
end

---Wrapper around deprecated vim.tbl_islist.
---@param table table Table to check
function M.islist(table)
    if has_v_0_10 then
        return vim.islist(table)
    else
        return vim.tbl_islist(table)
    end
end
return M
