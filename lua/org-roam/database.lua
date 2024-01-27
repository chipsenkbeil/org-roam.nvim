local utils = require("org-roam.utils")

-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Core database to keep track of org-roam nodes.
-------------------------------------------------------------------------------

-- NOTE: This is a placeholder until we can make the database class generic
--       as ideally we have a specific type used for the node data across
--       all nodes. I don't expect this to be available for years, but the
--       tracking issue is here: https://github.com/LuaLS/lua-language-server/issues/1861
--
---@alias org-roam.database.Node any

---@alias org-roam.database.IndexName string

---@alias org-roam.database.NodeId string

---@alias org-roam.database.NodeIdMap table<org-roam.database.NodeId, boolean>

---@alias org-roam.database.IndexKey
---| boolean
---| integer
---| string

---@alias org-roam.database.IndexKeys
---| org-roam.database.IndexKey
---| org-roam.database.IndexKey[]

---@alias org-roam.database.Indexer fun(node:org-roam.database.Node):org-roam.database.IndexKeys

---@class org-roam.database.Database
---@field private __nodes table<org-roam.database.NodeId, org-roam.database.Node>
---@field private __outbound table<org-roam.database.NodeId, org-roam.database.NodeIdMap> mapping of node -> node by id
---@field private __inbound table<org-roam.database.NodeId, org-roam.database.NodeIdMap> mapping of node <- node by id
---@field private __indexers table<org-roam.database.NodeId, org-roam.database.Indexer> table of labels -> indexers to run when inserting or refreshing a node
---@field private __indexes table<org-roam.database.IndexName, table<org-roam.database.IndexKey, org-roam.database.NodeIdMap>> mapping of some identifier to ids of associated nodes
local M = {}
M.__index = M

---Creates a new instance of the database.
---@return org-roam.database.Database
function M:new()
    local instance = {}
    setmetatable(instance, M)
    instance.__nodes = {}
    instance.__outbound = {}
    instance.__inbound = {}
    instance.__indexers = {}
    instance.__indexes = {}

    return instance
end

---Creates a new index with the given name using the provided indexer.
---@param name org-roam.database.IndexName name associated with indexer
---@param indexer org-roam.database.Indexer function to perform indexing
---@return org-roam.database.Database #reference to updated database
function M:new_index(name, indexer)
    -- Add the indexer to our internal tracker
    self.__indexers[name] = indexer

    return self
end

---Loads database from disk. Will fail with an assertion error if something goes wrong.
---@param path string where to find the database
---@return org-roam.database.Database
function M:load_from_disk(path)
    local db = M:new()

    -- Load the file, read the data, and close the file
    local handle = assert(io.open(path, "rb"), "Failed to open " .. path)
    local data = assert(handle:read("*a"), "Failed to read from " .. path)
    handle:close()

    -- Decode the data into Lua and set it as the nodes
    local __data = assert(vim.mpack.decode(data), "Failed to decode database")
    db.__nodes = __data.nodes
    db.__inbound = __data.inbound
    db.__outbound = __data.outbound
    db.__indexes = __data.indexes

    return db
end

---Writes database to disk. Will fail with an assertion error if something goes wrong.
---@param path string where to store the database
function M:write_to_disk(path)
    ---@type string
    local data = assert(vim.mpack.encode({
        nodes = self.__nodes,
        inbound = self.__inbound,
        outbound = self.__outbound,
        indexes = self.__indexes,
    }), "Failed to encode database")

    -- Open the file to create/overwite, write the data, and close the file
    local handle = assert(io.open(path, "wb"), "Failed to open " .. path)
    assert(handle:write(data), "Failed to write to " .. path)
    handle:close()
end

---Inserts non-false data into the database as a node with no edges.
---If an id is provided in options, will be used, otherwise a new id is generated.
---@param node org-roam.database.Node
---@param opts? {id?:org-roam.database.NodeId}
---@return org-roam.database.NodeId id #the id of the inserted node
function M:insert(node, opts)
    assert(node ~= nil, "Cannot insert nil value as node")

    opts = opts or {}

    ---@type org-roam.database.NodeId
    local id = opts.id

    -- If we aren't given an id with the node, create one
    if type(id) ~= "string" then
        id = utils.uuid_v4()
    end

    -- Perform the actual insertion of the node
    self.__nodes[id] = node
    self.__outbound[id] = {}
    self.__inbound[id] = {}

    -- Do any pending indexing of the node
    self:reindex({
        nodes = { id }
    })

    return id
end

---Removes a node from the database by its id, disconnecting it from any other nodes.
---@param id org-roam.database.NodeId
---@return org-roam.database.Node|nil #the removed node, or nil if none with id found
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

    return node
end

---Retrieves node from the database by its id.
---@param id org-roam.database.NodeId
---@return org-roam.database.Node|nil #the node, or nil if none with id found
function M:get(id)
    return self.__nodes[id]
end

---Retrieves one or more nodes from the database by their ids.
---@param ... org-roam.database.NodeId ids of nodes to retrieve
---@return table<org-roam.database.NodeId, org-roam.database.Node[]> #mapping of id -> node
function M:get_many(...)
    local nodes = {}

    for _, id in ipairs({ ... }) do
        nodes[id] = self:get(id)
    end

    return nodes
end

---Retrieves ids of nodes from the database by some index.
---@param name org-roam.database.IndexName name of the index
---@param cmp org-roam.database.IndexKey|fun(key:org-roam.database.IndexKey):boolean
---@return org-roam.database.NodeId[] #ids of nodes that matched by index
function M:find_by_index(name, cmp)
    ---@type string[]
    local ids = {}

    local tbl = self.__indexes[name]

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
---@param opts? {nodes?:org-roam.database.NodeId[], indexes?:org-roam.database.IndexName[], remove?:boolean}
---@return org-roam.database.Database #reference to updated database
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

    return self
end

---@private
---Retrieves ids of nodes linked to by the node in inbound or outbound direction.
---@param opts {root:org-roam.database.NodeId, max_depth?:integer, direction:"inbound"|"outbound"}
---@return table<org-roam.database.NodeId, integer> #ids of found nodes mapped to the total steps away from specified node
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
    local ids = vim.tbl_keys(edges[root_id])

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
                for edge_id, _ in pairs(edges[step_id]) do
                    table.insert(ids, edge_id)
                end
            end
        end

        step = step + 1
    end

    return nodes
end

---Retrieves ids of nodes linked to by the node with the specified id.
---@param id org-roam.database.NodeId
---@param opts? {max_depth?:integer} # max_depth indicates how many nodes away to look (default 1)
---@return table<org-roam.database.NodeId, integer> #ids of found nodes mapped to the total steps away from specified node
function M:get_links(id, opts)
    opts = opts or {}
    return self:__get_links_in_direction({ root = id, max_depth = opts.max_depth, direction = "outbound" })
end

---Retrieves ids of nodes that link to the node with the specified id.
---@param id org-roam.database.NodeId
---@param opts? {max_depth?:integer} # max_depth indicates how many nodes away to look (default 1)
---@return table<org-roam.database.NodeId, integer> #ids of found nodes mapped to the total steps away from specified node
function M:get_backlinks(id, opts)
    opts = opts or {}
    return self:__get_links_in_direction({ root = id, max_depth = opts.max_depth, direction = "inbound" })
end

---Creates outbound edges from node `id`. Only in the direction of node[id] -> node.
---@param id org-roam.database.NodeId id of node
---@param ... org-roam.database.NodeId ids of nodes to form edges (node[id] -> node)
function M:link(id, ...)
    -- Grab the outbound edges from `node`, which are cached by id
    local outbound = self.__outbound[id] or {}

    -- Ensure the new nodes are cached as an outbound edges
    for _, node in ipairs({ ... }) do
        outbound[node] = true

        -- For each outbound, we also want to cache as inbound for the nodes
        local inbound = self.__inbound[node] or {}
        inbound[id] = true
        self.__inbound[node] = inbound
    end

    -- Update the pointer
    self.__outbound[id] = outbound
end

---Removes outbound edges from node `id`.
---@param id org-roam.database.NodeId id of node
---@param ... org-roam.database.NodeId ids of nodes to remove edges (node[id] -> node); if none provided, all outbound edges removed
---@return org-roam.database.NodeId[] #list of ids of nodes where an outbound edge was removed
function M:unlink(id, ...)
    -- Grab the outbound edges, which are cached by id
    local outbound = self.__outbound[id] or {}

    -- Build the list of nodes we will be removing from the edges list
    local nodes = { ... }
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

    return ids
end

---@class org-roam.database.Database.TraverseOpts
---@field depth? integer the maximum depth of traversal. 0 means to stop at the root. 1 means ot stop at the immediate connections.
---@field destination? org-roam.database.NodeId id of the node which, once reached, will stop traversing. Paths are built up internally such that only nodes between the root and destination will be returned.
---@field filter? fun(id:org-roam.database.NodeId, depth:integer):boolean function that takes in nodes as they are traversed, returning false if they should be ignored, true if they should be kept.

---Traverses across nodes in the database.
---@param root org-roam.database.NodeId id of the root/starting node
---@param opts org-roam.database.Database.TraverseOpts
---@return {[1]: org-roam.database.NodeId, [2]: integer}[]
function M:traverse(root, opts)
    assert(opts.depth ~= nil
        or opts.destination ~= nil
        or opts.filter ~= nil, "Missing traversal option")

    ---@type {[1]: org-roam.database.NodeId, [2]: integer}[]
    local results = { { root, 0 } }
    local i = 1 -- Keep track of which result we are traversing

    while i <= #results do
        local skip = false
        local id = results[i][1]
        local depth = results[i][2]

        -- Once we reach the desired depth, we don't traverse anymore
        if opts.depth and depth >= opts.depth then
            skip = true
        end

        -- Otherwise,

        local next = {}
        for _, id in ipairs(queue) do
            local skip = false

            -- Check if we have found our node
            if opts.destination and opts.destination == id then
                break
            end

            -- Check if we want to traverse this node
            if opts.filter and not opts.filter(id, depth) then
                skip = true
            end

            -- At this stage, we have visited the node, so add it,
            -- check if it is our destination, and if not get
            -- the outbound links to traverse next
            if not skip then
                ---@type org-roam.database.NodeId[]
                local links = vim.tbl_key(self:get_links(id))
            end
        end
    end

    return results
end

return M
