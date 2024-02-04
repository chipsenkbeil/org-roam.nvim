describe("utils.io", function()
    local utils_io = require("org-roam.utils.io")

    ---Reads data of a temporary file and then deletes it.
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

    describe("read_file_sync", function()
        it("should fail if file does not exist", function()
            local path = vim.fn.tempname()
            local err, data = utils_io.read_file_sync(path)
            assert.is_not_nil(err)
            assert.is_nil(data)
        end)

        it("should read full file's data", function()
            local path = write_temp_file_sync("hello world")
            local err, data = utils_io.read_file_sync(path)
            assert.is_nil(err)
            assert.equals("hello world", data)
        end)
    end)

    describe("write_file", function()
        it("should fail if file does not exist", function()
            local error, data
            local is_done = false

            local path = vim.fn.tempname()
            utils_io.read_file(path, function(err, d)
                error = err
                data = d
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            assert.is_not_nil(error)
            assert.is_nil(data)
        end)

        it("should read full file's data", function()
            local error, data
            local is_done = false

            local path = write_temp_file_sync("hello world")
            utils_io.read_file(path, function(err, d)
                error = err
                data = d
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            assert.is_nil(error)
            assert.equals("hello world", data)
        end)
    end)

    describe("write_file_sync", function()
        it("should create a file if none exists", function()
            local path = vim.fn.tempname()

            local err = utils_io.write_file_sync(path, "hello world")
            assert.is_nil(err)

            local data = read_temp_file_sync(path)
            assert.equals("hello world", data)
        end)

        it("should overwrite a file if it exists", function()
            local path = write_temp_file_sync("test")

            local err = utils_io.write_file_sync(path, "hello world")
            assert.is_nil(err)

            local data = read_temp_file_sync(path)
            assert.equals("hello world", data)
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

            local data = read_temp_file_sync(path)

            assert.is_nil(error)
            assert.equals("hello world", data)
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

            local data = read_temp_file_sync(path)

            assert.is_nil(error)
            assert.equals("hello world", data)
        end)
    end)

    describe("stat_sync", function()
        it("should fail if path does not exist", function()
            local path = vim.fn.tempname()
            local err, stat = utils_io.stat_sync(path)
            assert.is_not_nil(err)
            assert.is_nil(stat)
        end)

        it("should retrieve information about the file at path", function()
            local path = write_temp_file_sync("test")
            local err, stat = utils_io.stat_sync(path)
            assert.is_nil(err)
            assert.is_not_nil(stat) ---@cast stat -nil

            -- Check something we can verify indicates it works as expected,
            -- which in this case is validating the modification time
            local expected = vim.fn.getftime(path)
            assert.equals(expected, stat.mtime.sec)
        end)
    end)

    describe("stat", function()
        it("should fail if path does not exist", function()
            local error, stat
            local is_done = false

            local path = vim.fn.tempname()
            utils_io.stat(path, function(err, s)
                error = err
                stat = s
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            assert.is_not_nil(error)
            assert.is_nil(stat)
        end)

        it("should retrieve information about the file at path", function()
            local error, stat
            local is_done = false

            local path = write_temp_file_sync("test")
            utils_io.stat(path, function(err, s)
                error = err
                stat = s
                is_done = true
            end)

            vim.wait(10000, function() return is_done end)

            assert.is_nil(error)
            assert.is_not_nil(stat) ---@cast stat -nil

            -- Check something we can verify indicates it works as expected,
            -- which in this case is validating the modification time
            local expected = vim.fn.getftime(path)
            assert.equals(expected, stat.mtime.sec)
        end)
    end)
end)
