describe("org-roam.setup", function()
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should fail if no directory supplied", function()
        assert.is.error(function()
            local roam = utils.init_plugin({ setup = false })
            roam.setup({}):wait()
        end)
    end)

    it("should adjust the database to the supplied configuration", function()
        local db_path = vim.fn.tempname() .. "-test-db"
        local directory = utils.make_temp_org_files_directory()

        local roam = utils.init_plugin({ setup = false })
        roam.setup({
            database = { path = db_path },
            directory = directory,
        }):wait()

        assert.are.equal(db_path, roam.database:path())
        assert.are.equal(directory, roam.database:files_path())
    end)
end)
