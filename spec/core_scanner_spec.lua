describe("org-roam.core.scanner", function()
    local join_path = require("org-roam.core.utils.path").join
    local Scanner = require("org-roam.core.scanner")

    local ORG_FILES_DIR = (function()
        local str = debug.getinfo(2, "S").source:sub(2)
        return join_path(vim.fs.dirname(str:match("(.*/)")), "files")
    end)()

    it("should support scanning a directory for org files", function()
        local error

        ---@type {[string]:org-roam.core.file.Node}
        local nodes = {}

        local scanner = Scanner
            :new({ ORG_FILES_DIR })
            :on_scan(function(scan)
                if not scan.file then
                    error = "Scan missing parsed file"
                    return
                end

                for _, node in ipairs(scan.nodes) do
                    if node then
                        -- We shouldn't have the same node twice
                        if nodes[node.id] then
                            error = "Already have node " .. node.id
                            return
                        end

                        nodes[node.id] = node
                    end
                end
            end)
            :on_error(function(err) error = err end)
            :start()

        vim.wait(1000, function() return not scanner:is_running() end)
        assert(not scanner:is_running(), "Scanner failed to complete in time")
        assert(not error, error)

        ---@type org-roam.core.file.Node
        local node

        node = assert(nodes["1"], "missing node 1")
        assert.are.equal("1", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.are.equal("one", node.title)
        assert.are.same({ "1", "neo", "the one" }, node.aliases)
        assert.are.equal(0, node.level)
        assert.are.same({ "a", "b", "c" }, node.tags)
        assert.are.same({
            ["2"] = { { row = 7, column = 2, offset = 138 } },
            ["3"] = { { row = 8, column = 2, offset = 149 } },
            ["4"] = { { row = 9, column = 2, offset = 160 } },
        }, node.linked)

        node = assert(nodes["2"], "missing node 2")
        assert.are.equal("2", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.are.equal("node two", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(1, node.level)
        assert.are.same({ "a", "b", "c", "d", "e", "f" }, node.tags)
        assert.are.same({
            ["1"] = { { row = 16, column = 36, offset = 258 } },
            ["3"] = { { row = 16, column = 49, offset = 271 } },
        }, node.linked)

        node = assert(nodes["3"], "missing node 3")
        assert.are.equal("3", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.are.equal("node three", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(2, node.level)
        assert.are.same({ "a", "b", "c", "d", "e", "f", "g", "h", "i" }, node.tags)
        assert.are.same({
            ["2"] = { { row = 23, column = 42, offset = 379 } },
        }, node.linked)

        node = assert(nodes["1234"], "missing node 1234")
        assert.are.equal("1234", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "test.org"), node.file)
        assert.are.equal("some title", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(0, node.level)
        assert.are.same({ "a", "b", "c" }, node.tags)
        assert.are.same({
            ["1234"] = { { row = 22, column = 2, offset = 291 } },
            ["5678"] = { { row = 23, column = 2, offset = 333 } },
        }, node.linked)

        node = assert(nodes["5678"], "missing node 5678")
        assert.are.equal("5678", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "test.org"), node.file)
        assert.are.equal("Heading 1 that is a node", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(1, node.level)
        assert.are.same({ "a", "b", "c" }, node.tags)
        assert.are.same({}, node.linked)

        node = assert(nodes["9999"], "missing node 9999")
        assert.are.equal("9999", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "test.org"), node.file)
        assert.are.equal("Heading 3 that is a node with tags", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(1, node.level)
        assert.are.same({ "a", "b", "c", "tag1", "tag2" }, node.tags)
        assert.are.same({}, node.linked)

        node = assert(nodes["links-1234"], "missing node links-1234")
        assert.are.equal("links-1234", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "links.org"), node.file)
        assert.are.equal("links", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(0, node.level)
        assert.are.same({}, node.tags)
        assert.are.same({
            ["1234"] = { { row = 6, column = 2, offset = 57 } },
            ["5678"] = { { row = 7, column = 2, offset = 99 } },
        }, node.linked)
    end)

    it("should support scanning explicitly-provided org files", function()
        local error

        ---@type org-roam.core.scanner.Scan
        local scan

        local scanner = Scanner
            :new({ join_path(ORG_FILES_DIR, "one.org") })
            :on_scan(function(s)
                for _, node in ipairs(s.nodes) do
                    if node then
                        -- We shouldn't have the same node twice
                        if s.nodes[node.id] then
                            error = "Already have node " .. node.id
                            return
                        end
                    end
                end

                scan = s
            end)
            :on_error(function(err) error = err end)
            :start()

        vim.wait(1000, function() return not scanner:is_running() end)
        assert(not scanner:is_running(), "Scanner failed to complete in time")
        assert(not error, error)

        -- Verify the scan path and file are correct
        assert.are.equal(join_path(ORG_FILES_DIR, "one.org"), scan.path)
        assert.is_not_nil(scan.file)

        -- Make a map of node id -> node for tests so we can avoid dependency on order
        local nodes = {}
        for _, node in ipairs(scan.nodes) do
            nodes[node.id] = node
        end

        ---@type org-roam.core.file.Node
        local node

        node = assert(nodes["1"], "missing node 1")
        assert.are.equal("1", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.are.equal("one", node.title)
        assert.are.same({ "1", "neo", "the one" }, node.aliases)
        assert.are.equal(0, node.level)
        assert.are.same({ "a", "b", "c" }, node.tags)
        assert.are.same({
            ["2"] = { { row = 7, column = 2, offset = 138 } },
            ["3"] = { { row = 8, column = 2, offset = 149 } },
            ["4"] = { { row = 9, column = 2, offset = 160 } },
        }, node.linked)

        node = assert(nodes["2"], "missing node 2")
        assert.are.equal("2", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.are.equal("node two", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(1, node.level)
        assert.are.same({ "a", "b", "c", "d", "e", "f" }, node.tags)
        assert.are.same({
            ["1"] = { { row = 16, column = 36, offset = 258 } },
            ["3"] = { { row = 16, column = 49, offset = 271 } },
        }, node.linked)

        node = assert(nodes["3"], "missing node 3")
        assert.are.equal("3", node.id)
        assert.are.equal(join_path(ORG_FILES_DIR, "one.org"), node.file)
        assert.are.equal("node three", node.title)
        assert.are.same({}, node.aliases)
        assert.are.equal(2, node.level)
        assert.are.same({ "a", "b", "c", "d", "e", "f", "g", "h", "i" }, node.tags)
        assert.are.same({
            ["2"] = { { row = 23, column = 42, offset = 379 } },
        }, node.linked)
    end)
end)
