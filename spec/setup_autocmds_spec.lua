describe("org-roam.setup.autocmds", function()
    local utils = require("spec.utils")
    local AUGROUP_NAME = utils.autogroup_name()

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should enable updating the database on write if configured", function()
        local directory = utils.make_temp_org_files_directory({
            filter = function(entry)
                return vim.list_contains({ "one.org", "two.org", "three.org" }, entry.filename)
            end,
        })
        local test_path = vim.fs.joinpath(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    update_on_save = true,
                },
            },
        })

        -- Ensure we are loaded
        roam.database:load():wait()

        local ids = roam.database:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3" }, ids)

        -- Load up an org file, modify it, and write it to trigger database update
        vim.cmd.edit(test_path)
        vim.api.nvim_buf_set_lines(0, 2, 3, true, { ":ID: new-id" })
        vim.cmd.write()

        -- Wait a bit to have the changes apply
        utils.wait()

        -- Verify that the database reflects the change
        ids = roam.database:ids()
        table.sort(ids)
        assert.are.same({ "2", "3", "new-id" }, ids)
    end)

    it("should not enable updating the database on write if configured", function()
        local directory = utils.make_temp_org_files_directory({
            filter = function(entry)
                return vim.list_contains({ "one.org", "two.org", "three.org" }, entry.filename)
            end,
        })
        local test_path = vim.fs.joinpath(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    update_on_save = false,
                },
            },
        })

        -- Ensure we are loaded
        roam.database:load():wait()

        local ids = roam.database:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3" }, ids)

        -- Load up an org file, modify it, and write it to trigger database update
        vim.cmd.edit(test_path)
        vim.api.nvim_buf_set_lines(0, 2, 3, true, { ":ID: new-id" })
        vim.cmd.write()

        -- Wait a bit to have the changes apply
        utils.wait()

        -- Verify that the database does not reflect change
        ids = roam.database:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3" }, ids)
    end)

    it("should save database to disk on exit if persist configured", function()
        -- Configure plugin to persist database
        local roam = utils.init_plugin({
            setup = {
                database = {
                    persist = true,
                },
            },
        })

        -- Look for the persistence autocmd
        ---@type {callback:fun()}[]
        local autocmds = vim.api.nvim_get_autocmds({
            group = AUGROUP_NAME,
            event = "VimLeavePre",
            pattern = "*",
        })

        -- Should have exactly one
        assert.are.equal(1, #autocmds)
        local autocmd = autocmds[1]

        -- Delete the database so we can verify it gets created later
        vim.fn.delete(roam.config.database.path)
        assert.are.equal(0, vim.fn.filereadable(roam.config.database.path))

        -- Do some database mutation to avoid caching
        roam.database:insert_sync(utils.fake_node())

        -- Trigger the autocmd to save the database
        autocmd.callback()

        -- Verify the database file exists
        assert.are.equal(1, vim.fn.filereadable(roam.config.database.path))
    end)

    it("should not save database to disk on exit if persist not configured", function()
        -- Configure plugin to not persist database
        local _ = utils.init_plugin({
            setup = {
                database = {
                    persist = false,
                },
            },
        })

        -- Look for the persistence autocmd
        local autocmds = vim.api.nvim_get_autocmds({
            group = AUGROUP_NAME,
            event = "VimLeavePre",
            pattern = "*",
        })

        -- Should have not been set up
        assert.are.same({}, autocmds)
    end)
end)
