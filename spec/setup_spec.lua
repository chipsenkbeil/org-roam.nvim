describe("org-roam.setup", function()
    local roam = require("org-roam")
    local utils = require("spec.utils")

    before_each(function()
        roam.db = roam.db:new({
            db_path = vim.fn.tempname() .. "-test-db",
            directory = utils.make_temp_org_files_directory(),
        })
    end)

    it("should fail of no directory supplied", function()
        assert.is.error(function()
            roam.setup({})
        end)
    end)

    it("should adjust the database to the supplied configuration", function()
        local db_path = vim.fn.tempname() .. "-test-db"
        local directory = utils.make_temp_org_files_directory()

        roam.setup({
            database = { path = db_path },
            directory = directory,
        })

        assert.are.equal(db_path, roam.db:path())
        assert.are.equal(directory, roam.db:files_path())
    end)
end)
