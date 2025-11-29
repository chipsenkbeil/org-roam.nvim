describe("org-roam.ui.node-buffer", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()

        -- Initialize an entirely new plugin and set it up
        -- so extra features like cursor node tracking works
        roam = utils.init_plugin({
            setup = {
                directory = utils.make_temp_org_files_directory({
                    filter = function(entry)
                        return vim.list_contains({ "one.org", "two.org", "three.org" }, entry.filename)
                    end,
                }),
            },
        })
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should display node buffer that follows cursor if no node specified", function()
        roam.database:load():wait()

        local test_path_one = vim.fs.joinpath(roam.config.directory, "one.org")
        local test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")

        -- Load up multiple different files
        local one_win, two_win = utils.edit_files(test_path_one, test_path_two)
        vim.api.nvim_set_current_win(one_win)

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer():wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        local buf = vim.api.nvim_win_get_buf(win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Node: one",
            "",
            "Backlinks (1)",
            "▶ three @ 8,0",
        }, utils.read_buffer(buf))

        -- Switch back to our node window and change it to move cursor
        vim.api.nvim_set_current_win(two_win)
        utils.wait()

        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Node: two",
            "Origin: one",
            "",
            "Backlinks (1)",
            "▶ one @ 7,0",
        }, utils.read_buffer(buf))
    end)

    it("should include origin of node in the displayed node buffer if it has one", function()
        roam.database:load():wait()

        local test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")

        vim.cmd.edit(test_path_two)

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer():wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        local buf = vim.api.nvim_win_get_buf(win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Node: two",
            "Origin: one",
            "",
            "Backlinks (1)",
            "▶ one @ 7,0",
        }, utils.read_buffer(buf))
    end)

    it("should be able to navigate to the origin from the node buffer", function()
        roam.database:load():wait()

        local test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")

        -- Load up a test file so we have a node under cursor
        vim.cmd.edit(test_path_two)

        -- Get the window that contains the node
        local node_win = vim.api.nvim_get_current_win()

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer({ focus = true }):wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        -- Jump to the line containing the origin and trigger navigation
        utils.jump_to_line(function(_, lines)
            for i, line in ipairs(lines) do
                if vim.startswith(line, "Origin") then
                    return i
                end
            end
        end)

        -- Trigger our buffer-local mapping, waiting a bit for the node to load
        utils.trigger_mapping("n", "<CR>", { buf = 0, wait = utils.wait_time() })

        -- Load the non-node buffer that is visible
        local buf = vim.api.nvim_win_get_buf(node_win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer(buf))
    end)

    it("should be able to navigate to the link from the node buffer", function()
        roam.database:load():wait()

        local test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")

        -- Load up a test file so we have a node under cursor
        vim.cmd.edit(test_path_two)

        -- Get the window that contains the node
        local node_win = vim.api.nvim_get_current_win()

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer({ focus = true }):wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        -- Jump to the line containing the origin and trigger navigation
        utils.jump_to_line(function(_, lines)
            for i, line in ipairs(lines) do
                if string.find(line, "one @ 7,0") then
                    return i
                end
            end
        end)

        -- Trigger our buffer-local mapping, waiting a bit for the node to load
        utils.trigger_mapping("n", "<CR>", { buf = 0, wait = utils.wait_time() })

        -- Load the non-node buffer that is visible
        local buf = vim.api.nvim_win_get_buf(node_win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer(buf))
    end)

    it("should be able to expand a link to display a preview within the node buffer", function()
        roam.database:load():wait()

        local test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")

        -- Load up a test file so we have a node under cursor
        vim.cmd.edit(test_path_two)

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer({ focus = true }):wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        local buf = vim.api.nvim_win_get_buf(win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        -- Jump to the line containing the origin and trigger navigation
        utils.jump_to_line(function(_, lines)
            for i, line in ipairs(lines) do
                if string.find(line, "one @ 7,0") then
                    return i
                end
            end
        end)

        -- Trigger our buffer-local mapping, waiting a bit for the preview
        utils.trigger_mapping("n", "<Tab>", { buf = 0, wait = utils.wait_time() })

        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Node: two",
            "Origin: one",
            "",
            "Backlinks (1)",
            "▼ one @ 7,0",
            "[[id:2]]",
        }, utils.read_buffer(buf))
    end)

    it("should be able to expand all links to display previews within the node buffer", function()
        roam.database:load():wait()

        local test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")

        -- Load up a test file so we have a node under cursor
        vim.cmd.edit(test_path_two)

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer({ focus = true }):wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        local buf = vim.api.nvim_win_get_buf(win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        -- Trigger our buffer-local mapping, waiting a bit for the preview
        -- NOTE: With a wait of 100, sometimes hasn't loaded preview yet;
        --       so, we're using a longer wait time to give it a better chance.
        local wait_time = math.max(500, utils.wait_time())
        utils.trigger_mapping("n", "<S-Tab>", { buf = 0, wait = wait_time })

        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Node: two",
            "Origin: one",
            "",
            "Backlinks (1)",
            "▼ one @ 7,0",
            "[[id:2]]",
        }, utils.read_buffer(buf))
    end)

    it("should display node buffer for a fixed node specified", function()
        roam.database:load():wait()

        local test_path_one = vim.fs.joinpath(roam.config.directory, "one.org")
        local test_path_two = vim.fs.joinpath(roam.config.directory, "two.org")

        -- Load up multiple different files
        local one_win, two_win = utils.edit_files(test_path_one, test_path_two)
        vim.api.nvim_set_current_win(one_win)

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer({ fixed = "1" }):wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        local buf = vim.api.nvim_win_get_buf(win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Fixed Node: one",
            "",
            "Backlinks (1)",
            "▶ three @ 8,0",
        }, utils.read_buffer(buf))

        -- Switch back to our node window and change it to move cursor
        vim.api.nvim_set_current_win(two_win)
        utils.wait()

        -- Verify it is unchanged despite cursor moving
        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Fixed Node: one",
            "",
            "Backlinks (1)",
            "▶ three @ 8,0",
        }, utils.read_buffer(buf))
    end)
end)
