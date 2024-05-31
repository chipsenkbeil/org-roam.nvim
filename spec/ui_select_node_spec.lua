describe("org-roam.ui.select-node", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    ---@param buf? integer
    ---@return string[]
    local function read_trimmed_sorted_buf_lines(buf)
        buf = buf or vim.api.nvim_get_current_buf()
        local lines = utils.read_buffer(buf)
        table.sort(lines)
        lines = vim.tbl_map(vim.trim, lines)
        return lines
    end

    ---Fills in text for the selection dialog, representing the filter criteria.
    ---If `buf` provided, uses it over the current buffer.
    ---If `wait` provided, uses it over the default 100 milliseconds.
    ---@param text string
    ---@param opts? {buf?:integer, wait?:integer}
    local function fill_selection_text(text, opts)
        opts = opts or {}

        -- TODO: I can't figure out how to get input to work. Using
        --       feedkeys with mode `x!` blocks, not leaving insert.
        --
        --       Our mode itself appears to be normal and not insert
        --       at this stage, which itself is a problem as well.
        --
        --       So, we instead directly modify the selection text
        --       within the buffer to force a filter.
        local buf = opts.buf or vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(buf, 0, 1, true, { text })
        vim.api.nvim_exec_autocmds("TextChangedI", { buffer = buf })

        local wait = opts.wait or utils.wait_time()
        if wait > 0 then
            vim.wait(wait)
        end
    end

    before_each(function()
        utils.init_before_test()

        roam = utils.init_plugin({
            setup = {
                directory = utils.make_temp_org_files_directory(),
            },
        })
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should display titles and aliases of all nodes by default", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Load up the selection interface for all nodes
        roam.ui.select_node():open()
        utils.wait()

        -- Grab lines from current buffer
        local lines = read_trimmed_sorted_buf_lines()

        -- Duplicate aliases are not included
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "", -- line containing filter text
            "one",
            "three",
            "two",
        }, lines)
    end)

    it("should support limiting to only included node ids", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Load up the selection interface for nodes 2 and 3
        roam.ui.select_node({ include = { "2", "3" } }):open()
        utils.wait()

        -- Grab lines from current buffer
        local lines = read_trimmed_sorted_buf_lines()

        -- Duplicate aliases are not included
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "", -- line containing filter text
            "three",
            "two",
        }, lines)
    end)

    it("should support limiting to exclude specific node ids", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Load up the selection interface for all nodes except 1
        roam.ui.select_node({ exclude = { "1" } }):open()
        utils.wait()

        -- Grab lines from current buffer
        local lines = read_trimmed_sorted_buf_lines()

        -- Duplicate aliases are not included
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "", -- line containing filter text
            "three",
            "two",
        }, lines)
    end)

    it("should support being provided initial input to filter by title/alias", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Load up the selection interface for all nodes that contain "o"
        roam.ui.select_node({ init_input = "o" }):open()
        utils.wait()

        -- Grab lines from current buffer
        local lines = read_trimmed_sorted_buf_lines()

        -- Duplicate aliases are not included
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "o", -- line containing filter text
            "one",
            "two",
        }, lines)
    end)

    it("should support selecting automatically if filter matches one node", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Load up the selection interface for all nodes with autoselect, which
        -- will automatically select a node and close itself
        local selected = false
        local id = nil
        roam.ui
            .select_node({ auto_select = true, init_input = "one" })
            :on_choice(function(choice)
                id = choice.id
                selected = true
            end)
            :open()
        utils.wait()

        -- Verify we're on the original window
        assert.are.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({ "" }, utils.read_buffer(vim.api.nvim_get_current_buf()))

        -- Should still have not made a choice automatically
        assert.is_true(selected)
        assert.are.equal("1", id)
    end)

    it("should not select automatically if filter does not select one node", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Load up the selection interface for all nodes with autoselect, which
        -- will do nothing because we have more than one node
        local selected = false
        roam.ui
            .select_node({ auto_select = true, init_input = "o" })
            :on_choice(function()
                selected = true
            end)
            :open()
        utils.wait()

        -- Grab lines from current buffer
        local lines = read_trimmed_sorted_buf_lines()

        -- Duplicate aliases are not included
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "o", -- line containing filter text
            "one",
            "two",
        }, lines)

        -- Should still have not made a choice automatically
        assert.is_false(selected)
    end)

    it("should cancel and close itself if provided initial input with no matches", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Allow missing selection, which we will trigger by pressing <Enter>
        local canceled = false
        local selected = false
        roam.ui
            .select_node({ init_input = "four" })
            :on_choice(function()
                selected = true
            end)
            :on_cancel(function()
                canceled = true
            end)
            :open()
        utils.wait()

        -- Should be at original window with no modifications
        assert.are.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({ "" }, utils.read_buffer(vim.api.nvim_get_current_buf()))

        -- Should have not selected anything and instead canceled
        assert.is_false(selected)
        assert.is_true(canceled)
    end)

    it("should support returning typed text as a label if missing true", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Allow missing selection, which we will trigger by pressing <Enter>
        local label = ""
        local selected = false
        roam.ui
            .select_node({ allow_select_missing = true })
            :on_choice_missing(function(_label)
                label = _label
                selected = true
            end)
            :open()
        utils.wait()

        -- Verify that we're at the selection dialog
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "", -- line containing filter text
            "one",
            "three",
            "two",
        }, read_trimmed_sorted_buf_lines())

        -- Enter in "four" as filter criteria
        fill_selection_text("four")

        -- Should have filtered down to nothing ("four")
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "four", -- line containing filter text
        }, read_trimmed_sorted_buf_lines())

        -- Hit enter to select the input
        utils.trigger_mapping("i", "<CR>", { buf = 0, wait = utils.wait_time() })

        -- Should have selected "four" from our input
        assert.are.equal(win, vim.api.nvim_get_current_win())
        assert.is_true(selected)
        assert.are.equal("four", label)
    end)

    it("should not support returning typed text as a label if missing false/unspecified", function()
        roam.database:load():wait()
        local win = vim.api.nvim_get_current_win()

        -- Don't allow selecting missing
        local label = ""
        local selected = false
        roam.ui
            .select_node()
            :on_choice_missing(function(_label)
                label = _label
                selected = true
            end)
            :open()
        utils.wait()

        -- Verify that we're at the selection dialog
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "", -- line containing filter text
            "one",
            "three",
            "two",
        }, read_trimmed_sorted_buf_lines())

        -- Enter in "four" as filter criteria
        fill_selection_text("four")

        -- Should have filtered down to nothing ("four")
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "four", -- line containing filter text
        }, read_trimmed_sorted_buf_lines())

        -- Hit enter to select the input
        utils.trigger_mapping("i", "<CR>", { buf = 0, wait = utils.wait_time() })

        -- Should not have selected "four" and still be at the dialog
        assert.are_not.equal(win, vim.api.nvim_get_current_win())
        assert.are.same({
            "four", -- line containing filter text
        }, read_trimmed_sorted_buf_lines())

        assert.is_false(selected)
        assert.are.equal("", label)
    end)
end)
