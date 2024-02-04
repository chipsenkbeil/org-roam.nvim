-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- Contains utility functions to use throughout the codebase. Internal-only.
-------------------------------------------------------------------------------

---@class org-roam.Utils
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

---Write some content asynchronously to disk.
---The file is closed asynchronously once the contents have been written.
---@param path string
---@param contents string|string[]
---@param cb fun(err:string|nil)
function M.async_write_file(path, contents, cb)
    -- Open or create file with 0o644 (rw-r--r--)
    vim.loop.fs_open(path, "w", tonumber(644, 8), function(err, fd)
        if err then
            cb(err)
            return
        end

        assert(fd, "Impossible: file descriptor missing")

        vim.loop.fs_write(fd, contents, -1, function(err)
            if err then
                cb(err)
                return
            end

            vim.loop.fs_close(fd, function(err)
                if err then
                    cb(err)
                    return
                end

                cb(nil)
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

return M
