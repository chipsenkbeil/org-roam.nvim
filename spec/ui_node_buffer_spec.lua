describe("org-roam.ui.node-buffer", function()
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
        roam.setup({ directory = test_dir })

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

    it("should display node buffer that follows cursor if no node specified", function()
        roam.db:load():wait()

        -- Load up a test file so we have a node under cursor
        vim.cmd.edit(test_path_one)

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
    end)

    it("should include origin of node in the displayed node buffer if it has one", function()
        roam.db:load():wait()

        -- Load up multiple different files
        local two_win, three_win = utils.edit_files(test_path_two, test_path_three)
        vim.api.nvim_set_current_win(two_win)

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

        -- Switch back to our node window and change it to move cursor
        vim.api.nvim_set_current_win(three_win)
        vim.wait(100)

        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Node: three",
            "Origin: two",
            "",
            "Backlinks (1)",
            "▶ two @ 8,0",
        }, utils.read_buffer(buf))
    end)

    it("should be able to navigate to the origin from the node buffer", function()
        roam.db:load():wait()

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
        utils.trigger_mapping("n", "<CR>", { buf = 0, wait = 100 })

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
        roam.db:load():wait()

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
        utils.trigger_mapping("n", "<CR>", { buf = 0, wait = 100 })

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
        roam.db:load():wait()

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
        utils.trigger_mapping("n", "<Tab>", { buf = 0, wait = 100 })

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
        roam.db:load():wait()

        -- Load up a test file so we have a node under cursor
        vim.cmd.edit(test_path_two)

        ---@type integer|nil
        local win = roam.ui.toggle_node_buffer({ focus = true }):wait()
        assert(win and win ~= 0, "failed to create node buffer window")

        local buf = vim.api.nvim_win_get_buf(win)
        assert(buf ~= 0, "failed to retrieve node buffer handle")

        -- Trigger our buffer-local mapping, waiting a bit for the preview
        utils.trigger_mapping("n", "<S-Tab>", { buf = 0, wait = 100 })

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
        roam.db:load():wait()

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
        vim.wait(100)

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
