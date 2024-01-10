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

        -- We save nodes, edges, and indexes, so create all three
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        db:link(id1, id2)
        db:new_index("first_letter", function(node) return node:sub(1, 1) end)
        db:reindex()

        local path = vim.fn.tempname()
        db:write_to_disk(path)

        -- Load a fresh copy of the database and verify that nodes, edges, and indexes still exist
        local new_db = DB:load_from_disk(path)
        assert.equals("one", new_db:get(id1))
        assert.equals("two", new_db:get(id2))
        assert.same({ [id2] = 1 }, new_db:get_links(id1))
        assert.same({ [id1] = 1 }, new_db:get_backlinks(id2))
        assert.same({ id1 }, new_db:find_by_index("first_letter", "o"))
        assert.same({ id2 }, new_db:find_by_index("first_letter", "t"))

        -- Delete the database
        os.remove(path)
    end)

    it("should support inserting new, unlinked nodes", function()
        local db = DB:new()
        local id = db:insert("test")
        assert.equals("test", db:get(id))
    end)

    it("should support removing unlinked nodes", function()
        local db = DB:new()
        local id = db:insert("test")

        assert.equals("test", db:remove(id))
        assert.equals(nil, db:remove(id))
    end)

    it("should support removing nodes with outbound links", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "two" -> "three"
        db:link(id1, id2)
        db:link(id2, id3)

        -- Remove "one" node to sever the "one" -> "two" link
        assert.equals("one", db:remove(id1))

        -- Verify the link no longer exists
        assert.same({}, db:get_links(id1))
        assert.same({}, db:get_backlinks(id2))

        -- Verify the other links still exist
        assert.same({ [id3] = 1 }, db:get_links(id2))
        assert.same({ [id2] = 1 }, db:get_backlinks(id3))
    end)

    it("should support removing nodes with inbound links", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "two" -> "three"
        db:link(id1, id2)
        db:link(id2, id3)

        -- Remove "three" node to sever the "two" -> "three" link
        assert.equals("three", db:remove(id3))

        -- Verify the link no longer exists
        assert.same({}, db:get_links(id2))
        assert.same({}, db:get_backlinks(id3))

        -- Verify the other links still exist
        assert.same({ [id2] = 1 }, db:get_links(id1))
        assert.same({ [id1] = 1 }, db:get_backlinks(id2))
    end)

    it("should support removing nodes with outbound and inbound links", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "two" -> "three"
        db:link(id1, id2)
        db:link(id2, id3)

        -- Remove "two" node to sever the "one" -> "two" and "two" -> "three" links
        assert.equals("two", db:remove(id2))

        -- Verify the links no longer exist
        assert.same({}, db:get_links(id1))
        assert.same({}, db:get_links(id2))
        assert.same({}, db:get_backlinks(id2))
        assert.same({}, db:get_backlinks(id3))
    end)

    it("should support retrieving a node by its id", function()
        local db = DB:new()
        local id = db:insert("test")
        assert.equals("test", db:get(id))
    end)

    it("should support retrieving many nodes by their ids", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        assert.same({
            [id1] = "one",
            [id2] = "two",
            [id3] = "three",
        }, db:get_many(id1, id2, id3))
    end)

    it("should support getting ids of nodes linked to by a node", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "one" -> "two" and "one" -> "three"
        db:link(id1, id2)
        db:link(id1, id3)

        assert.same({ [id2] = 1, [id3] = 1 }, db:get_links(id1))
    end)

    it("should support getting ids of nodes linked to by a node indirectly", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        local id4 = db:insert("four")

        -- Create outbound links
        db:link(id1, id2)
        db:link(id2, id3)
        db:link(id3, id4)

        -- Test with max depth 2 so we can verify we get one node, but not the one at depth 3
        assert.same({ [id2] = 1, [id3] = 2 }, db:get_links(id1, { max_depth = 2 }))
    end)

    it("should support getting ids of nodes linking to a node", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Create outbound link from "two" -> "one" and "three" -> "one"
        db:link(id2, id1)
        db:link(id3, id1)

        assert.same({ [id2] = 1, [id3] = 1 }, db:get_backlinks(id1))
    end)

    it("should support getting ids of nodes linking to a node indirectly", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")
        local id4 = db:insert("four")

        -- Create outbound links
        db:link(id1, id2)
        db:link(id2, id3)
        db:link(id3, id4)

        assert.same({ [id2] = 2, [id3] = 1 }, db:get_backlinks(id4, { max_depth = 2 }))
    end)

    it("should support linking one node to another (a -> b)", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        db:link(id1, id2)
        assert.same({ [id2] = 1 }, db:get_links(id1))
        assert.same({ [id1] = 1 }, db:get_backlinks(id2))
    end)

    it("should support unlinking one node from another (a -> b)", function()
        local db = DB:new()
        local id1 = db:insert("one")
        local id2 = db:insert("two")

        -- Link both ways so we can verify we don't break links in opposite direction
        db:link(id1, id2)
        db:link(id2, id1)

        -- Unlink "one" -> "two", but keep "two" -> "one"
        db:unlink(id1, id2)

        assert.same({}, db:get_links(id1))
        assert.same({}, db:get_backlinks(id2))

        assert.same({ [id1] = 1 }, db:get_links(id2))
        assert.same({ [id2] = 1 }, db:get_backlinks(id1))
    end)

    it("should support indexing by node value and looking up nodes by index", function()
        local db = DB:new()
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

        local id1 = db:insert("one")
        local id2 = db:insert("two")
        local id3 = db:insert("three")

        -- Look up nodes that start with letter "t"
        local expected = { id2, id3 }
        local actual = db:find_by_index("starts_with_t", true)
        table.sort(expected)
        table.sort(actual)
        assert.same(expected, actual)

        -- Look up nodes with "e" based on total count of "e"
        assert.same({ id3 }, db:find_by_index("e_cnt", 2))

        -- Use function to find matches (much slower)
        local expected = { id2, id3 }
        local actual = db:find_by_index("e_cnt", function(cnt)
            return cnt ~= 1
        end)
        table.sort(expected)
        table.sort(actual)
        assert.same(expected, actual)
    end)
end)
