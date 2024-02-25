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

---@return integer
function M:depth()
    return self._depth
end

---@return string
function M:__tostring()
    return vim.inspect(self)
end

---@private
---Returns comparsing of tree intervals.
---
---* -1 means this tree has an interval that either starts before or ends earlier.
---* 0 means this tree has the exact same interval.
---* 1 means this tree has an interval that either starts after or ends later.
---
---@param tree org-roam.core.utils.tree.IntervalTree
---@return -1|0|1 cmp
function M:__cmp_tree_interval(tree)
    if self._start < tree._start then
        return -1
    end

    if self._start > tree._start then
        return 1
    end

    -- Starts are the same, so figure out
    -- based on the end instead
    if self._end < tree._end then
        return -1
    elseif self._end > tree._end then
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
        local cmp = cur:__cmp_tree_interval(tree)
        if cmp == 1 and cur.left then
            cur = cur.left
        elseif cmp == 1 then
            cur.left = tree
            cur = nil
        elseif cur.right then
            cur = cur.right
        else
            cur.right = tree
            cur = nil
        end
    end

    return tree
end

---Returns all tree nodes whose interval intersects with the point or interval specified.
---Traverses using breadth-first search, so nodes are sorted by depth.
---@param start integer #inclusive start of point (or interval if end provided)
---@param end_ integer|nil #inclusive end of interval
---@return org-roam.core.utils.tree.IntervalTree[]
function M:find_intersects(start, end_)
    local nodes = {}

    local queue = Queue:new({ self })
    while not queue:is_empty() do
        ---@type org-roam.core.utils.tree.IntervalTree
        local cur = queue:pop_front()

        -- If we have more available that can intersect, continue,
        -- otherwise if the node is to the right of the right-most
        -- node then we have nothing to do here
        if start <= cur._max then
            -- Add current tree node if point/interval intersects
            if cur:intersects(start, end_) then
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
