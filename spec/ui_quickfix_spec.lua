describe("org-roam.ui.quickfix", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    ---@type string
    local test_path_two

    before_each(function()
        utils.init_before_test()

        roam = utils.init_plugin({
            setup = {
                directory = utils.make_temp_org_files_directory({
                    filter = function(entry)
                        return vim.list_contains({ "one.org", "two.org", "three.org" }, entry.filename)
                    end,
                }),
            },
        })
        test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should be able to display backlinks for the node under cursor", function()
        roam.database:load():wait()

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
        roam.database:load():wait()

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
        roam.database:load():wait()

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
            { module = "(link) three", text = "", lnum = 0, col = 0 },
        }, items)
    end)

    it("should support including a preview for quickfix items", function()
        roam.database:load():wait()

        -- Load up a test file
        vim.cmd.edit(test_path_two)

        -- Open the quickfix list based on the node from two.org
        roam.ui
            .open_quickfix_list({
                backlinks = true,
                show_preview = true,
            })
            :wait()

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
