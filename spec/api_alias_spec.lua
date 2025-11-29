describe("org-roam.api.alias", function()
    local utils = require("spec.utils")

    ---@return OrgRoam
    local function setup_roam()
        return utils.init_plugin({ setup = true })
    end

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should be able to add the first alias to the node under cursor", function()
        local roam = setup_roam()
        local id = utils.random_id()

        local test_org_file_path = utils.make_temp_filename({
            dir = roam.config.directory,
            ext = "org",
        })

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

        -- Add the alias to the file in the buffer
        local ok = roam.api.add_alias({ alias = "other test" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ':ROAM_ALIASES: "other test"',
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to add a second alias to the node under cursor", function()
        local roam = setup_roam()
        local id = utils.random_id()

        local test_org_file_path = utils.make_temp_filename({
            dir = roam.config.directory,
            ext = "org",
        })

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Add the alias to the file in the buffer
        local ok = roam.api.add_alias({ alias = "other test" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ':ROAM_ALIASES: something "other test"',
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should not error if removing an alias from the node under cursor with no aliases", function()
        local roam = setup_roam()
        local id = utils.random_id()

        local test_org_file_path = utils.make_temp_filename({
            dir = roam.config.directory,
            ext = "org",
        })

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

        -- Remove the alias from the file in the buffer
        local ok = roam.api.remove_alias({ alias = "not there" }):wait()
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
        local roam = setup_roam()
        local id = utils.random_id()

        local test_org_file_path = utils.make_temp_filename({
            dir = roam.config.directory,
            ext = "org",
        })

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something else",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- NOTE: Because removing an alias that's not there will trigger
        --       the selection dialog, we need to mock it to cancel as
        --       soon as it opens.
        utils.mock_select_pick(function()
            return nil
        end)

        -- Remove the alias from the file in the buffer
        local ok = roam.api.remove_alias({ alias = "not there" }):wait()
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
        local roam = setup_roam()
        local id = utils.random_id()

        local test_org_file_path = utils.make_temp_filename({
            dir = roam.config.directory,
            ext = "org",
        })

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something else",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the alias from the file in the buffer
        local ok = roam.api.remove_alias({ alias = "something" }):wait()
        assert.is_true(ok)

        -- Review that buffer was updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ':ROAM_ALIASES: "else"',
            ":END:",
            "#+TITLE: Test",
        }, utils.read_buffer())
    end)

    it("should be able to remove all aliases from the node under cursor", function()
        local roam = setup_roam()
        local id = utils.random_id()

        local test_org_file_path = utils.make_temp_filename({
            dir = roam.config.directory,
            ext = "org",
        })

        -- Create our test file
        utils.write_to(test_org_file_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ALIASES: something else",
            ":END:",
            "#+TITLE: Test",
        })

        -- Load files into the database
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_org_file_path)

        -- Remove the aliases from the file in the buffer
        local ok = roam.api.remove_alias({ all = true }):wait()
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
