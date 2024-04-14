describe("org-roam.api.alias", function()
    local api = require("org-roam.api")
    local utils = require("spec.utils")

    ---Database populated before each test.
    ---@type org-roam.Database
    local db

    ---@type string
    local test_org_file_path

    before_each(function()
        local dir = utils.make_temp_directory()
        test_org_file_path = utils.make_temp_filename({
            dir = dir,
            ext = "org",
        })

        db = require("org-roam.database"):new({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = dir,
        })

        -- Patch `vim.cmd` so we can run tests here
        utils.patch_vim_cmd()
    end)

    after_each(function()
        -- Unpatch `vim.cmd` so we can have tests pass
        utils.unpatch_vim_cmd()
    end)

    it("should be able to add the first alias to the node under cursor", function()
        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: 1234",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Add the alias to the file in the buffer
        local ok = api.add_alias({ alias = "other test" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1234",
            ":ROAM_ALIASES: \"other test\"",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to add a second alias to the node under cursor", function()
        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: 1234",
            ":ROAM_ALIASES: something",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Add the alias to the file in the buffer
        local ok = api.add_alias({ alias = "other test" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1234",
            ":ROAM_ALIASES: something \"other test\"",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)
end)
