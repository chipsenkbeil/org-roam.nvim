describe("db", function()
    local DB = require("org-roam.db")

    it("should be able to persist to disk", function()
        local db = DB:new()

        local path = vim.fn.tempname()
        db:write_to_disk(path)

        -- Check the file was created, and then delete it
        assert(vim.fn.filereadable(path) == 1, "File not found at " .. path)
        os.remove(path)
    end)

    it("should be able to be loaded from disk", function()
        local db = DB:new()
        local id = db:insert("test")

        local path = vim.fn.tempname()
        db:write_to_disk(path)

        local new_db = DB:load_from_disk(path)
        assert.equals("test", new_db:get(id))
        os.remove(path)
    end)

    it("should support inserting new, unlinked nodes", function()
        error("TODO")
    end)

    it("should support removing unlinked nodes", function()
        error("TODO")
    end)

    it("should support removing nodes with outbound links", function()
        error("TODO")
    end)

    it("should support removing nodes with inbound links", function()
        error("TODO")
    end)

    it("should support removing nodes with outbound and inbound links", function()
        error("TODO")
    end)

    it("should support retrieving a node by its id", function()
        error("TODO")
    end)

    it("should support retrieving many nodes by their ids", function()
        error("TODO")
    end)

    it("should support getting ids of nodes linked to by a node", function()
        error("TODO")
    end)

    it("should support getting ids of nodes linking to a node", function()
        error("TODO")
    end)

    it("should support linking one node to another (a -> b)", function()
        error("TODO")
    end)

    it("should support unlinking one node from another (a -> b)", function()
        error("TODO")
    end)
end)
