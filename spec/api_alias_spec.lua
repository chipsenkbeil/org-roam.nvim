describe("org-roam.api.alias", function()
    local api = require("org-roam.api")
    local utils = require("spec.utils")

    -- Patch `vim.cmd` so we can run tests here
    utils.patch_vim_cmd()

    ---Database populated before each test.
    ---@type org-roam.Database
    local db

    ---@type string
    local test_file_path

    before_each(function()
        local dir = utils.make_temp_directory()
        test_file_path = utils.join_path(dir, "test.org")

        utils.write_to(test_file_path, {
            ":PROPERTIES:",
            ":ID: 1234",
            ":END:",
            "#+TITLE: Test",
        })

        db = require("org-roam.database"):new({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = dir,
        })
    end)

    it("should be able to add an alias to the node under cursor", function()
        db:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_file_path)

        -- Add the alias to the file in the buffer
        api.add_alias({ alias = "other test" })

        -- Review that buffer was updated
        assert.are.same({}, utils.read_buffer())
    end)
end)
