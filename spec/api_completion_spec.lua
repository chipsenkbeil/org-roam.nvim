describe("org-roam.api.completion", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    ---@type string
    local test_dir

    before_each(function()
        roam = utils.init_plugin({
            setup = {
                directory = utils.make_temp_org_files_directory(),
            }
        })
        test_dir = roam.config.directory

        -- Patch `vim.cmd` so we can run tests here
        utils.patch_vim_cmd()
    end)

    after_each(function()
        -- Unpatch `vim.cmd` so we can have tests pass
        utils.unpatch_vim_cmd()

        -- Restore select in case we mocked it
        utils.unmock_select()
    end)

    it("should do nothing if the expression under cursor has no matching nodes", function()
        local id = utils.random_id()
        local test_path = utils.make_temp_filename({
            dir = test_dir,
            ext = "org",
        })

        -- Create our test file with an expression that matches nothing
        utils.write_to(test_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "",
            "expression",
        })

        -- Load files into the database
        roam.db:load():wait()

        -- Open our test file into a buffer
        vim.cmd.edit(test_path)

        -- Move our cursor down to the expression
        vim.api.nvim_win_set_cursor(0, { 5, 0 })

        -- Try to complete
        local ok = roam.api.complete_node():wait()
        assert.is_false(ok)

        -- Review that buffer was not updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "",
            "expression",
        }, utils.read_buffer())
    end)

    it("should replace the expression under cursor with a link to the single matching node", function()
        local id = utils.random_id()
        local test_path = utils.make_temp_filename({
            dir = test_dir,
            ext = "org",
        })

        -- Create our test file with an expression that matches nothing
        utils.write_to(test_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "",
            "one",
        })

        -- Load files into the database
        roam.db:load():wait()

        -- Open our test file into a buffer
        vim.cmd.edit(test_path)

        -- Move our cursor down to the expression
        vim.api.nvim_win_set_cursor(0, { 5, 0 })

        -- Try to complete
        local ok = roam.api.complete_node():wait()
        assert.is_true(ok)

        -- Review that buffer was not updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "",
            "[[id:1][one]]",
        }, utils.read_buffer())
    end)

    it("should provide a selection dialog if the expression under cursor has multiple matching nodes", function()
        local id = utils.random_id()
        local test_path = utils.make_temp_filename({
            dir = test_dir,
            ext = "org",
        })

        -- Create our test file with an expression that matches nothing
        utils.write_to(test_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "",
            "o",
        })

        -- Load files into the database
        roam.db:load():wait()

        -- Open our test file into a buffer
        vim.cmd.edit(test_path)

        -- Move our cursor down to the expression
        vim.api.nvim_win_set_cursor(0, { 5, 0 })

        -- Pick two as the choice
        utils.mock_select_pick(function(choices)
            for _, choice in ipairs(choices) do
                if choice.label == "two" then
                    return choice
                end
            end
        end)

        -- Try to complete
        local ok = roam.api.complete_node():wait()
        assert.is_true(ok)

        -- Review that buffer was not updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "",
            "[[id:2][two]]",
        }, utils.read_buffer())
    end)
end)
