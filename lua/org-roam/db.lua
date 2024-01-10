local utils = require("org-roam.utils")

-------------------------------------------------------------------------------
-- DB.LUA
--
-- Core database to keep track of org-roam nodes.
-------------------------------------------------------------------------------

---@class org-roam.Node
---@field title string the title of the org-roam note.
---@field file string the file name where the note is stored.
---@field id string the unique identifier for the note.
---@field level number the heading level of the note in the org-mode file.
---@field tags string[] a list of tags associated with the note.
---@field linked org-roam.Node[] a list of linked notes (references) within the note.

---@alias org-roam.database.Node any

---@class org-roam.Database
---@field private __nodes table<string, org-roam.database.Node> collection of nodes indexed by id
---@field private __outbound table<string, table<string, boolean>> mapping of node -> node by id
---@field private __inbound table<string, table<string, boolean>> mapping of node <- node by id
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

    return instance
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
    db.__nodes = assert(vim.mpack.decode(data), "Failed to decode database")

    return db
end

---Writes database to disk. Will fail with an assertion error if something goes wrong.
---@param path string where to store the database
function M:write_to_disk(path)
    ---@type string
    local data = assert(vim.mpack.encode(self.__nodes), "Failed to encode database")

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

    return id
end

---Removes a node from the database by its id, disconnecting it from any other nodes.
---@param id string
---@return org-roam.database.Node|nil #the removed node, or nil if none with id found
function M:remove(id)
    -- Disconnect the node from all associated nodes in both directions
    -- TODO: This is not working fully, so we need to figure out what's wrong!
    local backlink_ids = self:get_backlinks(id)
    for _, backlink_id in ipairs(backlink_ids) do
        self:unlink(backlink_id, id)
    end
    self:unlink(id) -- Remove all outbound links from this node to anywhere else

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
