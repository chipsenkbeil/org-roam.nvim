describe("org-roam.api.node", function()
    local api = require("org-roam.api")
    local utils = require("spec.utils")

    ---Database populated before each test.
    ---@type org-roam.Database
    local db

    ---@type string, string
    local test_dir, one_path

    before_each(function()
        test_dir = utils.make_temp_org_files_directory()

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
        vim.wait(1000)

        -- Save the capture buffer
        vim.api.nvim_input("ZZ")
        vim.wait(1000)

        assert.are.same({}, utils.read_buffer())
        error("ID: " .. vim.inspect(id))

        -- Review that buffer was not updated
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "",
            "expression",
        }, utils.read_buffer())
    end)
end)
