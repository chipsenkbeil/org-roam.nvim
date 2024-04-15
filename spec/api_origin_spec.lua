describe("org-roam.api.origin", function()
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

    it("should be able to set the origin for the node under cursor", function()
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

        -- Add the origin to the file in the buffer
        local ok = api.add_origin({ origin = "other test" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: other test",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to overwrite the origin for the node under cursor", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: something",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Add the origin to the file in the buffer
        local ok = api.add_origin({ origin = "other test" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: other test",
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should not error if removing the origin from the node under cursor with no origin", function()
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

        -- Remove the origin from the file in the buffer
        local ok = api.remove_origin():wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to remove the origin from the node under cursor", function()
        local id = utils.random_id()

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: something else",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the origin from the file in the buffer
        local ok = api.remove_origin():wait()
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
