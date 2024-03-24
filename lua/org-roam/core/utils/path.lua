-------------------------------------------------------------------------------
-- PATH.LUA
--
-- Contains utility functions to assist path building.
-------------------------------------------------------------------------------

local M = {}

-- From plenary.nvim, determines the path separator.
local SEP = (function()
    if jit then
        local os = string.lower(jit.os)
        if os ~= "windows" then
            return "/"
        else
            return "\\"
        end
    else
        return package.config:sub(1, 1)
    end
end)()

---Returns the path separator.
---@return string
function M.separator()
    return SEP
end

---Joins one or more paths together as one.
---If any path is absolute, it will replace the currently-constructed path.
---@param ...string
---@return string path
function M.join(...)
    local path = ""

    --- From plenary.nvim, determines if the path is absolute.
    ---@param filename string
    ---@return boolean
    local is_absolute = function(filename)
        if SEP == "\\" then
            return string.match(filename, "^[%a]:\\.*$") ~= nil
        end
        return string.sub(filename, 1, 1) == SEP
    end

    for _, p in ipairs({ ... }) do
        if path == "" or is_absolute(p) then
            path = p
        else
            path = path .. SEP .. p
        end
    end

    return path
end

return M
