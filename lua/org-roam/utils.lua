-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- Contains utility functions to use throughout the codebase. Internal-only.
-------------------------------------------------------------------------------

local M = {}

---@param m integer
---@param n integer
---@return integer
function M.random(m, n)
    return math.random(m, n)
end

---@param tbl table
---@return ...
function M.unpack(tbl)
    if type(table.unpack) == "function" then
        return table.unpack(tbl)
    else
        return unpack(tbl)
    end
end

---@return string #random uuid (v4)
function M.uuid_v4()
    ---@type integer[]
    local uuid = {}

    -- 00000000-0000-0000-0000-000000000000
    for i = 1, 36 do
        if i == 9 or i == 14 or i == 19 or i == 24 then
            -- Separators following pattern above
            table.insert(uuid, string.byte("-"))
        elseif i == 15 then
            -- Version indicator
            table.insert(uuid, string.byte("4"))
        else
            local n
            if i == 20 then
                -- 8, 9, A, B
                n = M.random(9, 12)
            else
                -- Any numeric character of letter between a and f
                n = M.random(1, 16)
            end

            -- 11 to 16 are alphabetic
            if n > 10 then
                -- 97 is decimal place for "a"
                table.insert(uuid, 97 + (n - 11))
            else
                -- 48 is decimal place for "0"
                table.insert(uuid, 48 + (n - 1))
            end
        end
    end

    return string.char(M.unpack(uuid))
end

return M
