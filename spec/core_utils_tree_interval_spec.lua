describe("utils.tree.interval", function()
    local Tree = require("org-roam.core.utils.tree.interval")

    it("should build up a tree using start & end of intervals", function()
        -- Tree is built up using the list in order
        local tree = Tree:from_list({
            { 20, 36, "a" },
            { 3,  41, "b" },
            { 29, 99, "c" },
            { 0,  1,  "d" },
            { 10, 15, "e" },
        })

        --        a
        --       / \
        --      b   c
        --     / \
        --    d   e
        assert.equals("a", tree.data)
        assert.equals(1, tree:depth())
        assert.equals("b", tree.left.data)
        assert.equals(2, tree.left:depth())
        assert.equals("c", tree.right.data)
        assert.equals(2, tree.right:depth())
        assert.equals("d", tree.left.left.data)
        assert.equals(3, tree.left.left:depth())
        assert.equals("e", tree.left.right.data)
        assert.equals(3, tree.left.right:depth())
    end)

    it("should support querying for tree nodes that intersect with a point", function()
        local tree = Tree:from_list({
            { 20, 36, "a" },
            { 3,  41, "b" },
            { 29, 99, "c" },
            { 0,  1,  "d" },
            { 10, 15, "e" },
        })

        ---@param i integer
        ---@return string[]
        local function values_at_point(i)
            return vim.tbl_map(function(node)
                return node.data
            end, tree:find_all({ i, match = "intersects" }))
        end

        assert.same({}, values_at_point(-1))
        assert.same({ "d" }, values_at_point(0))
        assert.same({ "d" }, values_at_point(1))
        assert.same({}, values_at_point(2))
        assert.same({ "b" }, values_at_point(3))
        assert.same({ "b", "e" }, values_at_point(10))
        assert.same({ "b", "e" }, values_at_point(15))
        assert.same({ "a", "b" }, values_at_point(20))
        assert.same({ "a", "b" }, values_at_point(25))
        assert.same({ "a", "b", "c" }, values_at_point(29))
        assert.same({ "a", "b", "c" }, values_at_point(36))
        assert.same({ "b", "c" }, values_at_point(41))
        assert.same({ "c" }, values_at_point(99))
        assert.same({}, values_at_point(100))
    end)

    it("should support querying for tree nodes that intersect with an interval", function()
        local tree = Tree:from_list({
            { 20, 36, "a" },
            { 3,  41, "b" },
            { 29, 99, "c" },
            { 0,  1,  "d" },
            { 10, 15, "e" },
        })

        ---@param i integer
        ---@param j integer
        ---@return string[]
        local function values_at_interval(i, j)
            return vim.tbl_map(function(node)
                return node.data
            end, tree:find_all({ i, j, match = "intersects" }))
        end

        -- Test intervals that have the same start and end
        assert.same({}, values_at_interval(-1, -1))
        assert.same({ "d" }, values_at_interval(0, 0))
        assert.same({ "d" }, values_at_interval(1, 1))
        assert.same({}, values_at_interval(2, 2))
        assert.same({ "b" }, values_at_interval(3, 3))
        assert.same({ "b", "e" }, values_at_interval(10, 10))
        assert.same({ "b", "e" }, values_at_interval(15, 15))
        assert.same({ "a", "b" }, values_at_interval(20, 20))
        assert.same({ "a", "b" }, values_at_interval(25, 25))
        assert.same({ "a", "b", "c" }, values_at_interval(29, 29))
        assert.same({ "a", "b", "c" }, values_at_interval(36, 36))
        assert.same({ "b", "c" }, values_at_interval(41, 41))
        assert.same({ "c" }, values_at_interval(99, 99))
        assert.same({}, values_at_interval(100, 100))

        -- Test longer intervals
        assert.same({}, values_at_interval(-100, -1))
        assert.same({ "a", "b", "c", "d", "e" }, values_at_interval(0, 99))
        assert.same({ "a", "b", "c", "d", "e" }, values_at_interval(1, 29))
        assert.same({ "a", "b", "e" }, values_at_interval(2, 28))
        assert.same({ "a", "b", "e" }, values_at_interval(10, 20))
        assert.same({ "a", "b" }, values_at_interval(16, 20))
        assert.same({ "b", "c" }, values_at_interval(40, 50))
        assert.same({ "c" }, values_at_interval(50, 60))
    end)
end)
