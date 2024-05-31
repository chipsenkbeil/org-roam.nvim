describe("org-roam.core.utils.io", function()
    local utils_io = require("org-roam.core.utils.io")
    local join_path = require("org-roam.core.utils.path").join

    ---Reads data of a temporary file and then deletes it.
    ---@param path string
    ---@param opts? {keep?:boolean}
    ---@return string
    local function read_temp_file(path, opts)
        opts = opts or {}
        local f = assert(io.open(path, "r"))
        local data = f:read("*a")
        f:close()

        if not opts.keep then
            os.remove(path)
        end

        return data
    end

    ---@param path string
    ---@param ...string|number
    ---@return string path
    local function write_temp_file(path, ...)
        local f = assert(io.open(path, "w"))
        f:write(...)
        f:close()
        return path
    end

    ---@param ...string|number
    ---@return string path
    local function create_temp_file(...)
        local path = vim.fn.tempname()
        write_temp_file(path, ...)
        return path
    end

    ---Creates a new temporary directory.
    ---@param ...string
    ---@return string path
    local function create_temp_dir(...)
        local tempname = vim.fn.tempname()
        local root = vim.fs.dirname(tempname)
        local filename = "temp-" .. vim.fs.basename(tempname)

        local name = join_path(...)
        local path = join_path(root, name ~= "" and name or filename)
        assert(vim.fn.mkdir(path, "p"), "Failed to create " .. path)
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
            local path = create_temp_file("hello world")
            local err, data = utils_io.read_file_sync(path)
            assert.is_nil(err)
            assert.are.equal("hello world", data)
        end)
    end)

    describe("write_file", function()
        it("should fail if file does not exist", function()
            local error, data
            local is_done = false

            local path = vim.fn.tempname()
            utils_io
                .read_file(path)
                :next(function(d)
                    data = d
                    return d
                end)
                :catch(function(err)
                    error = err
                end)
                :finally(function()
                    is_done = true
                end)

            vim.wait(10000, function()
                return is_done
            end)

            assert.is_not_nil(error)
            assert.is_nil(data)
        end)

        it("should read full file's data", function()
            local error, data
            local is_done = false

            local path = create_temp_file("hello world")
            utils_io
                .read_file(path)
                :next(function(d)
                    data = d
                    return d
                end)
                :catch(function(err)
                    error = err
                end)
                :finally(function()
                    is_done = true
                end)

            vim.wait(10000, function()
                return is_done
            end)

            assert.is_nil(error)
            assert.are.equal("hello world", data)
        end)
    end)

    describe("write_file_sync", function()
        it("should create a file if none exists", function()
            local path = vim.fn.tempname()

            local err = utils_io.write_file_sync(path, "hello world")
            assert.is_nil(err)

            local data = read_temp_file(path)
            assert.are.equal("hello world", data)
        end)

        it("should overwrite a file if it exists", function()
            local path = create_temp_file("test")

            local err = utils_io.write_file_sync(path, "hello world")
            assert.is_nil(err)

            local data = read_temp_file(path)
            assert.are.equal("hello world", data)
        end)
    end)

    describe("write_file", function()
        it("should create a file if none exists", function()
            local error
            local is_done = false

            local path = vim.fn.tempname()
            utils_io
                .write_file(path, "hello world")
                :catch(function(err)
                    error = err
                end)
                :finally(function()
                    is_done = true
                end)

            vim.wait(10000, function()
                return is_done
            end)

            local data = read_temp_file(path)

            assert.is_nil(error)
            assert.are.equal("hello world", data)
        end)

        it("should overwrite a file if it exists", function()
            local error
            local is_done = false

            local path = create_temp_file("test")

            utils_io
                .write_file(path, "hello world")
                :catch(function(err)
                    error = err
                end)
                :finally(function()
                    is_done = true
                end)

            vim.wait(10000, function()
                return is_done
            end)

            local data = read_temp_file(path)

            assert.is_nil(error)
            assert.are.equal("hello world", data)
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
            local path = create_temp_file("test")
            local err, stat = utils_io.stat_sync(path)
            assert.is_nil(err)
            assert.is_not_nil(stat) ---@cast stat -nil

            -- Check something we can verify indicates it works as expected,
            -- which in this case is validating the modification time
            local expected = vim.fn.getftime(path)
            assert.are.equal(expected, stat.mtime.sec)
        end)
    end)

    describe("stat", function()
        it("should fail if path does not exist", function()
            local error, stat
            local is_done = false

            local path = vim.fn.tempname()
            utils_io
                .stat(path)
                :next(function(s)
                    stat = s
                    return s
                end)
                :catch(function(err)
                    error = err
                end)
                :finally(function()
                    is_done = true
                end)

            vim.wait(10000, function()
                return is_done
            end)

            assert.is_not_nil(error)
            assert.is_nil(stat)
        end)

        it("should retrieve information about the file at path", function()
            local error, stat
            local is_done = false

            local path = create_temp_file("test")
            utils_io
                .stat(path)
                :next(function(s)
                    stat = s
                    return s
                end)
                :catch(function(err)
                    error = err
                end)
                :finally(function()
                    is_done = true
                end)

            vim.wait(10000, function()
                return is_done
            end)

            assert.is_nil(error)
            assert.is_not_nil(stat) ---@cast stat -nil

            -- Check something we can verify indicates it works as expected,
            -- which in this case is validating the modification time
            local expected = vim.fn.getftime(path)
            assert.are.equal(expected, stat.mtime.sec)
        end)
    end)

    describe("walk", function()
        it("should return an iterator that yields nothing if provided path is a file", function()
            local file = create_temp_file("hello")

            local entries = utils_io.walk(file, { depth = math.huge }):collect()
            assert.are.same({}, entries)
        end)

        it("should return an iterator over directory entries", function()
            local join = join_path

            -- /root
            -- /root/dir1
            -- /root/dir1/file1
            -- /root/dir1/file2
            -- /root/dir2
            local root = create_temp_dir()
            local dir1 = create_temp_dir(root, "dir1")
            local file1 = write_temp_file(join(dir1, "file1"), "hello")
            local file2 = write_temp_file(join(dir1, "file2"), "world")
            local dir2 = create_temp_dir(root, "dir2")

            -- Get everything by using `math.huge` as depth limit
            local entries = utils_io.walk(root, { depth = math.huge }):collect()
            table.sort(entries, function(a, b)
                ---@cast a org-roam.core.utils.io.WalkEntry
                ---@cast b org-roam.core.utils.io.WalkEntry
                return a.path < b.path
            end)
            assert.are.same({
                { filename = "dir1", name = "dir1", path = dir1, type = "directory" },
                { filename = "file1", name = join("dir1", "file1"), path = file1, type = "file" },
                { filename = "file2", name = join("dir1", "file2"), path = file2, type = "file" },
                { filename = "dir2", name = "dir2", path = dir2, type = "directory" },
            }, entries)
        end)

        it("should limit entries no deeper than the depth specified", function()
            local join = join_path

            -- /root
            -- /root/dir1
            -- /root/dir1/file1
            -- /root/dir1/file2
            -- /root/dir2
            local root = create_temp_dir()
            local dir1 = create_temp_dir(root, "dir1")
            write_temp_file(join(dir1, "file1"), "hello")
            write_temp_file(join(dir1, "file2"), "world")
            local dir2 = create_temp_dir(root, "dir2")

            -- Limit depth to 1 so we just get directories
            local entries = utils_io.walk(root, { depth = 1 }):collect()
            table.sort(entries, function(a, b)
                ---@cast a org-roam.core.utils.io.WalkEntry
                ---@cast b org-roam.core.utils.io.WalkEntry
                return a.path < b.path
            end)
            assert.are.same({
                { filename = "dir1", name = "dir1", path = dir1, type = "directory" },
                { filename = "dir2", name = "dir2", path = dir2, type = "directory" },
            }, entries)
        end)
    end)
end)
