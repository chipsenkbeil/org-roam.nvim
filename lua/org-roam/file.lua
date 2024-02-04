local utils = require("org-roam.utils")

-------------------------------------------------------------------------------
-- FILE.LUA
--
-- Abstraction for an org-roam file.
-------------------------------------------------------------------------------

---@class org-roam.File
---@field private __path string normalized path to the file
---@field private __checksum? string checksum (sha256) of file's contents
---@field private __mtime? integer last mod time measured as seconds since 01/01/1970
local M = {}
M.__index = M

---Creates a file pointer. By default, this does nothing else than normalize the path.
---
---Accepts optional additional parameters:
---
---1. `checksum` - if provided, calculates the checksum for the file (ignores errors).
---2. `mtime` - if provided, calculates the last modified time for the file (ignores errors).
---3. `strict` - if provided, fails if the file does not exist.
---
---@param path string
---@param opts? {checksum?:boolean, mtime?:boolean, strict?:boolean}
---@return org-roam.File
function M:new(path, opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    -- Always normalize the path before storing it
    -- NOTE: This is not the same as canonicalizing the path.
    --       We do NOT follow symlinks or resolve '.' or '..'!
    instance.__path = vim.fs.normalize(path)

    -- If strict, ensure the file exists before doing anything else
    if opts.strict and not instance:exists() then
        error("File does not exist or is not readable at " .. path)
    end

    -- Calculate checksum, ignoring errors
    if opts.checksum then
        instance:checksum({ refresh = true })
    end

    -- Calculate modification time, ignoring errors
    if opts.mtime then
        instance:mtime({ refresh = true })
    end

    return instance
end

---Returns the normalized path to the file.
---@return string
function M:path()
    return self.__path
end

---Checks if the file exists by verifying it is readable.
---@return boolean
function M:exists()
    return vim.fn.filereadable(self.__path) ~= 0
end

---Checks if the file has changed.
---
---By default, this will compare the last calculated `mtime` with the current
---`mtime` of the file.
---
---If `checksum` is true, will instead compare file contents for changes.
---
---If this file reference has not loaded `mtime` or `checksum` when needed, it
---will be loaded and changed will return true.
---
---@param opts? {checksum?:boolean}
---@return boolean
function M:changed(opts)
    opts = opts or {}

    if opts.checksum then
        local old = self.__checksum
        local new = self:checksum({ refresh = true })
        return old ~= new
    else
        local old = self.__mtime
        local new = self:mtime({ refresh = true })
        return old ~= new
    end
end

---Loads checksum for the file, calculating it if `refresh` is true.
---
---If `strict` is true, an error is thrown if failing to calculate the
---checksum, otherwise the error is ignored and the checksum is cleared.
---
---@param opts? {refresh?:boolean, strict?:boolean}
---@return string|nil #checksum (sha256) of the file's contents
function M:checksum(opts)
    opts = opts or {}

    -- Check if we want to refresh the value
    if opts.refresh then
        -- Clear old checksum
        self.__checksum = nil

        local err, data = utils.io.read_file_sync(self.__path)
        if err then
            if opts.strict then
                error(err)
            else
                return
            end
        end

        assert(data, "impossible: missing data")
        self.__checksum = vim.fn.sha256(data)
    end

    return self.__checksum
end

---Loads the last-modified time of the file, calculating it if `refresh` is true.
---@param opts? {refresh?:boolean}
---@return integer|nil #last modified time if available
function M:mtime(opts)
    opts = opts or {}

    -- Check if we want to refresh the value
    if opts.refresh then
        -- Clear old modification time
        self.__mtime = nil

        -- Attempt to set new modification time
        local _, stat = utils.io.stat_sync(self.__path)
        if stat then
            self.__mtime = stat.mtime.sec
        end
    end

    return self.__mtime
end

return M
