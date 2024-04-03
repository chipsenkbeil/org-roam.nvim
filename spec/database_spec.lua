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
    end)

    it("should support loading modified files from a directory", function()
        -- Trigger initial loading of all files
        db:load():wait()

        -- Verify the initial state of the file
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of all files again
        db:load():wait()

        -- Verify the new state of the file
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
    end)

    it("should support loading a new single file", function()
        -- Load a singular file
        db:load_file({ path = one_path }):wait()

        local ids = db:ids()
        table.sort(ids)

        assert.are.same({ "1" }, ids)
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))
    end)

    it("should support loading a modified single file", function()
        -- Load a singular file
        db:load_file({ path = one_path }):wait()

        -- Verify the initial state of the file
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of the single file
        db:load_file({ path = one_path }):wait()

        -- Verify the new state of the file
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
    end)

    it("should support loading a modified file when loading the directory containing it", function()
        -- Load a singular file
        db:load_file({ path = one_path }):wait()

        -- Verify the initial state of the file
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of all files again
        db:load():wait()

        -- Verify the new state of the file
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
    end)

    it("should support loading a single modified file after loading the directory containing it", function()
        -- Trigger initial loading of all files
        db:load():wait()

        -- Verify the initial state of the file
        assert.are.same({ ["2"] = 1 }, db:get_links("1"))

        -- Add a second link to a file
        utils.append_to(one_path, "[[id:3]]")

        -- Trigger a reload of the single file
        db:load_file({ path = one_path }):wait()

        -- Verify the new state of the file
        assert.are.same({ ["2"] = 1, ["3"] = 1 }, db:get_links("1"))
    end)
end)
