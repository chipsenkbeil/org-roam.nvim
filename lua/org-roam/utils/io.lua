-------------------------------------------------------------------------------
-- IO.LUA
--
-- Utilities to do input/output operations.
-------------------------------------------------------------------------------

-- 0o644 (rw-r--r--)
-- Owner can read and write.
-- Group can read.
-- Other can read.
---@diagnostic disable-next-line:param-type-mismatch
local DEFAULT_WRITE_PERMISSIONS = tonumber(644, 8)

---@class org-roam.utils.IO
local M = {}

---Write some data synchronously to disk, creating the file or overwriting
---if it exists.
---
---Note: cannot be called within fast callbacks.
---
---Accepts options to configure how to wait for writing to finish.
---
---    1. timeout:  the milliseconds to wait for writing to finish. Defaults
---                 to waiting forever.
---    2. interval: the millseconds between attempts to check that writing
---                 has finished. Defaults to 200 milliseconds.
---@param path string
---@param data string|string[]
---@param opts? {timeout?:integer,interval?:integer}
---@return string|nil err
function M.write_file_sync(path, data, opts)
    opts = opts or {}

    local TIMEOUT = opts.timeout or math.huge
    local INTERVAL = opts.interval

    local results = { done = false }
    M.write_file(path, data, function(err)
    end)

    vim.wait()
end

---Write some data asynchronously to disk, creating the file or overwriting
---if it exists.
---@param path string
---@param data string|string[]
---@param cb fun(err:string|nil)
function M.write_file(path, data, cb)
    -- Open or create file with 0o644 (rw-r--r--)
    vim.loop.fs_open(path, "w", DEFAULT_WRITE_PERMISSIONS, function(err, fd)
        if err then
            cb(err)
            return
        end

        assert(fd, "Impossible: file descriptor missing")

        vim.loop.fs_write(fd, data, -1, function(err)
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

---Read some data asynchronously from disk.
---@param path string
---@param cb fun(err:string|nil, data:string|nil)
function M.read_file(path, cb)
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

                vim.loop.fs_close(fd, function(err)
                    if err then
                        cb(err)
                        return
                    end

                    cb(nil, data)
                end)
            end)
        end)
    end)
end

return M
