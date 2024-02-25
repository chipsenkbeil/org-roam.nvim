-------------------------------------------------------------------------------
-- INTERVAL.LUA
--
-- Abstraction of an interval tree.
--
-- From Wikipedia:
--
-- > An augmented tree can be built from a simple ordered tree, for example a
-- > binary search tree or self-balancing binary search tree, ordered by the
-- > 'low' values of the intervals. An extra annotation is then added to every
-- > node, recording the maximum upper value among all the intervals from this
-- > node down.
-- >
-- > Maintaining this attribute involves updating all ancestors of the
-- > node from the bottom up whenever a node is added or deleted. This takes
-- > only O(h) steps per node addition or removal, where h is the height of the
-- > node added or removed in the tree. If there are any tree rotations during
-- > insertion and deletion, the affected nodes may need updating as well.
-- >
-- > Both insertion and deletion require O(log n) time, with n being the
-- > total number of intervals in the tree prior to the insertion or deletion
-- > operation.
-- >
-- > Now, it is known that two intervals A and B overlap only when both
-- > A(low) <= B(high) and A(high) >= B(low). When searching the trees for
-- > nodes overlapping with a given interval, you can immediately skip:
-- >
-- > 1. all nodes to the right of nodes whose low value is past the end of the
-- >    given interval.
-- > 2. all nodes that have their maximum high value below the start of the
-- >    given interval.
-------------------------------------------------------------------------------

local Queue = require("org-roam.core.utils.queue")
local unpack = require("org-roam.core.utils.table").unpack

---An augmented tree using intervals as defined in
---[Wikipedia](https://en.wikipedia.org/wiki/Interval_tree#Augmented_tree).
---
---@class org-roam.core.utils.tree.IntervalTree
---@field data any
---@field private _depth integer
---@field private _start integer
---@field private _end integer
---@field private _max integer #maximum upper value of all intervals from this point down
---@field left? org-roam.core.utils.tree.IntervalTree
---@field right? org-roam.core.utils.tree.IntervalTree
local M = {}
M.__index = M

---Creates a new instance of the tree with no leaf nodes.
---@param start integer #inclusive start of interval
---@param end_ integer #inclusive end of interval
---@param data any
---@return org-roam.core.utils.tree.IntervalTree
function M:new(start, end_, data)
    local instance = {}
    setmetatable(instance, M)
    instance.data = data
    instance._depth = 1
    instance._start = start
    instance._end = end_
    instance._max = end_
    return instance
end

---Builds a tree from the list of intervals (inclusive start/end) and data.
---Will fail if the list is empty.
---@param lst {[1]:integer, [2]:integer, [3]:any}[]
---@return org-roam.core.utils.tree.IntervalTree
function M:from_list(lst)
    assert(not vim.tbl_isempty(lst), "List cannot be empty")

    -- Create the tree with the root being the first item in the list
    local tree = M:new(lst[1][1], lst[1][2], lst[1][3])

    -- For all remaining list items, add them to the tree
    for i = 2, #lst do
        tree:insert(lst[i][1], lst[i][2], lst[i][3])
    end

    return tree
end

---Returns the range of this tree, [start, end].
---@return {[1]:integer, [2]:integer}
function M:range()
    return { self._start, self._end }
end

---Returns depth of node in the tree with 1 being the root node.
---@return integer
function M:depth()
    return self._depth
end

---@return string
function M:__tostring()
    return vim.inspect(self)
end

---Returns comparsing of tree intervals.
---
---* -1 means tree A has an interval that either starts before or ends earlier than tree B.
---* 0 means tree A has the exact same interval as tree B.
---* 1 means tree A has an interval that either starts after or ends later than tree B.
---
---@param a org-roam.core.utils.tree.IntervalTree
---@param b org-roam.core.utils.tree.IntervalTree
---@return -1|0|1 cmp
local function cmp_tree_interval(a, b)
    ---@type integer, integer
    local a_start, a_end = unpack(a:range())
    ---@type integer, integer
    local b_start, b_end = unpack(b:range())

    if a_start < b_start then
        return -1
    end

    if a_start > b_start then
        return 1
    end

    -- Starts are the same, so figure out
    -- based on the end instead
    if a_end < b_end then
        return -1
    elseif a_end > b_end then
        return 1
    else
        return 0
    end
end

---@param start integer #inclusive start of interval
---@param end_ integer #inclusive end of interval
---@param data any
---@return org-roam.core.utils.tree.IntervalTree
function M:insert(start, end_, data)
    local tree = M:new(start, end_, data)

    ---@type org-roam.core.utils.tree.IntervalTree|nil
    local cur = self

    -- Figure out where to place the new node, updating
    -- the maximum value maintained by nodes as we go down
    while cur do
        -- Update the max value of the current node based on the new
        -- data's interval in the case that it is higher
        cur._max = math.max(cur._max, end_)

        -- Check which direction we go (left or right) by comparing
        -- intervals. If the new tree node starts earlier/is smaller
        -- then we go left, otherwise we go right. If there is no
        -- tree node in that direction, we insert ourselves and flag
        -- to stop the loop, otherwise continue traversal.
        local cmp = cmp_tree_interval(cur, tree)
        if cmp == 1 and cur.left then
            cur = cur.left
        elseif cmp == 1 then
            cur.left = tree
            cur.left._depth = cur._depth + 1
            cur = nil
        elseif cur.right then
            cur = cur.right
        else
            cur.right = tree
            cur.right._depth = cur._depth + 1
            cur = nil
        end
    end

    return tree
end

---Function used to find matches during a search.
---@alias org-roam.core.utils.tree.interval.MatchFn fun(node:org-roam.core.utils.tree.IntervalTree, start:integer|nil, end_:integer|nil):boolean

---@class org-roam.core.utils.tree.interval.FindOpts
---@field [1] integer|nil #lower bound (inclusive) of interval to use for search
---@field [2] integer|nil #upper bound (inclusive) of interval to use for search
---@field limit? integer #maximum nodes to find before stopping; defaults to unlimited
---@field match? "c"|"contains"|"i"|"intersects"|org-roam.core.utils.tree.interval.MatchFn

---Returns all tree nodes who follow matching rules with the point or interval specified.
---Traverses using breadth-first search, so nodes are sorted by depth.
---@param opts? org-roam.core.utils.tree.interval.FindOpts
---@return org-roam.core.utils.tree.IntervalTree[]
function M:find_all(opts)
    opts = opts or {}
    local nodes = {}

    local start = opts[1]
    local end_ = opts[2]
    local limit = opts.limit or math.huge

    ---@type org-roam.core.utils.tree.interval.MatchFn|nil
    local is_match
    if opts.match == "c" or opts.match == "contains" then
        ---@param node org-roam.core.utils.tree.IntervalTree
        ---@param i integer|nil
        ---@param j integer|nil
        ---@return boolean
        is_match = function(node, i, j)
            if i == nil then
                return false
            end

            return node:contains(i, j)
        end
    elseif opts.match == "i" or opts.match == "intersects" then
        ---@param node org-roam.core.utils.tree.IntervalTree
        ---@param i integer|nil
        ---@param j integer|nil
        ---@return boolean
        is_match = function(node, i, j)
            if i == nil then
                return false
            end

            return node:intersects(i, j)
        end
    elseif type(opts) == "function" then
        is_match = opts
    else
        is_match = function()
            return true
        end
    end

    local queue = Queue:new({ self })
    while not queue:is_empty() and #nodes < limit do
        ---@type org-roam.core.utils.tree.IntervalTree
        local cur = queue:pop_front()

        -- If we have more available that can intersect, continue,
        -- otherwise if the node is to the right of the right-most
        -- node then we have nothing to do here
        if start <= cur._max then
            -- Add current tree node if point/interval intersects
            if is_match(cur, start, end_) then
                table.insert(nodes, cur)
            end

            -- If we have a left node, check that the new node's
            -- start not to the right of the right-most node, and
            -- if not then add it
            if cur.left and start <= cur.left._max then
                queue:push_back(cur.left)
            end

            -- Always queue up the right node
            if cur.right then
                queue:push_back(cur.right)
            end
        end
    end

    return nodes
end

---Finds the first node that matches provided options.
---NOTE: Because of breadth-first search, this should be the shallowest node.
---
---See `find_all` for more details.
---@param opts? org-roam.core.utils.tree.interval.FindOpts
---@return org-roam.core.utils.tree.IntervalTree|nil
function M:find_first(opts)
    local nodes = self:find_all(vim.tbl_extend(
        "keep",
        { limit = 1 },
        opts or {}
    ))
    return nodes[1]
end

---Finds the last node that matches provided options.
---NOTE: Because of breadth-first search, this should be the deepest node.
---
---See `find_all` for more details.
---@param opts? org-roam.core.utils.tree.interval.FindOpts
---@return org-roam.core.utils.tree.IntervalTree|nil
function M:find_last(opts)
    local nodes = self:find_all(opts)

    -- NOTE: Because of breadth-first search, the last node should
    --       be the deepest (or tied as deepest) of all nodes
    return nodes[#nodes]
end

---Checks if this tree's interval contains entirely the specified point or interval.
---@param start integer #inclusive start of point (or interval if end included)
---@param end_ integer|nil #inclusive end of interval
---@return boolean
function M:contains(start, end_)
    end_ = end_ or start

    if self._start > start then
        return false
    end

    if self._end < end_ then
        return false
    end

    return true
end

---Checks if this tree's interval intersects with the specified point or interval.
---@param start integer #inclusive start of point (or interval if end included)
---@param end_ integer|nil #inclusive end of interval
---@return boolean
function M:intersects(start, end_)
    end_ = end_ or start

    if self._start > end_ then
        return false
    end

    if self._end < start then
        return false
    end

    return true
end

return M
