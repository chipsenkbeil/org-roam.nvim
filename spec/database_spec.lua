describe("org-roam.database", function()
    local Database = require("org-roam.database")
    local utils = require("spec.utils")

    ---@return org-roam.Database db, string one_path, string two_path, string three_path
    local function setup_db()
        local test_dir = utils.make_temp_org_files_directory({
            filter = function(entry)
                return vim.list_contains({ "one.org", "two.org", "three.org" }, entry.filename)
            end,
        })
        local one_path = vim.fs.joinpath(test_dir, "one.org")
        local two_path = vim.fs.joinpath(test_dir, "two.org")
        local three_path = vim.fs.joinpath(test_dir, "three.org")

        local db = Database:new({
            db_path = vim.fs.joinpath(test_dir, "db"),
            directory = test_dir,
            org_files = {},
        })

        return db, one_path, two_path, three_path
    end

    before_each(function()
        -- NOTE: We need to run this in this core test because org_file calls
        --       are triggering the ftplugin/org.lua, which is trying to use
        --       vim.cmd.something(...) and is failing because of a plenary issue
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should support loading new files from a directory", function()
        local db = setup_db()

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
        local db, one_path = setup_db()

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
        local db, one_path = setup_db()

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
        local db, one_path = setup_db()

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
        local db, one_path = setup_db()

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
        local db, one_path = setup_db()

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

    it("should support retrieving nodes by alias", function()
        local db = setup_db()

        -- Trigger initial loading of all files
        db:load():wait()

        ---@param alias string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(alias)
            local nodes = db:find_nodes_by_alias_sync(alias)
            return vim.tbl_map(function(node)
                return node.id
            end, nodes)
        end

        assert.are.same({ "1" }, retrieve_ids("one"))
        assert.are.same({ "2" }, retrieve_ids("two"))
        assert.are.same({ "3" }, retrieve_ids("three"))
    end)

    it("should support retrieving nodes by file", function()
        local db, one_path, two_path, three_path = setup_db()

        -- Trigger initial loading of all files
        db:load():wait()

        ---@param file string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(file)
            local nodes = db:find_nodes_by_file_sync(file)
            return vim.tbl_map(function(node)
                return node.id
            end, nodes)
        end

        assert.are.same({ "1" }, retrieve_ids(one_path))
        assert.are.same({ "2" }, retrieve_ids(two_path))
        assert.are.same({ "3" }, retrieve_ids(three_path))
    end)

    it("should support retrieving nodes by origin", function()
        local db = setup_db()

        -- Trigger initial loading of all files
        db:load():wait()

        ---@param origin string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(origin)
            local nodes = db:find_nodes_by_origin_sync(origin)
            return vim.tbl_map(function(node)
                return node.id
            end, nodes)
        end

        assert.are.same({ "2" }, retrieve_ids("1"))
        assert.are.same({ "3" }, retrieve_ids("2"))
        assert.are.same({}, retrieve_ids("3"))
    end)

    it("should support retrieving nodes by tag", function()
        local db = setup_db()

        -- Trigger initial loading of all files
        db:load():wait()

        ---@param tag string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(tag)
            local nodes = db:find_nodes_by_tag_sync(tag)
            return vim.tbl_map(function(node)
                return node.id
            end, nodes)
        end

        assert.are.same({ "1" }, retrieve_ids("one"))
        assert.are.same({ "2" }, retrieve_ids("two"))
        assert.are.same({ "3" }, retrieve_ids("three"))
    end)

    it("should support retrieving nodes by title", function()
        local db = setup_db()

        -- Trigger initial loading of all files
        db:load():wait()

        ---@param title string
        ---@return org-roam.core.database.Id[]
        local function retrieve_ids(title)
            local nodes = db:find_nodes_by_title_sync(title)
            return vim.tbl_map(function(node)
                return node.id
            end, nodes)
        end

        assert.are.same({ "1" }, retrieve_ids("one"))
        assert.are.same({ "2" }, retrieve_ids("two"))
        assert.are.same({ "3" }, retrieve_ids("three"))
    end)

    it("should support retrieving links by file", function()
        local db, _, two_path = setup_db()

        -- Trigger initial loading of all files
        db:load():wait()

        -- By default, this is only immediate links
        assert.are.same({ ["3"] = 1 }, db:get_file_links_sync(two_path))

        -- If we specify a depth, more links are included
        assert.are.same(
            { ["3"] = 1, ["1"] = 2 },
            db:get_file_links_sync(two_path, {
                max_depth = 2,
            })
        )
    end)

    it("should support retrieving backlinks by file", function()
        local db, _, two_path = setup_db()

        -- Trigger initial loading of all files
        db:load():wait()

        -- By default, this is only immediate links
        assert.are.same({ ["1"] = 1 }, db:get_file_backlinks_sync(two_path))

        -- If we specify a depth, more links are included
        assert.are.same(
            { ["1"] = 1, ["3"] = 2 },
            db:get_file_backlinks_sync(two_path, {
                max_depth = 2,
            })
        )
    end)
end)
