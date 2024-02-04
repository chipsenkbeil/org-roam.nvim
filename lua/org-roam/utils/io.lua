-------------------------------------------------------------------------------
-- IO.LUA
--
-- Utilities to do input/output operations.
-------------------------------------------------------------------------------

-- 0o644 (rw-r--r--)
-- Owner can read and write.
-- Group can read.
-- Other can read.
local DEFAULT_WRITE_PERMISSIONS = tonumber(644, 8)

---@class org-roam.utils.IO
local M = {}

---Write some content asynchronously to disk.
---The file is closed asynchronously once the contents have been written.
---@param path string
---@param contents string|string[]
---@param cb fun(err:string|nil)
function M.async_write_file(path, contents, cb)
    -- Open or create file with 0o644 (rw-r--r--)
    vim.loop.fs_open(path, "w", DEFAULT_WRITE_PERMISSIONS, function(err, fd)
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

return M
