describe("org-roam.database", function()
    local db = require("org-roam.database")

    ---@diagnostic disable-next-line:invisible
    db.__path = vim.fn.tempname() .. "-test-db"

    it("todo", function()
    end)
end)
