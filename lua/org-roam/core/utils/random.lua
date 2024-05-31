-------------------------------------------------------------------------------
-- RANDOM.LUA
--
-- Contains utility functions to assist with random generation.
-------------------------------------------------------------------------------

---@class org-roam.core.utils.Random
local M = {}
local seeded = false

---@param m integer
---@param n integer
---@return integer
function M.random(m, n)
    if seeded == false then
        -- https://www.lua-users.org/wiki/MathLibraryTutorial
        math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 6)))
        seeded = true
    end
    return math.random(m, n)
end

---Generates a new id. Attempts to use orgmode's id generator, but if uuid
---is desired and uuidgen is missing, will use the Lua-native implementation.
---@return string
function M.id()
    local config = require("orgmode.config")
    local is_uuid_method = config.org_id_method == "uuid"
    local has_uuidgen = vim.fn.executable(config.org_id_uuid_program) == 1
    if is_uuid_method and not has_uuidgen then
        return M.uuid_v4()
    else
        return require("orgmode.org.id").new()
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

    return string.char(require("org-roam.core.utils.table").unpack(uuid))
end

return M
