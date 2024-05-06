-------------------------------------------------------------------------------
-- PACKED_VALUE.LUA
--
-- Utility for packing values.
-------------------------------------------------------------------------------

local vim = vim

---@class org-roam.core.utils.promise.PackedValue
---@field private __values table
local M = {}
M.__index = M

function M:new(...)
    local values = vim.F.pack_len(...)
    local tbl = { __values = values }
    return setmetatable(tbl, M)
end

function M:pcall(f)
    local ok_and_value = function(ok, ...)
        return ok, M.new(...)
    end
    return ok_and_value(pcall(f, self:unpack()))
end

function M:unpack()
    return vim.F.unpack_len(self.__values)
end

function M:first()
    local first = self:unpack()
    return first
end

return M
