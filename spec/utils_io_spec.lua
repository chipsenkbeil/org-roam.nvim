describe("utils.IO", function()
    local utils_io = require("org-roam.utils.io")

    ---Reads contents of a temporary file and then deletes it.
    ---@param path string
    ---@param opts? {keep?:boolean}
    ---@return string
    local function read_temp_file_sync(path, opts)
        opts = opts or {}
        local f = assert(io.open(path, "r"))
        local data = f:read("*a")
        f:close()

        if not opts.keep then
            os.remove(path)
        end

        return data
    end

    ---@param ...string|number
    ---@return string path
    local function write_temp_file_sync(...)
        local path = vim.fn.tempname()
        local f = assert(io.open(path, "w"))
        f:write(...)
        f:close()
        return path
    end

    describe("read_file", function()
        it("should fail if file does not exist", function()
        end)

        it("should read full file's contents", function()
        end)
    end)

    describe("write_file", function()
        it("should create a file if none exists", function()
            local error
            local is_done = false

            local path = vim.fn.tempname()
            utils_io.write_file(path, "hello world", function(err)
                error = err
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            local contents = read_temp_file_sync(path)

            assert.is_nil(error)
            assert.equals("hello world", contents)
        end)

        it("should overwrite a file if it exists", function()
            local error
            local is_done = false

            local path = write_temp_file_sync("test")

            utils_io.write_file(path, "hello world", function(err)
                error = err
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            local contents = read_temp_file_sync(path)

            assert.is_nil(error)
            assert.equals("hello world", contents)
        end)
    end)
end)
