-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Core database to keep track of org-roam nodes.
-------------------------------------------------------------------------------

local async = require("org-roam.core.utils.async")
local Iterator = require("org-roam.core.utils.iterator")
local io = require("org-roam.core.utils.io")
local Queue = require("org-roam.core.utils.queue")
local random = require("org-roam.core.utils.random")
local tbl_utils = require("org-roam.core.utils.table")

-- NOTE: This is a placeholder until we can make the database class generic
--       as ideally we have a specific type used for the node data across
--       all nodes. I don't expect this to be available for years, but the
--       tracking issue is here: https://github.com/LuaLS/lua-language-server/issues/1861
--
---@alias org-roam.core.database.Data any

---@alias org-roam.core.database.IndexName string

---@alias org-roam.core.database.Id string

---@alias org-roam.core.database.IdMap table<org-roam.core.database.Id, boolean>

---@alias org-roam.core.database.IndexKey
---| boolean
---| integer
---| string

---@alias org-roam.core.database.IndexKeys
---| org-roam.core.database.IndexKey
---| org-roam.core.database.IndexKey[]

---@alias org-roam.core.database.Indexer fun(data:org-roam.core.database.Data):(org-roam.core.database.IndexKeys|nil)

---@class org-roam.core.Database
---@field private __changed_tick integer #total number of changes made to the database (non-persistent)
---@field private __nodes table<org-roam.core.database.Id, org-roam.core.database.Data>
---@field private __outbound table<org-roam.core.database.Id, org-roam.core.database.IdMap> mapping of node -> node by id
---@field private __inbound table<org-roam.core.database.Id, org-roam.core.database.IdMap> mapping of node <- node by id
---@field private __indexers table<org-roam.core.database.Id, org-roam.core.database.Indexer> table of labels -> indexers to run when inserting or refreshing a node
---@field private __indexes table<org-roam.core.database.IndexName, table<org-roam.core.database.IndexKey, org-roam.core.database.IdMap>> mapping of some identifier to ids of associated nodes
local M = {}
M.__index = M

---Creates a new instance of the database.
---@return org-roam.core.Database
function M:new()
    local instance = {}
    setmetatable(instance, M)
    instance.__changed_tick = 0
    instance.__nodes = {}
    instance.__outbound = {}
    instance.__inbound = {}
    instance.__indexers = {}
    instance.__indexes = {}

    return instance
end

---Retrieves the tick representing how many changes have been made to the
---database since neovim started. Note that this does not persist to disk,
---meaning that it starts from 0 whenever neovim starts.
---@return integer
function M:changed_tick()
    return self.__changed_tick
end

---@private
---Increments changed tick within database.
function M:__update_tick()
    self.__changed_tick = self.__changed_tick + 1
end

---Synchronously loads database from disk.
---
---Note: cannot be called within fast callbacks.
---
---Accepts options to configure how to wait.
---
---* `time`: the milliseconds to wait for writing to finish.
---  Defaults to waiting forever.
---* `interval`: the millseconds between attempts to check that writing
---  has finished. Defaults to 200 milliseconds.
---@param path string where to find the database
---@param opts? {time?:integer,interval?:integer}
---@return string|nil err, org-roam.core.Database|nil db
function M:load_from_disk_sync(path, opts)
    opts = opts or {}

    local f = async.wrap(
        M.load_from_disk,
        {
            time = opts.time,
            interval = opts.interval,
            n = 2,
        }
    )

    return f(self, path)
end

---Asynchronously loads database from disk.
---@param path string where to find the database
---@param cb fun(err:string|nil, db:org-roam.core.Database|nil)
function M:load_from_disk(path, cb)
    io.read_file(path, function(err, data)
        if err then
            cb(err)
            return
        end

        assert(data, "impossible: data nil")

        -- Decode the data into Lua and set it as the nodes
        ---@type table|nil
        local __data = vim.mpack.decode(data)

        if not __data then
            cb("Failed to decode database")
            return
        end

        local db = M:new()

        ---@diagnostic disable-next-line:invisible
        db.__nodes = __data.nodes
        ---@diagnostic disable-next-line:invisible
        db.__inbound = __data.inbound
        ---@diagnostic disable-next-line:invisible
        db.__outbound = __data.outbound
        ---@diagnostic disable-next-line:invisible
        db.__indexes = __data.indexes

        cb(nil, db)
    end)
end

---Synchronously writes database to disk.
---
---Note: cannot be called within fast callbacks.
---
---Accepts options to configure how to wait.
---
---* `time`: the milliseconds to wait for writing to finish.
---  Defaults to waiting forever.
---* `interval`: the millseconds between attempts to check that writing
---  has finished. Defaults to 200 milliseconds.
---@param path string where to store the database
---@param opts? {time?:integer,interval?:integer}
---@return string|nil err
function M:write_to_disk_sync(path, opts)
    opts = opts or {}

    local f = async.wrap(
        M.write_to_disk,
        {
            time = opts.time,
            interval = opts.interval,
            n = 2,
        }
    )

    return f(self, path)
end

---Asynchronously writes database to disk.
---@param path string where to store the database
---@param cb fun(err:string|nil)
function M:write_to_disk(path, cb)
    ---@type string|nil
    local data = vim.mpack.encode({
        nodes = self.__nodes,
        inbound = self.__inbound,
        outbound = self.__outbound,
        indexes = self.__indexes,
    })

    if not data then
        cb("Failed to encode database")
        return
    end

    io.write_file(path, data, cb)
end

---Inserts non-false data into the database as a node with no edges.
---
---If an `id` is provided in options, will be used, otherwise a new id is
---generated.
---
---If `overwrite` is true and an id is provided that exists, the database will
---remove the old node before inserting the new one and restoring links,
---otherwise if `overwrite` is false then an error will be thrown if the node
---already exists.
---@param data org-roam.core.database.Data
---@param opts? {id?:org-roam.core.database.Id, overwrite?:boolean}
---@return org-roam.core.database.Id id #the id of the inserted node
function M:insert(data, opts)
    opts = opts or {}
    assert(data ~= nil, "Cannot insert nil value as data")

    ---@type org-roam.core.database.Id
    local id = opts.id

    -- If we aren't given an id with the node, create one
    if type(id) ~= "string" then
        id = random.uuid_v4()
    end

    -- If overwriting, ensure the node is removed first
    ---@type org-roam.core.database.Id[], org-roam.core.database.Id[]
    local link_ids, backlink_ids = {}, {}
    if opts.overwrite then
        link_ids = vim.tbl_keys(self:get_links(id))
        backlink_ids = vim.tbl_keys(self:get_backlinks(id))
        self:remove(id)
    end

    -- Check if the node exists, and fail if it does
    assert(not self:has(id), "inserting node " .. id .. ", but already exists")

    -- Perform the actual insertion of the node
    self.__nodes[id] = data

    -- Populate empty outbound only if it wasn't set
    -- from a link performed prior to being inserted
    if not self.__outbound[id] then
        self.__outbound[id] = {}
    end

    -- Populate empty inbound only if it wasn't set
    -- from a link performed prior to being inserted
    if not self.__inbound[id] then
        self.__inbound[id] = {}
    end

    -- Restore any links out of this node if they existed
    self:link(id, link_ids)

    -- Restore any links into this node if they existed
    for _, backlink_id in ipairs(backlink_ids) do
        self:link(backlink_id, id)
    end

    -- Do any pending indexing of the node
    self:reindex({
        nodes = { id }
    })

    -- Increment the changed tick counter
    self:__update_tick()

    return id
end

---Removes a node from the database by its id, disconnecting it from any other nodes.
---@param id org-roam.core.database.Id
---@return org-roam.core.database.Data|nil #the removed node's data, or nil if none with id found
function M:remove(id)
    -- Find every node pointing to this node, unlink it
    for backlink_id, _ in pairs(self:get_backlinks(id)) do
        self:unlink(backlink_id, id)
    end

    -- Unlink all outbound links from this node to anywhere else
    self:unlink(id)

    -- Remove existing indexes for node before deleting it
    self:reindex({
        nodes = { id },
        remove = true,
    })

    local node = self.__nodes[id]
    self.__nodes[id] = nil

    -- Increment the changed tick counter
    self:__update_tick()

    return node
end

---Returns true if there exists a node with the specified id.
---@param id org-roam.core.database.Id
---@return boolean
function M:has(id)
    return self:get(id) ~= nil
end

---Retrieves node from the database by its id.
---@param id org-roam.core.database.Id
---@return org-roam.core.database.Data|nil #the node's data, or nil if none with id found
function M:get(id)
    return self.__nodes[id]
end

---Retrieves one or more nodes from the database by their ids.
---@param ... org-roam.core.database.Id|org-roam.core.database.Id[] ids of nodes to retrieve
---@return table<org-roam.core.database.Id, org-roam.core.database.Data[]> #mapping of id -> node data
function M:get_many(...)
    local nodes = {}

    ---@type string[]
    local ids = vim.tbl_flatten({ ... })

    for _, id in ipairs(ids) do
        nodes[id] = self:get(id)
    end

    return nodes
end

---Returns a list of all ids of nodes within the database.
---
---If the database has a lot of nodes, this can be expensive and slow.
---Prefer using `iter_ids()` if you expect a large id set.
---@return org-roam.core.database.Id[]
function M:ids()
    return vim.tbl_keys(self.__nodes)
end

---Returns an iterator of all ids of nodes within the database.
---@return org-roam.core.utils.Iterator
function M:iter_ids()
    return Iterator:from_tbl_keys(self.__nodes)
end

---Creates a new index with the given name using the provided indexer.
---@param name org-roam.core.database.IndexName name associated with indexer
---@param indexer org-roam.core.database.Indexer function to perform indexing
---@return org-roam.core.Database #reference to updated database
function M:new_index(name, indexer)
    -- Add the indexer to our internal tracker
    self.__indexers[name] = indexer

    -- Increment the changed tick counter
    self:__update_tick()

    return self
end

---Returns true if an index exists with the given name.
---@param name org-roam.core.database.IndexName name associated with indexer
---@return boolean
function M:has_index(name)
    return self.__indexers[name] ~= nil
end

---Produces an iterator over the index keys tied to an index.
---
---For example, if you index nodes by a string field, this function will
---return an iterator over all of the string field's values.
---@param name org-roam.core.database.IndexName name of the index
---@return org-roam.core.utils.Iterator
function M:iter_index_keys(name)
    local index = self.__indexes[name] or {}
    return Iterator:from_tbl_keys(index)
end

---Retrieves ids of nodes from the database by some index.
---@param name org-roam.core.database.IndexName name of the index
---@param cmp org-roam.core.database.IndexKey|fun(key:org-roam.core.database.IndexKey):boolean
---@return org-roam.core.database.Id[] #ids of nodes that matched by index
function M:find_by_index(name, cmp)
    ---@type string[]
    local ids = {}

    local tbl = self.__indexes[name] or {}

    -- If cmp is a boolean/integer/string, we do a lookup,
    -- otherwise if it is a function we iterate through keys
    if type(cmp) == "boolean" or type(cmp) == "number" or type(cmp) == "string" then
        local map = tbl[cmp]
        if map ~= nil then
            ids = vim.tbl_keys(map)
        end
    elseif type(cmp) == "function" then
        for key, value in pairs(tbl) do
            if cmp(key) then
                for _, id in ipairs(vim.tbl_keys(value)) do
                    table.insert(ids, id)
                end
            end
        end
    end

    return ids
end

---Reindexes the database using the current indexers.
---
---Takes optional list of ids of nodes to index, otherwise re-indexes all nodes.
---Takes optional list of names of indexers to use, otherwise uses all indexers.
---Takes optional flag `remove`, which if true will not reindex but instead remove indexes for nodes.
---
---@param opts? {nodes?:org-roam.core.database.Id[], indexes?:org-roam.core.database.IndexName[], remove?:boolean}
---@return org-roam.core.Database #reference to updated database
function M:reindex(opts)
    opts = opts or {}
    local ids = opts.nodes or {}
    local indexes = opts.indexes or {}
    local should_remove = opts.remove == true

    if #ids == 0 then
        ids = vim.tbl_keys(self.__nodes)
    end

    if #indexes == 0 then
        indexes = vim.tbl_keys(self.__indexers)
    end

    for _, name in ipairs(indexes) do
        local indexer = assert(self.__indexers[name], "Invalid index: " .. name)

        -- Create an empty index if it doesn't exist yet
        if type(self.__indexes[name]) == "nil" then
            self.__indexes[name] = {}
        end

        -- For each node, we calculate values using the indexer
        for _, id in ipairs(ids) do
            local node = self:get(id)
            if type(node) ~= "nil" then
                local result = indexer(node)

                if type(result) == "number" then
                    ---@type number[]
                    result = { result }
                elseif type(result) == "string" then
                    ---@type string[]
                    result = { result }
                elseif type(result) == "boolean" then
                    ---@type boolean[]
                    result = { result }
                elseif type(result) ~= "table" then
                    ---@type string[]
                    result = {}
                end

                -- For each value, we cache a pointer to the node's id
                for _, value in ipairs(result) do
                    -- Protect against list with nil values
                    if type(value) ~= "nil" then
                        if type(self.__indexes[name][value]) == "nil" then
                            -- Create empty cache for value if doesn't exist yet
                            self.__indexes[name][value] = {}
                        end

                        -- Store the node's id in the lookup cache
                        if not should_remove then
                            self.__indexes[name][value][id] = true
                        else
                            self.__indexes[name][value][id] = nil
                        end
                    end
                end
            end
        end
    end

    -- Increment the changed tick counter
    self:__update_tick()

    return self
end

---@private
---Retrieves ids of nodes linked to by the node in inbound or outbound direction.
---@param opts {root:org-roam.core.database.Id, max_depth?:integer, direction:"inbound"|"outbound"}
---@return table<org-roam.core.database.Id, integer> #ids of found nodes mapped to the total steps away from specified node
function M:__get_links_in_direction(opts)
    local root_id = opts.root
    local max_depth = opts.max_depth
    local direction = opts.direction

    local nodes = {}

    if type(max_depth) ~= "number" then
        max_depth = 1
    end

    local edges
    if direction == "inbound" then
        edges = self.__inbound
    elseif direction == "outbound" then
        edges = self.__outbound
    else
        error("Invalid direction: " .. direction)
    end

    -- Populate initial list of node ids to traverse
    local ids = vim.tbl_keys(edges[root_id] or {})

    local step = 1
    while step <= max_depth do
        local step_ids = ids
        ids = {}

        for _, step_id in ipairs(step_ids) do
            -- Not visited node yet
            if type(nodes[step_id]) == "nil" then
                -- Store node and the current step
                nodes[step_id] = step

                -- Add all of the outbound edges of that node to the list
                -- to traverse in the next step
                for edge_id, _ in pairs(edges[step_id] or {}) do
                    table.insert(ids, edge_id)
                end
            end
        end

        step = step + 1
    end

    return nodes
end

---Retrieves ids of nodes linked to by the node with the specified id.
---@param id org-roam.core.database.Id
---@param opts? {max_depth?:integer} # max_depth indicates how many nodes away to look (default 1)
---@return table<org-roam.core.database.Id, integer> #ids of found nodes mapped to the total steps away from specified node
function M:get_links(id, opts)
    opts = opts or {}
    return self:__get_links_in_direction({ root = id, max_depth = opts.max_depth, direction = "outbound" })
end

---Retrieves ids of nodes that link to the node with the specified id.
---@param id org-roam.core.database.Id
---@param opts? {max_depth?:integer} # max_depth indicates how many nodes away to look (default 1)
---@return table<org-roam.core.database.Id, integer> #ids of found nodes mapped to the total steps away from specified node
function M:get_backlinks(id, opts)
    opts = opts or {}
    return self:__get_links_in_direction({ root = id, max_depth = opts.max_depth, direction = "inbound" })
end

---Creates outbound edges from node `id`. Only in the direction of node[id] -> node.
---@param id org-roam.core.database.Id #id of node
---@param ... org-roam.core.database.Id|org-roam.core.database.Id[] #ids of nodes to form edges (node[id] -> node)
function M:link(id, ...)
    -- Grab the outbound edges from `node`, which are cached by id
    local outbound = self.__outbound[id] or {}

    ---@type org-roam.core.database.Id[]
    local ids = vim.tbl_flatten({ ... })

    -- Ensure the new nodes are cached as an outbound edges
    for _, node in ipairs(ids) do
        outbound[node] = true

        -- For each outbound, we also want to cache as inbound for the nodes
        local inbound = self.__inbound[node] or {}
        inbound[id] = true
        self.__inbound[node] = inbound
    end

    -- Update the pointer
    self.__outbound[id] = outbound

    -- Increment the changed tick counter
    self:__update_tick()
end

---Removes outbound edges from node `id`.
---@param id org-roam.core.database.Id id of node
---@param ... org-roam.core.database.Id|org-roam.core.database.Id[] # ids of nodes to remove edges (node[id] -> node); if none provided, all outbound edges removed
---@return org-roam.core.database.Id[] #list of ids of nodes where an outbound edge was removed
function M:unlink(id, ...)
    -- Grab the outbound edges, which are cached by id
    local outbound = self.__outbound[id] or {}

    -- Build the list of nodes we will be removing from the edges list
    ---@type org-roam.core.database.Id[]
    local nodes = vim.tbl_flatten({ ... })
    if #nodes == 0 then
        nodes = vim.tbl_keys(outbound)
    end

    -- Do actual removal
    local ids = {}
    for _, node in ipairs(nodes) do
        local had_edge = false
        if type(outbound[node]) ~= "nil" then
            had_edge = true
        end

        outbound[node] = nil

        -- For each outbound, we also want to remove the cached inbound equivalent
        local inbound = self.__inbound[node]
        if type(inbound) ~= "nil" then
            had_edge = true
            inbound[id] = nil
            self.__inbound[node] = inbound
        end

        if had_edge then
            table.insert(ids, node)
        end
    end

    -- Update the pointer
    self.__outbound[id] = outbound

    -- Increment the changed tick counter
    self:__update_tick()

    return ids
end

---@class org-roam.core.database.Database.IterNodesOpts
---@field start_node_id org-roam.core.database.Id
---@field max_nodes? integer
---@field max_distance? integer
---@field filter? fun(id:org-roam.core.database.Id, distance:integer):boolean

---Traverses across nodes in the database, returning an iterator of tuples
---comprised of traversed node ids and their distance from the starting
---node.
---@param opts org-roam.core.database.Database.IterNodesOpts
---@return org-roam.core.utils.Iterator
function M:iter_nodes(opts)
    assert(opts and opts.start_node_id, "Missing starting node id")

    local MAX_NODES = opts.max_nodes or math.huge
    local MAX_DISTANCE = opts.max_distance or math.huge
    local filter = opts.filter or function() return true end

    ---@type table<org-roam.core.database.Id, boolean>
    local visited = {}
    local queue = Queue:new({ { opts.start_node_id, 0 } })
    local count = 0

    return Iterator:new(function()
        -- NOTE: While we have a loop, this should only run until
        --       we get a node id and distance to return as the
        --       next iterator value, or the queue becomes empty.
        while count < MAX_NODES and not queue:is_empty() do
            ---@type org-roam.core.database.Id, integer
            local id, distance = tbl_utils.unpack(queue:pop_front())

            if distance <= MAX_DISTANCE and not visited[id] and filter(id, distance) then
                visited[id] = true
                count = count + 1

                if distance + 1 <= MAX_DISTANCE then
                    for link_id, _ in pairs(self:get_links(id)) do
                        queue:push_back({ link_id, distance + 1 })
                    end
                end

                return id, distance
            end
        end
    end)
end

---Finds paths using BFS between the starting and ending nodes, returning
---an iterator over lists of node ids representing complete paths from start
---to end.
---@param start_node_id org-roam.core.database.Id
---@param end_node_id org-roam.core.database.Id
---@param opts? {max_distance?:integer}
---@return org-roam.core.utils.Iterator
function M:iter_paths(start_node_id, end_node_id, opts)
    opts = opts or {}

    local MAX_DISTANCE = opts.max_distance or math.huge

    -- Establish a queue of paths that we continue to try to build out
    -- until we find the end node.
    --
    -- Format of queue items is a map of id -> position and "last" -> id
    -- to keep track of the last id in the path thus far. We do this so
    -- we can lookup cycles by key before they occur.
    local queue = Queue:new({ { [start_node_id] = 1, last = start_node_id } })

    return Iterator:new(function()
        -- NOTE: While we have a loop, this should only run until we get a
        --       path to return as the next iterator value, or the queue becomes
        --       empty.
        while not queue:is_empty() do
            ---@type { last:string, [string]:integer }
            local path = queue:pop_front()
            local last_id = path.last ---@cast last_id string
            local idx = path[last_id]

            -- Queue up outbound links as future paths to explore
            if idx <= MAX_DISTANCE then
                for id, _ in pairs(self:get_links(last_id)) do
                    -- Skip any outgoing edge that results in a cycle
                    if not path[id] then
                        -- Make a new path that includes the outbound link
                        local tbl = vim.deepcopy(path)
                        tbl[id] = idx + 1
                        tbl.last = id
                        queue:push_back(tbl)
                    end
                end
            end

            -- Check if this path has found the end and if so return it
            if last_id == end_node_id then
                path.last = nil

                -- Reverse id -> i to be i -> id
                local results = {}
                for id, i in pairs(path) do
                    results[i] = id
                end

                return results
            end
        end
    end)
end

---Finds a path using BFS between the starting and ending nodes, returning
---the first path found as a list of node ids from start to end, or nil
---if no path found.
---@param start_node_id org-roam.core.database.Id
---@param end_node_id org-roam.core.database.Id
---@param opts? {max_distance?:integer}
---@return org-roam.core.database.Id[]|nil
function M:find_path(start_node_id, end_node_id, opts)
    return self:iter_paths(start_node_id, end_node_id, opts):next()
end

return M
