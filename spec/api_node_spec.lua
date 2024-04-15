describe("org-roam.api.node", function()
    local api = require("org-roam.api")
    local CONFIG = require("org-roam.config")
    local utils = require("spec.utils")

    ---Database populated before each test.
    ---@type org-roam.Database
    local db

    ---@type string, string
    local test_dir, one_path

    before_each(function()
        test_dir = utils.make_temp_org_files_directory()

        -- Overwrite the configuration roam directory
        CONFIG({ directory = test_dir })

        db = utils.make_db({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = test_dir,
        })

        one_path = utils.join_path(db:files_path(), "one.org")

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
        db:load():wait()

        -- Open an empty buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        -- Start the capture process
        local id
        api.capture_node({}, function(_id) id = _id end)

        -- Wait a bit for the capture buffer to appear
        vim.wait(100)

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        vim.wait(100)

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(db:get_sync(id), "missing node " .. id)
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
        db:load():wait()

        -- Open an empty buffer so we avoid capture closing neovim
        vim.cmd.edit(one_path)

        utils.mock_vim_inputs({
            input = "Some title",
        })

        -- Start the capture process
        local id
        api.capture_node({ immediate = true }, function(_id)
            id = _id
        end)

        -- Wait a bit for the capture to be processed
        vim.wait(100)

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(db:get_sync(id), "missing node " .. id)
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
end)
