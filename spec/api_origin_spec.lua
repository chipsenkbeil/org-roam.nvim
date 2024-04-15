describe("org-roam.api.origin", function()
    local api = require("org-roam.api")
    local CONFIG = require("org-roam.config")
    local utils = require("spec.utils")

    ---Database populated before each test.
    ---@type org-roam.Database
    local db

    ---@type string, string, string
    local test_dir, test_org_file_path, one_path

    before_each(function()
        test_dir = utils.make_temp_org_files_directory()
        test_org_file_path = utils.make_temp_filename({
            dir = test_dir,
            ext = "org",
        })

        -- Overwrite the configuration roam directory
        CONFIG({ directory = test_dir })

        db = utils.make_db({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = test_dir,
        })

        one_path = utils.join_path(db:files_path(), "one.org")

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

    it("should be able to go to the previous node if current node has an origin", function()
        local id = utils.random_id()

        -- Create our test file with an origin
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Navigate to the previous node, which is the origin
        local ok = api.goto_prev_node():wait()
        assert.is_true(ok)

        -- Review that we moved to the origin
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("should do nothing if visiting previous node if current node has no origin", function()
        local id = utils.random_id()

        -- Create our test file with no origin
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

        -- Try to navigate to the previous node, which does nothing
        local ok = api.goto_prev_node():wait()
        assert.is_false(ok)

        -- Review that we did not move
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to go to the next node automatically if current node is used as origin in one place", function()
        -- Load files into the database
        db:load():wait()

        -- Load a file used as an origin into the buffer
        vim.cmd.edit(one_path)

        -- Navigate to the next node, which is done automatically
        local ok = api.goto_next_node():wait()
        assert.is_true(ok)

        -- Review that we moved to the next node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 2",
            ":ROAM_ALIASES: two",
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+FILETAGS: :two:",
            "",
            "[[id:3]]",
        }, utils.read_buffer())
    end)

    it("should display a selection for next node if current node is used as origin in multiple places", function()
        local id_1 = utils.random_id()
        local id_2 = utils.random_id()
        local id_3 = utils.random_id()

        local path_1 = utils.make_temp_filename({ dir = test_dir, ext = "org" })
        local path_2 = utils.make_temp_filename({ dir = test_dir, ext = "org" })
        local path_3 = utils.make_temp_filename({ dir = test_dir, ext = "org" })

        -- Create multiple test files with same origin
        utils.write_to(path_1, {
            ":PROPERTIES:",
            ":ID: " .. id_1,
            ":ROAM_ORIGIN: " .. id_3,
            ":END:",
            "#+TITLE: Multi-test One",
        })
        utils.write_to(path_2, {
            ":PROPERTIES:",
            ":ID: " .. id_2,
            ":ROAM_ORIGIN: " .. id_3,
            ":END:",
            "#+TITLE: Multi-test Two",
        })
        utils.write_to(path_3, {
            ":PROPERTIES:",
            ":ID: " .. id_3,
            ":END:",
            "#+TITLE: Multi-test Three",
        })

        -- Load files into the database
        db:load():wait()

        -- Load the base file
        vim.cmd.edit(path_3)

        -- Pick our test file as the choice
        utils.mock_select_pick(function(choices)
            for _, choice in ipairs(choices) do
                if choice.label == "Multi-test Two" then
                    return choice
                end
            end
        end)

        -- Navigate to the next node, which triggers a selection dialog
        local ok = api.goto_next_node():wait()
        assert.is_true(ok)

        -- Review that we moved to the next node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id_2,
            ":ROAM_ORIGIN: " .. id_3,
            ":END:",
            "#+TITLE: Multi-test Two",
        }, utils.read_buffer())
    end)

    it("should do nothing if visiting next node if current node is not used as origin anywhere", function()
        local id = utils.random_id()

        -- Create our test file where no one has it as an origin
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

        -- Try to navigate to the next node, which does nothing
        local ok = api.goto_next_node():wait()
        assert.is_false(ok)

        -- Review that we did not move
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)
end)
