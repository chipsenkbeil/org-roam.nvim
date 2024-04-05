describe("org-roam.core.database", function()
    local Database = require("org-roam.core.database")

    ---Sorts lists a and b using some comparator and then asserts they are the same.
    ---NOTE: The comparator must provide a unique ordering for each list.
    ---@generic T
    ---@param a T[]
    ---@param b T[]
    ---@param cmp fun(a:T, b:T):boolean
    local function same_lists(a, b, cmp)
        table.sort(a, cmp)
        table.sort(b, cmp)
        assert.are.same(a, b)
    end

    it("should be able to persist to disk (synchronously)", function()
        local db = Database:new()

        local path = vim.fn.tempname()
        local err = db:write_to_disk_sync(path)
        assert(not err, err)

        -- Check the file was created, and then delete it
        assert(vim.fn.filereadable(path) == 1, "File not found at " .. path)
        os.remove(path)
    end)

    it("should be able to persist to disk (asynchronously)", function()
        local db = Database:new()

        local error
        local is_done = false

        local path = vim.fn.tempname()
        db:write_to_disk(path, function(err)
            error = err
            is_done = true
        end)

        vim.wait(10000, function() return is_done end)
        assert(not error, error)

        -- Check the file was created, and then delete it
        assert(vim.fn.filereadable(path) == 1, "File not found at " .. path)
        os.remove(path)
    end)

    it("should be able to be loaded from disk (synchronously)", function()
        local db = Database:new()

        -- We save nodes, edges, and indexes, so create all three
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        db:link(id1, id2)
        db:new_index("first_letter", function(node) return node:sub(1, 1) end)
        db:reindex()

        local path = vim.fn.tempname()
        db:write_to_disk_sync(path)

        -- Load a fresh copy of the database and verify that nodes, edges, and indexes still exist
        local err, new_db = Database:load_from_disk_sync(path)
        assert(not err, err) ---@cast new_db -nil
        assert.are.equal("one", new_db:get(id1))
        assert.are.equal("two", new_db:get(id2))
        assert.are.same({ [id2] = 1 }, new_db:get_links(id1))
        assert.are.same({ [id1] = 1 }, new_db:get_backlinks(id2))
        assert.are.same({ id1 }, new_db:find_by_index("first_letter", "o"))
        assert.are.same({ id2 }, new_db:find_by_index("first_letter", "t"))

        -- Delete the database
        os.remove(path)
    end)

    it("should be able to be loaded from disk (asynchronously)", function()
        local db = Database:new()

        -- We save nodes, edges, and indexes, so create all three
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        db:link(id1, id2)
        db:new_index("first_letter", function(node) return node:sub(1, 1) end)
        db:reindex()

        local path = vim.fn.tempname()
        db:write_to_disk_sync(path)

        local error, new_db
        local is_done = false

        -- Load a fresh copy of the database and verify that nodes, edges, and indexes still exist
        Database:load_from_disk(path, function(err, d)
            error = err
            new_db = d
            is_done = true
        end)

        vim.wait(10000, function() return is_done end)
        assert(not error, error) ---@cast new_db -nil

        assert.are.equal("one", new_db:get(id1))
        assert.are.equal("two", new_db:get(id2))
        assert.are.same({ [id2] = 1 }, new_db:get_links(id1))
        assert.are.same({ [id1] = 1 }, new_db:get_backlinks(id2))
        assert.are.same({ id1 }, new_db:find_by_index("first_letter", "o"))
        assert.are.same({ id2 }, new_db:find_by_index("first_letter", "t"))

        -- Delete the database
        os.remove(path)
    end)

    it("should support inserting new, unlinked nodes", function()
        local db = Database:new()
        local id = db:insert("test")
        assert.are.equal("test", db:get(id))
    end)

    it("should support inserting an unlinked node with a specific id", function()
        local db = Database:new()
        local id = db:insert("test", { id = "1234" })
        assert.are.equal("1234", id)

        -- Overwriting with an id that doesn't exist should insert like normal
        local id2 = db:insert("test", { id = "5678", overwrite = true })
        assert.are.equal("5678", id2)
    end)

    it("should throw an error if inserting with an id that already exists", function()
        local db = Database:new()
        local id = db:insert("test")

        assert.is.error(function()
            db:insert("test2", { id = id })
        end)
    end)

    it("should replace an existing node if inserting with an id that exists and overwrite is true", function()
        local db = Database:new()
        local id1 = db:insert("test")
        local id2 = db:insert("test-other")

        -- Perform links in both ways
        db:link(id1, id2)
        db:link(id2, id1)

        assert.are.equal(id1, db:insert("test2", { id = id1, overwrite = true }))
        assert.are.equal("test2", db:get(id1))

        -- Verify links in both ways are restored
        assert.are.same({ [id2] = 1 }, db:get_links(id1))
        assert.are.same({ [id1] = 1 }, db:get_links(id2))
    end)

    it("should support removing unlinked nodes", function()
        local db = Database:new()
        local id = db:insert("test")

        assert.are.equal("test", db:remove(id))
        assert.are.equal(nil, db:remove(id))
    end)

    it("should support removing nodes with outbound links", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "two" -> "three"
        db:link(id1, id2)
        db:link(id2, id3)

        -- Remove "one" node to sever the "one" -> "two" link
        assert.are.equal("one", db:remove(id1))

        -- Verify the link no longer exists
        assert.are.same({}, db:get_links(id1))
        assert.are.same({}, db:get_backlinks(id2))

        -- Verify the other links still exist
        assert.are.same({ [id3] = 1 }, db:get_links(id2))
        assert.are.same({ [id2] = 1 }, db:get_backlinks(id3))
    end)

    it("should support removing nodes with inbound links", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "two" -> "three"
        db:link(id1, id2)
        db:link(id2, id3)

        -- Remove "three" node to sever the "two" -> "three" link
        assert.are.equal("three", db:remove(id3))

        -- Verify the link no longer exists
        assert.are.same({}, db:get_links(id2))
        assert.are.same({}, db:get_backlinks(id3))

        -- Verify the other links still exist
        assert.are.same({ [id2] = 1 }, db:get_links(id1))
        assert.are.same({ [id1] = 1 }, db:get_backlinks(id2))
    end)

    it("should support removing nodes with outbound and inbound links", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "two" -> "three"
        db:link(id1, id2)
        db:link(id2, id3)

        -- Remove "two" node to sever the "one" -> "two" and "two" -> "three" links
        assert.are.equal("two", db:remove(id2))

        -- Verify the links no longer exist
        assert.are.same({}, db:get_links(id1))
        assert.are.same({}, db:get_links(id2))
        assert.are.same({}, db:get_backlinks(id2))
        assert.are.same({}, db:get_backlinks(id3))
    end)

    it("should support reporting if a node exists by id", function()
        local db = Database:new()
        local id = db:insert("test")
        assert.is_true(db:has(id))
    end)

    it("should support retrieving a node by its id", function()
        local db = Database:new()
        local id = db:insert("test")
        assert.are.equal("test", db:get(id))
    end)

    it("should support retrieving many nodes by their ids", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        assert.are.same({
            [id1] = "one",
            [id2] = "two",
            [id3] = "three",
        }, db:get_many(id1, id2, id3))
    end)

    it("should support retrieving ids within database", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        local expected = { id1, id2, id3 }
        table.sort(expected)

        local ids

        ids = db:iter_ids():collect()
        table.sort(ids)
        assert.are.same(expected, ids)

        ids = db:ids()
        table.sort(ids)
        assert.are.same(expected, ids)
    end)

    it("should support getting ids of nodes linked to by a node", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "one" -> "three"
        db:link(id1, id2)
        db:link(id1, id3)

        assert.are.same({ [id2] = 1, [id3] = 1 }, db:get_links(id1))
    end)

    it("should support getting ids of nodes linked to by a node indirectly", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        local id4 = db:insert("four")

        -- Create outbound links
        db:link(id1, id2)
        db:link(id2, id3)
        db:link(id3, id4)

        -- Test with max depth 2 so we can verify we get one node, but not the one at depth 3
        assert.are.same({ [id2] = 1, [id3] = 2 }, db:get_links(id1, { max_depth = 2 }))
    end)

    it("should support getting ids of non-existent nodes linked to by a node", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        db:link(id1, id2, "three")
        db:link(id2, "four", "five")

        assert.are.same({
            [id2] = 1,
            ["three"] = 1,
            ["four"] = 2,
            ["five"] = 2,
        }, db:get_links(id1, { max_depth = 2 }))
    end)

    it("should support getting ids of nodes linking to a node", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "two" -> "one" and "three" -> "one"
        db:link(id2, id1)
        db:link(id3, id1)

        assert.are.same({ [id2] = 1, [id3] = 1 }, db:get_backlinks(id1))
    end)

    it("should support getting ids of nodes linking to a node indirectly", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        local id4 = db:insert("four")

        -- Create outbound links
        db:link(id1, id2)
        db:link(id2, id3)
        db:link(id3, id4)

        assert.are.same({ [id2] = 2, [id3] = 1 }, db:get_backlinks(id4, { max_depth = 2 }))
    end)

    it("should support linking one node to another (a -> b)", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        db:link(id1, id2)
        assert.are.same({ [id2] = 1 }, db:get_links(id1))
        assert.are.same({ [id1] = 1 }, db:get_backlinks(id2))
    end)

    it("should support unlinking one node from another (a -> b)", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        -- Link both ways so we can verify we don't break links in opposite direction
        db:link(id1, id2)
        db:link(id2, id1)

        -- Unlink "one" -> "two", but keep "two" -> "one"
        db:unlink(id1, id2)

        assert.are.same({}, db:get_links(id1))
        assert.are.same({}, db:get_backlinks(id2))

        assert.are.same({ [id1] = 1 }, db:get_links(id2))
        assert.are.same({ [id2] = 1 }, db:get_backlinks(id1))
    end)

    it("should support indexing by node value and looking up nodes by index", function()
        local db = Database:new()
            :new_index("starts_with_t", function(node)
                -- Only index values that start with t
                if vim.startswith(node, "t") then
                    return true
                end
            end)
            :new_index("e_cnt", function(node)
                local cnt = 0
                for i = 1, #node do
                    local c = node:sub(i, i)
                    if c == "e" then
                        cnt = cnt + 1
                    end
                end
                return cnt
            end)
            :new_index("char", function(node)
                local chars = {}
                for i = 1, #node do
                    local c = node:sub(i, i)
                    chars[c] = true
                end
                return vim.tbl_keys(chars)
            end)

        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Look up nodes that start with letter "t"
        local expected = { id2, id3 }
        local actual = db:find_by_index("starts_with_t", true)
        table.sort(expected)
        table.sort(actual)
        assert.are.same(expected, actual)

        -- Look up nodes with "e" based on total count of "e"
        assert.are.same({ id3 }, db:find_by_index("e_cnt", 2))

        -- Use function to find matches (much slower)
        local expected = { id2, id3 }
        local actual = db:find_by_index("e_cnt", function(cnt)
            return cnt ~= 1
        end)
        table.sort(expected)
        table.sort(actual)
        assert.are.same(expected, actual)

        -- Indexer returning array results in an index per item
        local expected = { id1, id2 }
        local actual = db:find_by_index("char", "o")
        table.sort(expected)
        table.sort(actual)
        assert.are.same(expected, actual)
    end)

    it("should support determining if an index exists", function()
        local db = Database:new():new_index("name", function(node)
            return node.name
        end)

        assert.is_false(db:has_index("key"))
        assert.is_true(db:has_index("name"))
    end)

    it("should support iterating over indexed values", function()
        local db = Database:new():new_index("name", function(node)
            return node.name
        end)

        db:insert({ name = "one", value = 1 })
        db:insert({ name = "two", value = 2 })
        db:insert({ name = "three", value = 3 })
        db:insert({ name = { "four", "five" }, value = 4 })

        -- Retrieves names as the indexed keys for the name indexer
        local keys = db:iter_index_keys("name"):collect()
        table.sort(keys)

        assert.are.same({ "five", "four", "one", "three", "two" }, keys)
    end)

    it("should support iterating over nodes from a starting node", function()
        ---Sorts tuple lists a and b by their id fields and then asserts they are the same.
        ---@param a {[1]: string, [2]: integer}[]
        ---@param b {[1]: string, [2]: integer}[]
        local function same_tuple_lists(a, b)
            same_lists(a, b, function(x, y) return x[1] < y[1] end)
        end

        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        local id4 = db:insert("four")
        local id5 = db:insert("five")
        local id6 = db:insert("six")

        -- Link up our database of nodes in this way
        --
        -- 2 <- 1 -> 3    6
        --      ^    ^
        --      |    |
        --      V    |
        --      4 -> 5
        db:link(id1, id2, id3, id4)
        db:link(id4, id1, id5)
        db:link(id5, id3)

        -- Traversing on 1 will navigate to all nodes directly and indirectly connected
        same_tuple_lists({
            { id1, 0, n = 2 },
            { id2, 1, n = 2 },
            { id3, 1, n = 2 },
            { id4, 1, n = 2 },
            { id5, 2, n = 2 },
        }, db:iter_nodes({ start_node_id = id1 }):collect())

        -- Traversing on 2 or 3 will only find itself because we do not traverse backlinks
        same_tuple_lists({
            { id2, 0, n = 2 },
        }, db:iter_nodes({ start_node_id = id2 }):collect())
        same_tuple_lists({
            { id3, 0, n = 2 },
        }, db:iter_nodes({ start_node_id = id3 }):collect())

        -- Traversing on 4 can achieve the same thanks to some bi-directional links
        same_tuple_lists({
            { id4, 0, n = 2 },
            { id1, 1, n = 2 },
            { id5, 1, n = 2 },
            { id2, 2, n = 2 },
            { id3, 2, n = 2 },
        }, db:iter_nodes({ start_node_id = id4 }):collect())

        -- Traversing on 5 will only find nodes it points to and not traverse across backlinks
        same_tuple_lists({
            { id5, 0, n = 2 },
            { id3, 1, n = 2 },
        }, db:iter_nodes({ start_node_id = id5 }):collect())

        -- Traversing on 6 will only find itself because there is nothing linked
        same_tuple_lists({
            { id6, 0, n = 2 },
        }, db:iter_nodes({ start_node_id = id6 }):collect())

        -- Limiting maximum nodes should exit once that count has been reached
        same_tuple_lists({
            { id1, 0, n = 2 },
        }, db:iter_nodes({ start_node_id = id1, max_nodes = 1 }):collect())

        -- Limiting maximum distance should restrict traversal to closer nodes
        same_tuple_lists({
            { id1, 0, n = 2 },
            { id2, 1, n = 2 },
            { id3, 1, n = 2 },
            { id4, 1, n = 2 },
        }, db:iter_nodes({ start_node_id = id1, max_distance = 1 }):collect())

        -- Filtering should support blocking out traversal to nodes
        same_tuple_lists({
            { id1, 0, n = 2 },
            { id3, 1, n = 2 },
        }, db:iter_nodes({
            start_node_id = id1,
            filter = function(id, _)
                return id ~= id2 and id ~= id4
            end,
        }):collect())
    end)

    it("should support iterating through paths between nodes", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        local id4 = db:insert("four")
        local id5 = db:insert("five")
        local id6 = db:insert("six")

        -- Link up our database of nodes in this way
        --
        -- 2 <- 1 -> 3    6
        --      ^    ^
        --      |    |
        --      V    |
        --      4 -> 5
        db:link(id1, id2, id3, id4)
        db:link(id4, id1, id5)
        db:link(id5, id3)

        -- Find paths going from 1 -> 3
        local it = db:iter_paths(id1, id3)
        assert.are.same({ id1, id3 }, it:next())
        assert.are.same({ id1, id4, id5, id3 }, it:next())
        assert.is_nil(it:next())

        -- Find paths going from 1 -> 6
        it = db:iter_paths(id1, id6)
        assert.is_nil(it:next())

        -- Find paths going from 4 -> 3
        local paths = db:iter_paths(id4, id3):collect()
        same_lists({
            { id4, id1, id3 },
            { id4, id5, id3 },
        }, paths, function(a, b)
            if #a ~= #b then
                return #a < #b
            end

            for i = 1, #a do
                local aa = a[i]
                local bb = b[i]

                if aa ~= bb then
                    return aa < bb
                end
            end

            return false
        end)

        -- Limit paths going from 1 -> 3
        it = db:iter_paths(id1, id3, { max_distance = 1 })
        assert.are.same({ id1, id3 }, it:next())
        assert.is_nil(it:next())

        -- Go to self 1 -> 1
        it = db:iter_paths(id1, id1)
        assert.are.same({ id1 }, it:next())
        assert.is_nil(it:next())
    end)

    it("should be able to find a path between nodes", function()
        local db = Database:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        local id4 = db:insert("four")

        -- Link up our database of nodes in this way
        --
        -- 2 <- 1 -> 3 -> 4
        db:link(id1, id2, id3)
        db:link(id3, id4)

        -- Find paths
        assert.are.same({ id1 }, db:find_path(id1, id1))
        assert.are.same({ id1, id2 }, db:find_path(id1, id2))
        assert.are.same({ id1, id3 }, db:find_path(id1, id3))
        assert.are.same({ id1, id3, id4 }, db:find_path(id1, id4))
        assert.is_nil(db:find_path(id1, id4, { max_distance = 1 }))
        assert.are.same({ id3, id4 }, db:find_path(id3, id4))
        assert.is_nil(db:find_path(id2, id1))
        assert.is_nil(db:find_path(id3, id1))
        assert.is_nil(db:find_path(id2, id3))
        assert.is_nil(db:find_path(id2, id4))
        assert.is_nil(db:find_path(id4, id3))
        assert.is_nil(db:find_path(id4, id2))
        assert.is_nil(db:find_path(id4, id1))
    end)
end)
