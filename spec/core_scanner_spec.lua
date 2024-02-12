describe("core.scanner", function()
    local join_path = require("org-roam.core.utils.io").join_path
    local scanner = require("org-roam.core.scanner")

    local ORG_FILES_DIR = (function()
        local str = debug.getinfo(2, "S").source:sub(2)
        return join_path(vim.fs.dirname(str:match("(.*/)")), "files")
    end)()

    it("should support scanning a directory for org files", function()
        local is_done = false
        local error

        ---@type {[string]:org-roam.core.database.Node}
        local nodes = {}

        scanner.scan(ORG_FILES_DIR, function(err, node)
            -- Only catch the first error to report back
            if not error then
                error = err
            end

            if node then
                -- We shouldn't have the same node twice
                if nodes[node.id] then
                    error = "Already have node " .. node.id
                end

                nodes[node.id] = node
            end

            -- Scan is called one last time once finished with no arguments
            is_done = err == nil and node == nil
        end)

        vim.wait(1000, function() return is_done end)
        assert(is_done, "Scanner failed to complete in time")
        assert(not error, error)

        ---@type org-roam.core.database.Node
        local node

        node = assert(nodes["1"], "missing node 1")
        assert.equals("1", node.id)
        assert.equals(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.equals("one", node.title)
        assert.same({ "1", "neo", "the one" }, node.aliases)
        assert.equals(0, node.level)
        assert.same({ "a", "b", "c" }, node.tags)
        assert.same({ "2", "3", "4" }, node.linked)

        node = assert(nodes["2"], "missing node 2")
        assert.equals("2", node.id)
        assert.equals(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.equals("node two", node.title)
        assert.same({}, node.aliases)
        assert.equals(1, node.level)
        assert.same({ "a", "b", "c", "d", "e", "f" }, node.tags)
        assert.same({}, node.linked)

        node = assert(nodes["3"], "missing node 3")
        assert.equals("3", node.id)
        assert.equals(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.equals("node three", node.title)
        assert.same({}, node.aliases)
        assert.equals(1, node.level)
        assert.same({ "a", "b", "c", "d", "e", "f", "g", "h", "i" }, node.tags)
        assert.same({}, node.linked)
    end)

    it("should support scanning explicitly-provided org files", function()
        error("todo")
    end)
end)
