describe("org-roam.ui.quickfix", function()
    local utils = require("spec.utils")

    ---@return OrgRoam roam, string two_path
    local function setup_roam()
        local roam = utils.init_plugin({
            setup = {
                directory = utils.make_temp_org_files_directory({
                    filter = function(entry)
                        return vim.list_contains({ "one.org", "two.org", "three.org" }, entry.filename)
                    end,
                }),
            },
        })
        local two_path = vim.fs.joinpath(roam.config.directory, "two.org")
        return roam, two_path
    end

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should be able to display backlinks for the node under cursor", function()
        local roam, test_path_two = setup_roam()
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
        local roam, test_path_two = setup_roam()
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
        local roam, test_path_two = setup_roam()
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
        local roam, test_path_two = setup_roam()
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
