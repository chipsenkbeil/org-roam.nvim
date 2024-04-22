describe("org-roam.api.node", function()
    local roam = require("org-roam")

    ---@type spec.utils
    local utils = require("spec.utils")

    ---@type string, string
    local test_dir, one_path

    before_each(function()
        test_dir = utils.make_temp_org_files_directory()

        -- Overwrite the configuration roam directory
        roam.config.directory = test_dir

        roam.db = roam.db:new({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = test_dir,
        })

        one_path = utils.join_path(roam.db:files_path(), "one.org")

        -- Patch `vim.cmd` so we can run tests here
        utils.patch_vim_cmd()
    end)

    after_each(function()
        -- Unpatch `vim.cmd` so we can have tests pass
        utils.unpatch_vim_cmd()

        -- Restore select in case we mocked it
        utils.unmock_select()
        utils.unmock_vim_inputs()
    end)

    it("should capture by using the selected roam template", function()
        -- Load files into the database
        roam.db:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        -- Start the capture process
        local id
        roam.api.capture_node({}, function(_id) id = _id end)

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(roam.db:get_sync(id), "missing node " .. id)
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

    it("should capture without prompting if immediate mode enabled", function()
        -- Load files into the database
        roam.db:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            input = "Some title",
        })

        -- Start the capture process
        local id
        roam.api.capture_node({ immediate = true }, function(_id)
            id = _id
        end)

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(roam.db:get_sync(id), "missing node " .. id)
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
        roam.db:load():wait()

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

        -- Move cursor to the bottom of the buffer, in front of the text
        local row = vim.api.nvim_buf_line_count(0)
        vim.api.nvim_win_set_cursor(0, { row, 0 })

        -- Trigger node insertion, which will bring up the dialog
        local id
        roam.api.insert_node({}, function(_id) id = _id end)

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
            "[[id:1][one]][[id:2]]",
        }, utils.read_buffer())
    end)

    it("should create a new node and insert it if selected non-existing node", function()
        -- Load files into the database
        roam.db:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
        })

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Move cursor to the bottom of the buffer, in front of the text
        local row = vim.api.nvim_buf_line_count(0)
        vim.api.nvim_win_set_cursor(0, { row, 0 })

        -- Trigger node insertion, which will bring up the dialog
        local id
        roam.api.insert_node({}, function(_id) id = _id end)

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

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
            "[[id:" .. id .. "][some custom node]][[id:2]]",
        }, utils.read_buffer())
    end)

    it("should create a new node and insert it using immediate mode if specified", function()
        -- Load files into the database
        roam.db:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Move cursor to the bottom of the buffer, in front of the text
        local row = vim.api.nvim_buf_line_count(0)
        vim.api.nvim_win_set_cursor(0, { row, 0 })

        -- Trigger node insertion, which will not bring up the
        -- selection dialog as it's immediate
        local id
        roam.api.insert_node({ immediate = true }, function(_id) id = _id end)

        -- Wait a bit for the capture to be processed
        utils.wait()

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
            "[[id:" .. id .. "][some custom node]][[id:2]]",
        }, utils.read_buffer())
    end)

    it("should find and open existing node if selected", function()
        -- Load files into the database
        roam.db:load():wait()

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
        local id
        roam.api.find_node({}, function(_id) id = _id end)

        -- Wait a bit for the capture to be processed
        utils.wait()

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
        roam.db:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
        })

        -- Pick some custom title for a new node
        utils.mock_select_pick(function()
            return "some custom node"
        end)

        -- Trigger node insertion, which will bring up the dialog
        local id
        roam.api.find_node({}, function(_id) id = _id end)

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

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
end)
