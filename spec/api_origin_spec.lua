describe("org-roam.api.origin", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    ---@type string, string, string
    local test_dir, test_org_file_path, one_path

    before_each(function()
        utils.init_before_test()

        roam = utils.init_plugin({
            setup = {
                directory = utils.make_temp_org_files_directory(),
            }
        })
        test_dir = roam.config.directory
        test_org_file_path = utils.make_temp_filename({
            dir = roam.config.directory,
            ext = "org",
        })
        one_path = utils.join_path(roam.config.directory, "one.org")
    end)

    after_each(function()
        utils.cleanup_after_test()
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
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Add the origin to the file in the buffer
        local ok = roam.api.add_origin({ origin = "other test" }):wait()
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
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Add the origin to the file in the buffer
        local ok = roam.api.add_origin({ origin = "other test" }):wait()
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
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the origin from the file in the buffer
        local ok = roam.api.remove_origin():wait()
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
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the origin from the file in the buffer
        local ok = roam.api.remove_origin():wait()
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
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Navigate to the previous node, which is the origin
        local prev_id = roam.api.goto_prev_node():wait()
        assert.are.equal("1", prev_id)

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
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Try to navigate to the previous node, which does nothing
        local prev_id = roam.api.goto_prev_node():wait()
        assert.is_nil(prev_id)

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
        roam.database:load():wait()

        -- Load a file used as an origin into the buffer
        vim.cmd.edit(one_path)

        -- Navigate to the next node, which is done automatically
        local next_id = roam.api.goto_next_node():wait()
        assert.are.equal("2", next_id)

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

        -- Load files into the database (force to get new files)
        roam.database:load({ force = true }):wait()

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
        local next_id = roam.api.goto_next_node():wait()
        assert.are.equal(id_2, next_id)

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
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Try to navigate to the next node, which does nothing
        local next_id = roam.api.goto_next_node():wait()
        assert.is_nil(next_id)

        -- Review that we did not move
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)
end)
