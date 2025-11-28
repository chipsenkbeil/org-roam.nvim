describe("org-roam.api.node", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    ---@type string
    local one_path

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

        one_path = vim.fs.joinpath(roam.config.directory, "one.org")
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should capture by using the selected roam template", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1, -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input = "Some title", -- input "Some title" on title prompt
        })

        -- Start the capture process
        local id = roam.api.capture_node()

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(roam.database:get_sync(id), "missing node " .. id)
        local contents = utils.read_from(node.file)

        -- Verify that basic template was captured
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: Some title",
            "",
            "",
            "",
        }, contents)
    end)

    it("should capture using an optional set of custom templates if provided", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1, -- confirm yes for refile
            getchar = vim.fn.char2nr("v"), -- select "v" template
            input = "Some title", -- input "Some title" on title prompt
        })

        -- Start the capture process using a custom template
        local id = roam.api.capture_node({
            templates = {
                v = {
                    description = "custom",
                    template = "test template content\n%?",
                    target = "%<%Y%m%d%H%M%S>-%[slug].org",
                },
            },
        })

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(roam.database:get_sync(id), "missing node " .. id)
        local contents = utils.read_from(node.file)

        -- Verify that basic template was captured
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: Some title",
            "",
            "test template content",
            "",
            "",
        }, contents)
    end)

    it("should capture without prompting if immediate mode enabled", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            input = "Some title",
        })

        -- Start the capture process
        local id = roam.api.capture_node({ immediate = true }):wait()

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(roam.database:get_sync(id), "missing node " .. id)
        local contents = utils.read_from(node.file)

        -- Verify that basic template was captured
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: Some title",
            "",
            "",
        }, contents)
    end)

    it("should insert link to existing node if selected", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        -- Pick node "one" when given choices
        utils.mock_select_pick(function(choices)
            for _, choice in ipairs(choices) do
                if choice.label == "one" then
                    return choice
                end
            end
        end)

        -- Move cursor to the end of the last line in the buffer
        local row = vim.api.nvim_buf_line_count(0)
        local col = utils.cursor_end_of_line_col(row)
        vim.api.nvim_win_set_cursor(0, { row, col })

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.insert_node():wait()

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- We should have an id for a valid insertion
        assert.are.equal("1", id)

        -- Verify we inserted a link to the specified node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]][[id:1][one]]",
        }, utils.read_buffer())
    end)

    it("should insert link to existing node if selected using selected item's value", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        -- Pick node "one" when given choices
        utils.mock_select_pick(function(choices)
            for _, choice in ipairs(choices) do
                if choice.label == "one" then
                    -- Modify the value of the item so we can assert that it is used
                    choice.item.value = "VALUE ONE"

                    return choice
                end
            end
        end)

        -- Move cursor to the end of the last line in the buffer
        local row = vim.api.nvim_buf_line_count(0)
        local col = utils.cursor_end_of_line_col(row)
        vim.api.nvim_win_set_cursor(0, { row, col })

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.insert_node():wait()

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- We should have an id for a valid insertion
        assert.are.equal("1", id)

        -- Verify we inserted a link to the specified node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]][[id:1][VALUE ONE]]",
        }, utils.read_buffer())
    end)

    it("should insert link to existing node using alias if alias selected", function()
        -- Create a node with a distinct alias
        local test_path = vim.fs.joinpath(roam.config.directory, "test-file.org")
        utils.write_to(test_path, {
            ":PROPERTIES:",
            ":ID: test-node-id",
            ':ROAM_ALIASES: "some test alias"',
            ":END:",
        })

        -- Load files into the database (scan to pick up new file)
        roam.database:load({ force = "scan" }):wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        -- Pick node "some test alias" when given choices
        utils.mock_select_pick(function(_, _, helpers)
            return helpers.pick_with_label("some test alias")
        end)

        -- Move cursor to the end of the last line in the buffer
        local row = vim.api.nvim_buf_line_count(0)
        local col = utils.cursor_end_of_line_col(row)
        vim.api.nvim_win_set_cursor(0, { row, col })

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.insert_node():wait()

        -- We should have an id for a valid insertion
        assert.are.equal("test-node-id", id)

        -- Verify we inserted a link to the specified node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]][[id:test-node-id][some test alias]]",
        }, utils.read_buffer())
    end)

    it("should create a new node and insert it if selected non-existing node", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1, -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
        })

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Move cursor to the end of the last line in the buffer
        local row = vim.api.nvim_buf_line_count(0)
        local col = utils.cursor_end_of_line_col(row)
        vim.api.nvim_win_set_cursor(0, { row, col })

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.insert_node()

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

        -- We should have an id for a valid insertion
        assert.is_not_nil(id)

        -- Verify we inserted a link to the specified node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]][[id:" .. id .. "][some custom node]]",
        }, utils.read_buffer())
    end)

    it("should create a new node using custom templates and insert it if selected non-existing node", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1, -- confirm yes for refile
            getchar = vim.fn.char2nr("v"), -- select "v" template
        })

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Move cursor to the end of the last line in the buffer
        local row = vim.api.nvim_buf_line_count(0)
        local col = utils.cursor_end_of_line_col(row)
        vim.api.nvim_win_set_cursor(0, { row, col })

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.insert_node({
            templates = {
                v = {
                    description = "custom",
                    template = "test template content\n%?",
                    target = "%<%Y%m%d%H%M%S>-%[slug].org",
                },
            },
        })

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

        -- We should have an id for a valid insertion
        assert.is_not_nil(id)

        -- Verify we inserted a link to the specified node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]][[id:" .. id .. "][some custom node]]",
        }, utils.read_buffer())
    end)

    it("should create a new node and insert it using immediate mode if specified", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Move cursor to the end of the last line in the buffer
        local row = vim.api.nvim_buf_line_count(0)
        local col = utils.cursor_end_of_line_col(row)
        vim.api.nvim_win_set_cursor(0, { row, col })

        -- Trigger node insertion, which will not bring up the
        -- selection dialog as it's immediate
        local id = roam.api.insert_node({ immediate = true }):wait()

        -- We should have an id for a valid insertion
        assert.is_not_nil(id)

        -- Verify we inserted a link to the specified node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]][[id:" .. id .. "][some custom node]]",
        }, utils.read_buffer())
    end)

    it("should find and open existing node if selected", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        -- Pick node "two" when given choices
        utils.mock_select_pick(function(choices)
            for _, choice in ipairs(choices) do
                if choice.label == "two" then
                    return choice
                end
            end
        end)

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.find_node():wait()

        -- We should have an id for a valid find
        assert.are.equal("2", id)

        -- Verify we moved to the specified node
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

    it("should create a new node and navigate to it if find with non-existing node", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1, -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
        })

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.find_node()

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

        -- We should have an id for a valid find
        assert.is_not_nil(id)

        -- Verify that basic template was captured
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: some custom node",
            "",
            "",
        }, utils.read_buffer())
    end)

    it("should create a new node using custom templates and navigate to it if find with non-existing node", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1, -- confirm yes for refile
            getchar = vim.fn.char2nr("v"), -- select "v" template
        })

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Trigger node insertion, which will bring up the dialog
        local id = roam.api.find_node({
            templates = {
                v = {
                    description = "custom",
                    template = "test template content\n%?",
                    target = "%<%Y%m%d%H%M%S>-%[slug].org",
                },
            },
        })

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

        -- We should have an id for a valid find
        assert.is_not_nil(id)

        -- Verify that basic template was captured
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: some custom node",
            "",
            "test template content",
            "",
        }, utils.read_buffer())
    end)
end)
