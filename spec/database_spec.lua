describe("org-roam.database", function()
    local db = require("org-roam.database")

    ---@diagnostic disable-next-line:invisible
    db.__path = vim.fn.tempname() .. "-test-db"

    local ORG_FILES_DIR = (function()
        local path = require("org-roam.core.utils.path")
        local str = debug.getinfo(2, "S").source:sub(2)
        return path.join(vim.fs.dirname(str:match("(.*/)")), "files")
    end)()

    ---@diagnostic disable-next-line:invisible
    db.__files_directory = ORG_FILES_DIR

    it("should support loading all nodes", function()
        local results = db:load():wait()
    end)
end)
