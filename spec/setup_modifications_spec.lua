describe("org-roam.setup.modifications", function()
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should override orgmode's open_at_point to use roam's database first", function()
        local directory = utils.make_temp_org_files_directory()
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        roam.database:load():wait()

        -- Add a custom entry into our database that points to the same file
        local node = roam.database:get_sync("1")
        assert.is_not_nil(node)

        -- Make a new node that points to "1", but is called "4"
        local new_node = vim.deepcopy(node)
        new_node.id = "4"
        roam.database:internal_sync():insert(new_node, { id = "4" })

        -- Create a link reference to that id
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { "[[id:4]]" })

        -- Our cursor should be on the link right now, so open it
        require("orgmode").org_mappings:open_at_point()

        -- Verify that we loaded node "1"
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("should override orgmode's promise.wait to throw an error on timeout", function()
        local roam = utils.init_plugin({ setup = true })
        local Promise = require("orgmode.utils.promise")

        -- Create a promise that will never resolve or reject
        local promise = Promise.new(function() end)

        assert.is.error(function()
            -- Wait with a shorter timeout, which should fail on timeout exceeded
            promise:wait(50)
        end)
    end)
end)
