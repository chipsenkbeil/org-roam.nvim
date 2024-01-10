local utils = require("org-roam.utils")

-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Core database to keep track of org-roam nodes.
-------------------------------------------------------------------------------

---@alias org-roam.database.Node any

---@alias org-roam.database.Indexer
---| fun(node:org-roam.database.Node):any given a node, returns a value or multiple values that can be used to retrieve it

---@class org-roam.Database
---@field private __nodes table<string, org-roam.database.Node> collection of nodes indexed by id
---@field private __outbound table<string, table<string, boolean>> mapping of node -> node by id
---@field private __inbound table<string, table<string, boolean>> mapping of node <- node by id
---@field private __indexers table<string, org-roam.database.Indexer> table of labels -> indexers to run when inserting or refreshing a node
---@field private __indexes table<string, table<string, table<string, boolean>>> mapping of some identifier to ids of associated nodes
local M = {}
M.__index = M

---Creates a new instance of the database.
---@return org-roam.Database
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
---@param name string name associated with indexer
---@param indexer org-roam.database.Indexer function to perform indexing
---@return org-roam.Database #reference to updated database
function M:new_index(name, indexer)
    -- Add the indexer to our internal tracker
    self.__indexers[name] = indexer

    return self
end

---Loads database from disk. Will fail with an assertion error if something goes wrong.
---@param path string where to find the database
---@return org-roam.Database
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
---@param opts? {id?:string}
---@return string id #the id of the inserted node
function M:insert(node, opts)
    assert(node ~= nil, "Cannot insert nil value as node")

    opts = opts or {}
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
---@param id string
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
---@param id string
---@return org-roam.database.Node|nil #the node, or nil if none with id found
function M:get(id)
    return self.__nodes[id]
end

---Retrieves one or more nodes from the database by their ids.
---@param ... string ids of nodes to retrieve
---@return table<string, org-roam.database.Node[]> #mapping of id -> node
function M:get_many(...)
    local nodes = {}

    for _, id in ipairs({ ... }) do
        nodes[id] = self:get(id)
    end

    return nodes
end

---Retrieves ids of nodes from the database by some index.
---@param name string name of the index
---@param cmp boolean|integer|string|fun(value:boolean|integer|string):boolean
---@return string[] #ids of nodes that matched by index
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
---@param opts? {nodes?:string[], indexes?:string[], remove?:boolean}
---@return org-roam.Database #reference to updated database
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
---@param opts {root:string, max_depth?:integer, direction:"inbound"|"outbound"}
---@return table<string, integer> #ids of found nodes mapped to the total steps away from specified node
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
---@param id string
---@param opts? {max_depth?:integer} # max_depth indicates how many nodes away to look (default 1)
---@return table<string, integer> #ids of found nodes mapped to the total steps away from specified node
function M:get_links(id, opts)
    opts = opts or {}
    return self:__get_links_in_direction({ root = id, max_depth = opts.max_depth, direction = "outbound" })
end

---Retrieves ids of nodes that link to the node with the specified id.
---@param id string
---@param opts? {max_depth?:integer} # max_depth indicates how many nodes away to look (default 1)
---@return table<string, integer> #ids of found nodes mapped to the total steps away from specified node
function M:get_backlinks(id, opts)
    opts = opts or {}
    return self:__get_links_in_direction({ root = id, max_depth = opts.max_depth, direction = "inbound" })
end

---Creates outbound edges from node `id`. Only in the direction of node[id] -> node.
---@param id string id of node
---@param ... string ids of nodes to form edges (node[id] -> node)
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
---@param id string id of node
---@param ... string ids of nodes to remove edges (node[id] -> node); if none provided, all outbound edges removed
---@return string[] #list of ids of nodes where an outbound edge was removed
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

return M
