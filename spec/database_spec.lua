describe("org-roam.database", function()
    local utils = require("spec.utils")

    ---Database populated before each test.
    ---@type org-roam.Database
    local db

    ---@type string, string, string
    local one_path, two_path, three_path

    before_each(function()
        db = require("org-roam.database"):new({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = utils.make_temp_org_files_directory(),
        })
        one_path = utils.join_path(db:files_path(), "one.org")
        two_path = utils.join_path(db:files_path(), "two.org")
        three_path = utils.join_path(db:files_path(), "three.org")
    end)

    it("should support loading new files from a directory", function()
        -- Trigger initial loading of all files
        db:load():wait()

        local ids = db:ids()
        table.sort(ids)

        assert.are.same({ "1", "2", "3" }, ids)

        assert.are.same({ ["2"] = 1 }, db:get_links("1"))
        assert.are.same({ ["3"] = 1 }, db:get_links("2"))
        assert.are.same({ ["1"] = 1 }, db:get_links("3"))
        assert.are.same({ ["3"] = 1 }, db:get_backlinks("1"))
        assert.are.same({ ["1"] = 1 }, db:get_backlinks("2"))
        assert.are.same({ ["2"] = 1 }, db:get_backlinks("3"))
    end)

    it("should support loading modified files from a directory", function()
        -- Trigger initial loading of all files
        db:load():wait()

        -- Verify the initial state of the database
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))
        assert.are.same({ ["3"] = 1 }, db:get_links("2"))
        assert.are.same({ ["1"] = 1 }, db:get_links("3"))
        assert.are.same({ ["3"] = 1 }, db:get_backlinks("1"))
        assert.are.same({ ["1"] = 1 }, db:get_backlinks("2"))
        assert.are.same({ ["2"] = 1 }, db:get_backlinks("3"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of all files again
        db:load():wait()

        -- Verify the new state of the database (both links and backlinks)
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
        assert.are.same({ ["3"] = 1 }, db:get_links("2"))
        assert.are.same({ ["1"] = 1 }, db:get_links("3"))
        assert.are.same({ ["3"] = 1 }, db:get_backlinks("1"))
        assert.are.same({ ["1"] = 1 }, db:get_backlinks("2"))
        assert.are.same({ ["1"] = 1, ["2"] = 1 }, db:get_backlinks("3"))
    end)

    it("should support loading a new single file", function()
        -- Load a singular file
        db:load_file({ path = one_path }):wait()

        local ids = db:ids()
        table.sort(ids)

        assert.are.same({ "1" }, ids)

        -- Verify the new state of the database (both links and backlinks)
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))
        assert.are.same({}, db:get_backlinks("1"))
    end)

    it("should support loading a modified single file", function()
        -- Load a singular file
        db:load_file({ path = one_path }):wait()

        -- Verify the initial state of the database
        assert.are.same({ "1" }, db:ids())
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of the single file
        db:load_file({ path = one_path }):wait()

        -- Verify the new state of the database (both links and backlinks)
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
        assert.are.same({}, db:get_backlinks("1"))
    end)

    it("should support loading a modified file when loading the directory containing it", function()
        -- Load a singular file
        db:load_file({ path = one_path }):wait()

        -- Verify the initial state of the database
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))
        assert.are.same({}, db:get_backlinks("1"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of all files again
        db:load():wait()

        -- Verify the new state of the database (both links and backlinks)
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
        assert.are.same({ ["3"] = 1 }, db:get_links("2"))
        assert.are.same({ ["1"] = 1 }, db:get_links("3"))
        assert.are.same({ ["3"] = 1 }, db:get_backlinks("1"))
        assert.are.same({ ["1"] = 1 }, db:get_backlinks("2"))
        assert.are.same({ ["1"] = 1, ["2"] = 1 }, db:get_backlinks("3"))
    end)

    it("should support loading a single modified file after loading the directory containing it", function()
        -- Trigger initial loading of all files
        db:load():wait()

        -- Verify the initial state of the database
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))
        assert.are.same({ ["3"] = 1 }, db:get_links("2"))
        assert.are.same({ ["1"] = 1 }, db:get_links("3"))
        assert.are.same({ ["3"] = 1 }, db:get_backlinks("1"))
        assert.are.same({ ["1"] = 1 }, db:get_backlinks("2"))
        assert.are.same({ ["2"] = 1 }, db:get_backlinks("3"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of the single file
        db:load_file({ path = one_path }):wait()

        -- Verify the new state of the database (both links and backlinks)
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
        assert.are.same({ ["3"] = 1 }, db:get_links("2"))
        assert.are.same({ ["1"] = 1 }, db:get_links("3"))
        assert.are.same({ ["3"] = 1 }, db:get_backlinks("1"))
        assert.are.same({ ["1"] = 1 }, db:get_backlinks("2"))
        assert.are.same({ ["1"] = 1, ["2"] = 1 }, db:get_backlinks("3"))
    end)

    it("should support retrieving nodes by file", function()
        -- Trigger initial loading of all files
        db:load():wait()

        ---@param file string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(file)
            local nodes = db:find_nodes_by_file_sync(file)
            return vim.tbl_map(function(node) return node.id end, nodes)
        end

        assert.are.same({ "1" }, retrieve_ids(one_path))
        assert.are.same({ "2" }, retrieve_ids(two_path))
        assert.are.same({ "3" }, retrieve_ids(three_path))
    end)

    it("should support retrieving nodes by tag", function()
        -- Trigger initial loading of all files
        db:load():wait()

        ---@param tag string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(tag)
            local nodes = db:find_nodes_by_tag_sync(tag)
            return vim.tbl_map(function(node) return node.id end, nodes)
        end

        assert.are.same({ "1" }, retrieve_ids("one"))
        assert.are.same({ "2" }, retrieve_ids("two"))
        assert.are.same({ "3" }, retrieve_ids("three"))
    end)

    it("should support retrieving nodes by alias", function()
        -- Trigger initial loading of all files
        db:load():wait()

        ---@param alias string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(alias)
            local nodes = db:find_nodes_by_alias_sync(alias)
            return vim.tbl_map(function(node) return node.id end, nodes)
        end

        assert.are.same({ "1" }, retrieve_ids("one"))
        assert.are.same({ "2" }, retrieve_ids("two"))
        assert.are.same({ "3" }, retrieve_ids("three"))
    end)

    it("should support retrieving links by file", function()
        -- Trigger initial loading of all files
        db:load():wait()

        -- By default, this is only immediate links
        assert.are.same({ ["3"] = 1 }, db:get_file_links_sync(two_path))

        -- If we specify a depth, more links are included
        assert.are.same({ ["3"] = 1, ["1"] = 2 }, db:get_file_links_sync(two_path, {
            max_depth = 2,
        }))
    end)

    it("should support retrieving backlinks by file", function()
        -- Trigger initial loading of all files
        db:load():wait()

        -- By default, this is only immediate links
        assert.are.same({ ["1"] = 1 }, db:get_file_backlinks_sync(two_path))

        -- If we specify a depth, more links are included
        assert.are.same({ ["1"] = 1, ["3"] = 2 }, db:get_file_backlinks_sync(two_path, {
            max_depth = 2,
        }))
    end)
end)
