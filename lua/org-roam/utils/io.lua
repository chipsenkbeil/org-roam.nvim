-------------------------------------------------------------------------------
-- IO.LUA
--
-- Utilities to do input/output operations.
-------------------------------------------------------------------------------

local async = require("org-roam.utils.async")

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
---* `time`: the milliseconds to wait for writing to finish.
---  Defaults to waiting forever.
---* `interval`: the millseconds between attempts to check that writing
---  has finished. Defaults to 200 milliseconds.
---@param path string
---@param data string|string[]
---@param opts? {time?:integer,interval?:integer}
---@return string|nil err
function M.write_file_sync(path, data, opts)
    opts = opts or {}

    local f = async.wrap(
        M.write_file,
        {
            time = opts.time,
            interval = opts.interval,
            n = 2,
        }
    )

    return f(path, data)
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

---Reads data synchronously to disk.
---
---Note: cannot be called within fast callbacks.
---
---Accepts options to configure how to wait for writing to finish.
---
---* `time`: the milliseconds to wait for writing to finish.
---  Defaults to waiting forever.
---* `interval`: the millseconds between attempts to check that writing
---  has finished. Defaults to 200 milliseconds.
---@param path string
---@param opts? {time?:integer,interval?:integer}
---@return string|nil err, string|nil data
function M.read_file_sync(path, opts)
    opts = opts or {}

    local f = async.wrap(
        M.read_file,
        {
            time = opts.time,
            interval = opts.interval,
            n = 1,
        }
    )

    return f(path)
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

---Obtains information about the file pointed to by `path`. Read, write, or
---execute permission of the named file is not required, but all directories
---listed in the path name leading to the file must be searchable.
---
---Note: cannot be called within fast callbacks.
---
---Accepts options to configure how to wait for writing to finish.
---
---* `time`: the milliseconds to wait for writing to finish.
---  Defaults to waiting forever.
---* `interval`: the millseconds between attempts to check that writing
---  has finished. Defaults to 200 milliseconds.
---@param path string
---@param opts? {time?:integer,interval?:integer}
---@return string|nil err, uv.aliases.fs_stat_table|nil stat
function M.stat_sync(path, opts)
    opts = opts or {}

    local f = async.wrap(
        M.stat,
        {
            time = opts.time,
            interval = opts.interval,
            n = 1,
        }
    )

    return f(path)
end

---Obtains information about the file pointed to by `path`. Read, write, or
---execute permission of the named file is not required, but all directories
---listed in the path name leading to the file must be searchable.
---@param path string
---@param cb fun(err:string|nil, stat:uv.aliases.fs_stat_table|nil)
function M.stat(path, cb)
    vim.loop.fs_stat(path, cb)
end

return M
