-------------------------------------------------------------------------------
-- IO.LUA
--
-- Utilities to do input/output operations.
-------------------------------------------------------------------------------

local uv = vim.loop

local async = require("org-roam.core.utils.async")
local Iterator = require("org-roam.core.utils.iterator")

-- 0o644 (rw-r--r--)
-- Owner can read and write.
-- Group can read.
-- Other can read.
---@diagnostic disable-next-line:param-type-mismatch
local DEFAULT_WRITE_PERMISSIONS = tonumber(644, 8)

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

---@class org-roam.core.utils.IO
local M = {}

---Write some data synchronously to disk, creating the file or overwriting
---if it exists.
---
---Note: cannot be called within fast callbacks.
---
---Accepts options to configure how to wait.
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
    uv.fs_open(path, "w", DEFAULT_WRITE_PERMISSIONS, function(err, fd)
        if err then
            cb(err)
            return
        end

        assert(fd, "Impossible: file descriptor missing")

        uv.fs_write(fd, data, -1, function(err)
            if err then
                cb(err)
                return
            end

            uv.fs_close(fd, function(err)
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
---Accepts options to configure how to wait.
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
    uv.fs_open(path, "r", 0, function(err, fd)
        if err then
            cb(err)
            return
        end

        assert(fd, "Impossible: file descriptor missing")

        uv.fs_fstat(fd, function(err, stat)
            if err then
                cb(err)
                return
            end

            assert(stat, "Impossible: file stat missing")

            uv.fs_read(fd, stat.size, 0, function(err, data)
                if err then
                    cb(err)
                    return
                end

                uv.fs_close(fd, function(err)
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
---Accepts options to configure how to wait.
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
    uv.fs_stat(path, cb)
end

---Joins one or more paths together as one.
---If any path is absolute, it will replace the currently-constructed path.
---@param ...string
---@return string path
function M.join_path(...)
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

---@alias org-roam.core.utils.io.WalkEntryType
---|'"file"'
---|'"directory"'
---|'"link"'
---|'"fifo"'
---|'"socket"'
---|'"char"'
---|'"block"'
---|'"unknown"'

---@class org-roam.core.utils.io.WalkEntry
---@field name string #entry name, which is path portion within search
---@field filename string #name stripped down to use filename
---@field path string #full path to file
---@field type org-roam.core.utils.io.WalkEntryType

---@class org-roam.core.utils.io.WalkOpts
---@field depth integer|nil #how deep the traverse (default 1)
---@field skip (fun(dir_name: string): boolean)|nil #predicate

---Walks the provided `path`, returning an iterator over the entries.
---
---Traversal has no guaranteed order, and a directory's contents are
---fully traversed before entering subdirectories.
---@param path string
---@param opts? org-roam.core.utils.io.WalkOpts
---@return org-roam.core.utils.Iterator
function M.walk(path, opts)
    opts = opts or {}

    ---@param name string?
    ---@param type ("directory"|"file")?
    ---@return org-roam.core.utils.io.WalkEntry?
    local function map_entry(name, type)
        if name and type then
            return {
                name     = name,
                filename = vim.fs.basename(name),
                path     = M.join_path(path, name),
                type     = type,
            }
        end
    end

    return Iterator:new(vim.fs.dir(path, {
        depth = opts.depth,
        skip = opts.skip,
    })):map(map_entry)
end

return M
