describe("utils.IO", function()
    local utils = require("org-roam.utils")

    describe("async_write_file", function()
        it("should create a file if none exists", function()
            local error
            local is_done = false

            local path = vim.fn.tempname()
            utils.io.async_write_file(path, "hello world", function(err)
                error = err
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            local f = assert(io.open(path, "r"))
            local contents = f:read("*a")
            f:close()

            assert.is_nil(error)
            assert.equals("hello world", contents)
        end)

        it("should overwrite a file if it exists", function()
            local error
            local is_done = false

            local path = vim.fn.tempname()
            local f = assert(io.open(path, "w"))
            f:write("test")
            f:close()

            utils.io.async_write_file(path, "hello world", function(err)
                error = err
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            f = assert(io.open(path, "r"))
            local contents = f:read("*a")
            f:close()

            assert.is_nil(error)
            assert.equals("hello world", contents)
        end)
    end)
end)
