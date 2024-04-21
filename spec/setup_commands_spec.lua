describe("org-roam.setup.commands", function()
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("RoamSave should save database to disk", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure we are loaded and wipe out the local database file
        roam.db:load():wait()
        assert.are.equal(0, vim.fn.delete(roam.config.database.path))
        assert.are.equal(0, vim.fn.filereadable(roam.config.database.path))

        -- Trigger the command and wait a bit
        vim.cmd("RoamSave")
        vim.wait(100)

        -- Verify the database file exists again
        assert.are.equal(1, vim.fn.filereadable(roam.config.database.path))
    end)

    it("RoamUpdate should update database's existing files if they changed on disk", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.db:load():wait()

        -- Create a new file not loaded by the plugin yet
        utils.write_to(utils.join_path(directory, "one.org"), utils.indent([=[
        :PROPERTIES:
        :ID: roam-update-node
        :END:
        ]=]))

        -- Trigger the command and wait a bit
        vim.cmd("RoamUpdate")
        vim.wait(100)

        -- Verify the existing file was updated
        local ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "2", "3", "roam-update-node" }, ids)
    end)

    it("RoamUpdate! should force reloading database from files on disk", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.db:load():wait()

        -- Create a new file not loaded by the plugin yet
        utils.write_to(utils.join_path(directory, "test.org"), utils.indent([=[
        :PROPERTIES:
        :ID: roam-update-node
        :END:
        ]=]))

        -- Trigger the command and wait a bit
        vim.cmd("RoamUpdate!")
        vim.wait(100)

        -- Verify the new file was loaded
        local ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3", "roam-update-node" }, ids)
    end)

    it("RoamDatabaseReset should clear disk cache, wipe the database, and reload from disk", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.db:load():wait()

        -- Create a new file not loaded by the plugin yet
        utils.write_to(utils.join_path(directory, "test.org"), utils.indent([=[
        :PROPERTIES:
        :ID: roam-update-node
        :END:
        ]=]))

        -- Verify the database cache file exists
        assert.are.equal(1, vim.fn.filereadable(roam.config.database.path))

        -- Verify the state of the database
        local ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3" }, ids)

        -- Trigger the command and wait a bit
        vim.cmd("RoamDatabaseReset")
        vim.wait(100)

        -- Verify database has latest status
        ids = roam.db:ids()
        table.sort(ids)
        assert.are.same({ "1", "2", "3", "roam-update-node" }, ids)

        -- Verify the database cache file is gone
        assert.are.equal(0, vim.fn.filereadable(roam.config.database.path))
    end)

    it("RoamAddAlias should support adding an alias to the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.db:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())

        -- Trigger the command and wait a bit
        vim.cmd("RoamAddAlias some alias")
        vim.wait(100)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one \"some alias\"",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("RoamRemoveAlias should support removing an alias from the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.db:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())

        -- Trigger the command and wait a bit
        vim.cmd("RoamRemoveAlias one")
        vim.wait(100)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("RoamAddOrigin should support setting the origin for the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.db:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())

        -- Trigger the command and wait a bit
        vim.cmd("RoamAddOrigin node origin")
        vim.wait(100)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":ROAM_ORIGIN: node origin",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("RoamRemoveOrigin should support removing the origin for the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "two.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.db:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

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

        -- Trigger the command and wait a bit
        vim.cmd("RoamRemoveOrigin")
        vim.wait(100)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 2",
            ":ROAM_ALIASES: two",
            ":END:",
            "#+FILETAGS: :two:",
            "",
            "[[id:3]]",
        }, utils.read_buffer())
    end)
end)
