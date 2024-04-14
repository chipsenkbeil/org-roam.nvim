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

        db = utils.make_db({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = dir,
        })

        -- Patch `vim.cmd` so we can run tests here
        utils.patch_vim_cmd()
    end)

    after_each(function()
        -- Unpatch `vim.cmd` so we can have tests pass
        utils.unpatch_vim_cmd()

        -- Restore select in case we mocked it
        utils.unmock_select()
    end)

    it("should be able to add the first alias to the node under cursor", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
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
            ":ID: " .. id,
            ":ROAM_ALIASES: \"other test\"",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to add a second alias to the node under cursor", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
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
            ":ID: " .. id,
            ":ROAM_ALIASES: something \"other test\"",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should not error if removing an alias from the node under cursor with no aliases", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the alias from the file in the buffer
        local ok = api.remove_alias({ alias = "not there" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should not error if removing an invalid alias from the node under cursor", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something else",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- NOTE: Because removing an alias that's not there will trigger
        --       the selection dialog, we need to mock it to cancel as
        --       soon as it opens.
        utils.mock_select_pick(function(choices)
            return nil
        end)

        -- Remove the alias from the file in the buffer
        local ok = api.remove_alias({ alias = "not there" }):wait()
        assert.is_false(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something else",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to remove an alias from the node under cursor", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something else",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the alias from the file in the buffer
        local ok = api.remove_alias({ alias = "something" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: \"else\"",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to remove all aliases from the node under cursor", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something else",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the aliases from the file in the buffer
        local ok = api.remove_alias({ all = true }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)
end)
