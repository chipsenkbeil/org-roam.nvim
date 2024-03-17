---Creates a temporary file, optionally populated with `contents`, and passes its path to `f`.
---
---Once `f` has finished executing, the file is cleaned up. Any error will be bubbled up after cleanup.
---@param f fun(path:string)
---@param contents? string
local function with_temp_file(f, contents)
    -- Create a temporary file
    local path = vim.fn.tempname()
    local file = assert(io.open(path, "w"), "Failed to open temporary file")
    file:write(contents or "")
    file:close()

    local ok, err = pcall(f, path)

    -- Delete the file before we finish the test
    assert(os.remove(path), "Failed to remove temporary file")

    -- Fail with error if not succeeding
    assert(ok, err)
end

describe("org-roam.core.database.file", function()
    local File = require("org-roam.core.database.file")

    describe("new()", function()
        it("should fail if strict and file does not exist", function()
            assert.has_error(function()
                File:new(vim.fn.tempname(), { strict = true })
            end)
        end)
    end)

    describe("path()", function()
        it("should return the normalized path to the file", function()
            local file = File:new("~/path/to/file.txt")
            local tilde = vim.fs.normalize("~")
            assert.are.equal(tilde .. "/path/to/file.txt", file:path())
        end)
    end)

    describe("exists()", function()
        it("should return true if the file exists and is readable", function()
            with_temp_file(function(path)
                assert.is_true(File:new(path):exists())
            end)
        end)

        it("should return false if the file does not exist", function()
            local path = vim.fn.tempname()
            local file = File:new(path)
            assert.is_false(file:exists())
        end)
    end)

    describe("changed()", function()
        it("should return true if mtime not calculated and checking via modified time", function()
            with_temp_file(function(path)
                local file = File:new(path)

                -- Not calculating mtime will always result in first changed being true,
                -- and subsequent checks (unless mtime changed) being false
                assert.is_true(file:changed())
                assert.is_false(file:changed())
            end)
        end)

        it("should return true if checksum not calculated and checking via checksum", function()
            with_temp_file(function(path)
                local file = File:new(path)

                -- Not calculating checksum will always result in first changed being true,
                -- and subsequent checks (unless checksum changed) being false
                assert.is_true(file:changed({ checksum = true }))
                assert.is_false(file:changed({ checksum = true }))
            end)
        end)

        it("should return true if using mtime and the file has been modified since last calculation", function()
            with_temp_file(function(path)
                -- Load file with checksum & mtime calculated
                local file = File:new(path, { checksum = true, mtime = true })

                -- Wait a second since mtime is in seconds, meaning we can't determine an mtime change otherwise
                vim.wait(1000)

                -- Both mtime and checksum are now loaded, so let's change the
                -- timestamp, but not the content and verify
                local f = assert(io.open(path, "w"), "Failed to open temp file to overwrite it")
                assert(f:write(""), "Failed to overwrite temp file")
                assert(f:close(), "Failed to close change to time file")

                -- Checking by timestamp should show as modified, even if checksum is the same
                assert.is_true(file:changed())
                assert.is_false(file:changed({ checksum = true }))
            end)
        end)

        it("should return true if using checksum and the file's content has been modified since last calculation",
            function()
                with_temp_file(function(path)
                    -- Load file with checksum & mtime calculated
                    local file = File:new(path, { checksum = true, mtime = true })

                    -- Wait a second since mtime is in seconds, meaning we can't determine an mtime change otherwise
                    vim.wait(1000)

                    -- Both mtime and checksum are now loaded, so let's change the content and verify
                    local f = assert(io.open(path, "w"), "Failed to open temp file to overwrite it")
                    assert(f:write("test"), "Failed to overwrite temp file")
                    assert(f:close(), "Failed to close change to time file")

                    -- Checking by timestamp should show as modified, even if checksum is the same
                    assert.is_true(file:changed())
                    assert.is_true(file:changed({ checksum = true }))
                end)
            end)

        it("should return false if the mtime has not changed and checking mtime", function()
            with_temp_file(function(path)
                local file = File:new(path, { mtime = true })
                assert.is_false(file:changed())
            end)
        end)

        it("should return false if the content has not changed and checking checksum", function()
            with_temp_file(function(path)
                local file = File:new(path, { checksum = true })
                assert.is_false(file:changed({ checksum = true }))
            end)
        end)
    end)

    describe("checksum()", function()
        it("should be populated if specified during constructing file", function()
            local checksum = vim.fn.sha256("test")

            with_temp_file(function(path)
                -- If specified, checksum is loaded automatically
                assert.are.equal(checksum, File:new(path, { checksum = true }):checksum())

                -- Otherwise, it is nil
                assert.is_nil(File:new(path):checksum())
            end, "test")
        end)

        it("should be re-populated if refresh option is true", function()
            local checksum = vim.fn.sha256("test")

            with_temp_file(function(path)
                -- If specified, checksum is loaded automatically
                assert.are.equal(checksum, File:new(path):checksum({ refresh = true }))
            end, "test")
        end)
    end)

    describe("mtime()", function()
        it("should be populated if specified during constructing file", function()
            with_temp_file(function(path)
                local mtime = vim.fn.getftime(path)

                -- If specified, mtime is loaded automatically
                assert.are.equal(mtime, File:new(path, { mtime = true }):mtime())

                -- Otherwise, it is nil
                assert.is_nil(File:new(path):mtime())
            end)
        end)

        it("should be re-populated if refresh option is true", function()
            with_temp_file(function(path)
                local mtime = vim.fn.getftime(path)
                assert.are.equal(mtime, File:new(path):mtime({ refresh = true }))
            end)
        end)
    end)
end)
