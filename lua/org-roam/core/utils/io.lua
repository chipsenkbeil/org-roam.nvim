-------------------------------------------------------------------------------
-- IO.LUA
--
-- Utilities to do input/output operations.
-------------------------------------------------------------------------------

local uv = vim.uv or vim.loop

local Iterator = require("org-roam.core.utils.iterator")

local Promise = require("orgmode.utils.promise")

-- 0o644 (rw-r--r--)
-- Owner can read and write.
-- Group can read.
-- Other can read.
---@diagnostic disable-next-line:param-type-mismatch
local DEFAULT_FILE_PERMISSIONS = tonumber(644, 8)
---@cast DEFAULT_FILE_PERMISSIONS -nil

---@class org-roam.core.utils.IO
local M = {}

---Write some data synchronously to disk, creating the file or overwriting
---if it exists.
---@param path string
---@param data string|string[]
---@param opts? {timeout?:integer}
---@return string|nil err
function M.write_file_sync(path, data, opts)
    opts = opts or {}

    ---@type boolean, string|nil
    local _, err = pcall(function()
        M.write_file(path, data):wait(opts.timeout)
    end)

    return err
end

---Write some data asynchronously to disk, creating the file or overwriting
---if it exists.
---@param path string
---@param data string|string[]
---@return OrgPromise<nil>
function M.write_file(path, data)
    local dir = vim.fs.dirname(path)

    -- If the parent directory does not exist, create it
    -- using the default permissions of 0o755 (rwxr-xr-x)
    if 0 == vim.fn.isdirectory(dir) then
        vim.fn.mkdir(dir, "p")
    end

    return Promise.new(function(resolve, reject)
        uv.fs_open(path, "w", DEFAULT_FILE_PERMISSIONS, function(err, fd)
            if err then
                return vim.schedule(function()
                    reject(err)
                end)
            end

            ---@cast fd -nil
            uv.fs_write(fd, data, -1, function(err)
                if err then
                    return vim.schedule(function()
                        reject(err)
                    end)
                end

                -- Force writing of data to avoid situations where
                -- we write and then immediately try to read and get
                -- the old file contents
                uv.fs_fsync(fd, function(err)
                    if err then
                        return vim.schedule(function()
                            reject(err)
                        end)
                    end

                    uv.fs_close(fd, function(err)
                        if err then
                            return vim.schedule(function()
                                reject(err)
                            end)
                        end

                        vim.schedule(function()
                            resolve(nil)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

---Reads data synchronously to disk.
---@param path string
---@param opts? {timeout?:integer}
---@return string|nil err, string|nil data
function M.read_file_sync(path, opts)
    opts = opts or {}

    ---@type boolean, string
    local ok, data = pcall(function()
        return M.read_file(path):wait(opts.timeout)
    end)

    return not ok and data or nil, ok and data or nil
end

---Read some data asynchronously from disk.
---@param path string
---@return OrgPromise<string>
function M.read_file(path)
    return Promise.new(function(resolve, reject)
        uv.fs_open(path, "r", 0, function(err, fd)
            if err then
                return vim.schedule(function()
                    reject(err)
                end)
            end

            ---@cast fd -nil
            uv.fs_fstat(fd, function(err, stat)
                if err then
                    return vim.schedule(function()
                        reject(err)
                    end)
                end

                ---@cast stat -nil
                uv.fs_read(fd, stat.size, 0, function(err, data)
                    if err then
                        return vim.schedule(function()
                            reject(err)
                        end)
                    end

                    uv.fs_close(fd, function(err)
                        if err then
                            return vim.schedule(function()
                                reject(err)
                            end)
                        end

                        vim.schedule(function()
                            resolve(data)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

---Obtains information about the file pointed to by `path`. Read, write, or
---execute permission of the named file is not required, but all directories
---listed in the path name leading to the file must be searchable.
---@param path string
---@param opts? {timeout?:integer}
---@return string|nil err, uv.fs_stat.result|nil stat
function M.stat_sync(path, opts)
    opts = opts or {}

    ---@type boolean, string|uv.fs_stat.result
    local ok, data = pcall(function()
        return M.stat(path):wait(opts.timeout)
    end)

    if ok then
        ---@cast data -string
        return nil, data
    else
        ---@cast data string
        return data, nil
    end
end

---Obtains information about the file pointed to by `path`. Read, write, or
---execute permission of the named file is not required, but all directories
---listed in the path name leading to the file must be searchable.
---@param path string
---@return OrgPromise<uv.fs_stat.result>
function M.stat(path)
    return Promise.new(function(resolve, reject)
        uv.fs_stat(path, function(err, stat)
            if err then
                return vim.schedule(function()
                    reject(err)
                end)
            end

            vim.schedule(function()
                resolve(stat)
            end)
        end)
    end)
end

---Removes the file specified by `path`.
---@param path string
---@param opts? {timeout?:integer}
---@return string|nil err, boolean|nil success
function M.unlink_sync(path, opts)
    opts = opts or {}

    ---@type boolean, string|boolean
    local ok, data = pcall(function()
        return M.unlink(path):wait(opts.timeout)
    end)

    if ok then
        ---@cast data -string
        return nil, data
    else
        ---@cast data string
        return data, nil
    end
end

---Removes the file specified by `path`.
---@param path string
---@return OrgPromise<boolean>
function M.unlink(path)
    return Promise.new(function(resolve, reject)
        uv.fs_unlink(path, function(err, success)
            if err then
                return vim.schedule(function()
                    reject(err)
                end)
            end

            vim.schedule(function()
                resolve(success)
            end)
        end)
    end)
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
---@field resolve boolean|nil #if true, resolves paths
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
            local entry_path = vim.fs.joinpath(path, name)

            if opts.resolve then
                entry_path = vim.fn.resolve(entry_path)
            end

            entry_path = vim.fs.normalize(entry_path, { expand_env = true })

            return {
                name = name,
                filename = vim.fs.basename(name),
                path = entry_path,
                type = type,
            }
        end
    end

    return Iterator:new(vim.fs.dir(path, {
        depth = opts.depth,
        skip = opts.skip,
    })):map(map_entry)
end

return M
