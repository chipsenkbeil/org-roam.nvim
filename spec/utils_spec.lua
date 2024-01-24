describe("utils", function()
    local utils = require("org-roam.utils")

    describe("uuid_v4", function()
        it("should generate a random uuid", function()
            local uuid = utils.uuid_v4()
            local pattern = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-[89ab]%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

            -- print("Checking " .. vim.inspect(uuid))
            local i, j = string.find(uuid, pattern)

            -- Check start and end of a 36 character uuid string,
            -- which will fail if no match is found as i/j will be nil
            assert.equals(1, i)
            assert.equals(36, j)
        end)
    end)

    describe("async_read_file", function()
        it("should return an error if file missing", function()
            local has_error = false
            local is_done = false

            utils.async_read_file(vim.fn.tempname(), function(err)
                has_error = err ~= nil
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            assert.is_true(has_error)
        end)

        it("should return file contents on success", function()
            local contents
            local is_done = false

            local path = vim.fn.tempname()
            local f = assert(io.open(path, "w"))
            f:write("test")
            f:close()

            utils.async_read_file(path, function(_, data)
                contents = data
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            assert.equals("test", contents)
        end)
    end)

    describe("async_write_file", function()
        it("should create a file if none exists", function()
            local error
            local is_done = false

            local path = vim.fn.tempname()
            utils.async_write_file(path, "hello world", function(err)
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

            utils.async_write_file(path, "hello world", function(err)
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
