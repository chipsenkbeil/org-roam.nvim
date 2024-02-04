-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- Contains utility functions to use throughout the codebase. Internal-only.
-------------------------------------------------------------------------------

---@class org-roam.Utils
local M = {}

---@type org-roam.utils.IO
M.io = require("org-roam.utils.io")

---@param m integer
---@param n integer
---@return integer
function M.random(m, n)
    return math.random(m, n)
end

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

---Read a file into memory, returning the contents asynchronously in a callback.
---The file is closed asynchronously once the contents have been read.
---@param path string
---@param cb fun(err:string|nil, contents:string|nil)
function M.async_read_file(path, cb)
    vim.loop.fs_open(path, "r", 0, function(err, fd)
        if err then
            cb(err)
            return
        end

        assert(fd, "Impossible: file descriptor missing")

        vim.loop.fs_fstat(fd, function(err, stat)
            if err then
                cb(err)
                return
            end

            assert(stat, "Impossible: file stat missing")

            vim.loop.fs_read(fd, stat.size, 0, function(err, data)
                if err then
                    cb(err)
                    return
                end

                assert(data, "Impossible: file data missing")

                -- Schedule execution of callback in parallel to closing the
                -- file, which we will do and merely report a warning if failing
                vim.schedule(function()
                    cb(nil, data)
                end)

                vim.loop.fs_close(fd, function(err)
                    if err then
                        vim.notify(err, vim.log.levels.WARN)
                    end
                end)
            end)
        end)
    end)
end

---Creates a new queue.
---@param data? any[]
---@return org-roam.utils.Queue
function M.queue(data)
    return require("org-roam.utils.queue"):new(data)
end

---Creates a new iterator.
---@param f fun():...
---@param opts? {allow_nil?:boolean}
---@return org-roam.utils.Iterator
function M.iterator(f, opts)
    return require("org-roam.utils.iterator"):new(f, opts)
end

return M
