describe("org-roam.setup", function()
    local utils = require("spec.utils")
    local AUGROUP_NAME = "org-roam.nvim"

    ---@param opts? {setup?:boolean|org-roam.Config}
    ---@return OrgRoam
    local function init_roam_plugin(opts)
        opts = opts or {}
        -- Initialize an entirely new plugin and set it up
        -- so extra features like cursor node tracking works
        local roam = require("org-roam"):new()
        if opts.setup then
            local test_dir = utils.make_temp_directory()
            local config = {
                directory = test_dir,
                database = {
                    path = utils.join_path(test_dir, "db"),
                },
            }
            if type(opts.setup) == "table" then
                config = vim.tbl_deep_extend("force", config, opts.setup)
            end
            roam.setup(config)
        end
        return roam
    end

    before_each(function()
        -- Patch `vim.cmd` so we can run tests here
        utils.patch_vim_cmd()
        utils.clear_windows()
        utils.clear_buffers()
        utils.clear_autocmds(AUGROUP_NAME)
    end)

    after_each(function()
        utils.clear_autocmds(AUGROUP_NAME)
        utils.clear_windows()
        utils.clear_buffers()
        utils.unpatch_vim_cmd()
        utils.unmock_select()
    end)

    it("should fail if no directory supplied", function()
        assert.is.error(function()
            local roam = init_roam_plugin({ setup = false })
            roam.setup({})
        end)
    end)

    it("should adjust the database to the supplied configuration", function()
        local db_path = vim.fn.tempname() .. "-test-db"
        local directory = utils.make_temp_org_files_directory()

        local roam = init_roam_plugin({ setup = false })
        roam.setup({
            database = { path = db_path },
            directory = directory,
        })

        assert.are.equal(db_path, roam.db:path())
        assert.are.equal(directory, roam.db:files_path())
    end)

    it("should enable updating the database on write if configured", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = init_roam_plugin({
            setup = {
                directory = directory,
                database = {
                    update_on_save = true,
                },
            }
        })

        -- Ensure we are loaded
        roam.db:load():wait()

        local ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3" }, ids)

        -- Load up an org file, modify it, and write it to trigger database update
        vim.cmd.edit(test_path)
        vim.api.nvim_buf_set_lines(0, 2, 3, true, { ":ID: new-id" })
        vim.cmd.write()

        -- Wait a bit to have the changes apply
        vim.wait(100)

        -- Verify that the database reflects the change
        ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "2", "3", "new-id" }, ids)
    end)

    it("should not enable updating the database on write if configured", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = init_roam_plugin({
            setup = {
                directory = directory,
                database = {
                    update_on_save = false,
                },
            }
        })

        -- Ensure we are loaded
        roam.db:load():wait()

        local ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3" }, ids)

        -- Load up an org file, modify it, and write it to trigger database update
        vim.cmd.edit(test_path)
        vim.api.nvim_buf_set_lines(0, 2, 3, true, { ":ID: new-id" })
        vim.cmd.write()

        -- Wait a bit to have the changes apply
        vim.wait(100)

        -- Verify that the database does not reflect change
        ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3" }, ids)
    end)

    it("should save database to disk on exit if persist configured", function()
        -- Configure plugin to persist database
        local roam = init_roam_plugin({
            setup = {
                database = {
                    persist = true,
                },
            }
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

        -- Trigger the autocmd to save the database
        autocmd.callback()

        -- Verify the database file exists
        assert.are.equal(1, vim.fn.filereadable(roam.config.database.path))
    end)

    it("should not save database to disk on exit if persist not configured", function()
        -- Configure plugin to not persist database
        local roam = init_roam_plugin({
            setup = {
                database = {
                    persist = false,
                },
            }
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
