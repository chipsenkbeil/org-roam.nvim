-------------------------------------------------------------------------------
-- PROMISE.LUA
--
-- Utilities to operate on promises.
-------------------------------------------------------------------------------

local PackedValue = require("org-roam.core.utils.promise.packed_value")

local M = {}

---Waits for a promise to complete, throwing an error on timeout.
---
---This serves as a copy of the function from `orgmode.utils.promise`, except
---that it throws an error when the timeout is exceeded instead of returning nil.
---@generic T
---@param promise OrgPromise<T>
---@param timeout? number
---@return T
function M.wait(promise, timeout)
    local is_done = false
    local has_error = false
    local result = nil

    promise:next(function(...)
        result = PackedValue:new(...)
        is_done = true
        return ...
    end):catch(function(...)
        has_error = true
        result = PackedValue:new(...)
        is_done = true
    end)

    timeout = timeout or 5000
    local success, code = vim.wait(timeout, function()
        return is_done
    end, 1)

    local value = result and result:unpack()

    if has_error then
        return error(value)
    end

    if not success and code == -1 then
        return error("promise timeout of " .. tostring(timeout) .. "ms reached")
    elseif not success and code == -2 then
        return error("promise interrupted")
    elseif not success then
        return error("promise failed with unknown reason")
    end

    return value
end

return M
