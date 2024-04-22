describe("org-roam.ui.quickfix", function()
    ---@type OrgRoam
    local roam

    local utils = require("spec.utils")

    ---@type string, string, string, string
    local test_dir, test_path_one, test_path_two, test_path_three

    before_each(function()
        test_dir = utils.make_temp_org_files_directory()
        test_path_one = utils.join_path(test_dir, "one.org")
        test_path_two = utils.join_path(test_dir, "two.org")
        test_path_three = utils.join_path(test_dir, "three.org")

        -- Initialize an entirely new plugin and set it up
        -- so extra features like cursor node tracking works
        roam = require("org-roam"):new()
        roam.db = roam.db:new({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = test_dir,
        })
        roam.setup({ directory = test_dir }):wait()

        -- Patch `vim.cmd` so we can run tests here
        utils.patch_vim_cmd()

        -- Clear any buffers/windows that carried over from other tests
        utils.clear_windows()
        utils.clear_buffers()
    end)

    after_each(function()
        -- Clear any buffers/windows that carried over from this test
        utils.clear_windows()
        utils.clear_buffers()

        -- Unpatch `vim.cmd` so we can have tests pass
        utils.unpatch_vim_cmd()

        -- Restore select in case we mocked it
        utils.unmock_select()
    end)

    it("should be able to display backlinks for the node under cursor", function()
        roam.db:load():wait()

        -- Load up a test file
        vim.cmd.edit(test_path_two)

        -- Open the quickfix list based on the node from two.org
        roam.ui.open_quickfix_list({ backlinks = true }):wait()

        -- Verify the quickfix contents
        assert.are.same({
            { module = "one", text = "", lnum = 7, col = 1 },
        }, utils.qflist_items())

        -- Trigger a quickfix error navigation
        vim.cmd([[cc]])
        utils.wait()

        -- Verify position and contents
        local pos = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 7, 0 }, pos)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer(vim.api.nvim_get_current_buf()))
    end)

    it("should be able to display links for the node under cursor", function()
        roam.db:load():wait()

        -- Load up a test file
        vim.cmd.edit(test_path_two)

        -- Open the quickfix list based on the node from two.org
        roam.ui.open_quickfix_list({ links = true }):wait()

        -- Verify the quickfix contents
        assert.are.same({
            { module = "three", text = "", lnum = 0, col = 0 },
        }, utils.qflist_items())

        -- Trigger a quickfix error navigation
        vim.cmd([[cc]])
        utils.wait()

        -- Verify position and contents
        local pos = vim.api.nvim_win_get_cursor(0)
        assert.are.same({ 1, 0 }, pos)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 3",
            ":ROAM_ALIASES: three",
            ":ROAM_ORIGIN: 2",
            ":END:",
            "#+FILETAGS: :three:",
            "",
            "[[id:1]]",
        }, utils.read_buffer(vim.api.nvim_get_current_buf()))
    end)

    it("should distinguish multiple items of different types", function()
        roam.db:load():wait()

        -- Load up a test file
        vim.cmd.edit(test_path_two)

        -- Open the quickfix list based on the node from two.org
        roam.ui.open_quickfix_list({ backlinks = true, links = true }):wait()

        -- Verify the quickfix contents
        local items = utils.qflist_items()
        table.sort(items, function(a, b)
            return a.module < b.module
        end)
        assert.are.same({
            { module = "(backlink) one", text = "", lnum = 7, col = 1 },
            { module = "(link) three",   text = "", lnum = 0, col = 0 },
        }, items)
    end)

    it("should support including a preview for quickfix items", function()
        roam.db:load():wait()

        -- Load up a test file
        vim.cmd.edit(test_path_two)

        -- Open the quickfix list based on the node from two.org
        roam.ui.open_quickfix_list({
            backlinks = true,
            show_preview = true,
        }):wait()

        -- Verify the quickfix contents
        assert.are.same({
            { module = "one", text = "[[id:2]]", lnum = 7, col = 1 },
        }, utils.qflist_items())

        -- Trigger a quickfix error navigation
        vim.cmd([[cc]])
        utils.wait()

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer(vim.api.nvim_get_current_buf()))
    end)
end)
