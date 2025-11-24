-------------------------------------------------------------------------------
-- FILE.LUA
--
-- Represents an org-roam file, containing the associated nodes and other data.
-------------------------------------------------------------------------------

-- Cannot serialie `math.huge`. Potentially could use `vim.v.numbermax`, but
-- this is a safer and more reliable guarantee of maximum size.
local MAX_NUMBER = 2 ^ 31

local KEYS = {
    DIR_TITLE = "TITLE",
    PROP_ALIASES = "ROAM_ALIASES",
    PROP_ID = "ID",
    PROP_ORIGIN = "ROAM_ORIGIN",
}

---@class org-roam.core.File
---@field filename string
---@field links org-roam.core.file.Link[]
---@field nodes table<string, org-roam.core.file.Node>
local M = {}
M.__index = M

---Creates a new org-roam file.
---@param opts {filename:string, links?:org-roam.core.file.Link[], nodes?:org-roam.core.file.Node[]}
---@return org-roam.core.File
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.filename = opts.filename
    instance.links = opts.links or {}
    instance.nodes = {}
    for _, node in ipairs(opts.nodes or {}) do
        instance.nodes[node.id] = node
    end

    return instance
end

---Retrieves a node from the file by its id.
---@param id string
---@return org-roam.core.file.Node
function M:get_node(id)
    return self.nodes[id]
end

---Retrieves nodes from the collection by their ids.
---@param ... string|string[]
---@return org-roam.core.file.Node[]
function M:get_nodes(...)
    local ids = vim.iter({ ... }):flatten():totable()
    local nodes = {}

    for _, id in ipairs(ids) do
        local node = self:get_node(id)
        if node then
            table.insert(nodes, node)
        end
    end

    return nodes
end

---Returns nodes as a list.
---@return org-roam.core.file.Node[]
function M:get_node_list()
    return vim.tbl_values(self.nodes)
end

---@param nodes org-roam.core.file.Node
---@return org-roam.core.utils.IntervalTree|nil
local function make_node_tree(nodes)
    if #nodes == 0 then
        return
    end

    ---@param node org-roam.core.file.Node
    return require("org-roam.core.utils.tree"):from_list(vim.tbl_map(function(node)
        return {
            node.range.start.offset,
            node.range.end_.offset,
            node,
        }
    end, nodes))
end

---@type {files:table<string, org-roam.core.File>, hashes:table<string, string>}
local CACHE = setmetatable({ files = {}, hashes = {} }, { __mode = "k" })

---@param file OrgFile
---@return org-roam.core.File
function M:from_org_file(file)
    local nodes = {}

    ---@param s string|string[]|nil
    ---@return string|nil
    local function trim(s)
        if type(s) == "string" then
            return vim.trim(s)
        elseif type(s) == "table" then
            return vim.trim(table.concat(s))
        end
    end

    -- Check if we have a cached value for this file specifically
    local key = vim.fn.sha256(table.concat(file.lines, "\n"))
    if CACHE.files[key] and CACHE.hashes[file.filename] == key then
        return CACHE.files[key]
    end

    -- Build up our file-level node
    -- Get the id and strip whitespace, which incldues \r on windows
    local id = trim(file:get_property(KEYS.PROP_ID))
    if id then
        local tags = file:get_filetags()
        table.sort(tags)

        local origin = trim(file:get_property(KEYS.PROP_ORIGIN))
        table.insert(
            nodes,
            require("org-roam.core.file.node"):new({
                id = id,
                origin = origin,
                range = require("org-roam.core.file.range"):new(
                    { row = 0, column = 0, offset = 0 },
                    { row = MAX_NUMBER, column = MAX_NUMBER, offset = MAX_NUMBER }
                ),
                file = file.filename,
                mtime = file.metadata.mtime,
                title = trim(file:get_directive(KEYS.DIR_TITLE)),
                aliases = require("org-roam.core.file.utils").parse_property_value(
                    trim(file:get_property(KEYS.PROP_ALIASES)) or ""
                ),
                tags = tags,
                level = 0,
                linked = {},
            })
        )
    end

    -- Build up our section-level nodes
    for _, headline in ipairs(file:get_headlines()) do
        -- Get the id and strip whitespace, which incldues \r on windows
        local id = trim(headline:get_property(KEYS.PROP_ID))
        if id then
            -- NOTE: By default, this will get filetags and respect tag inheritance
            --       for nested headlines. If this is turned off in orgmode, then
            --       this only returns tags for the headline itself. We're going
            --       to use this and let that be a decision the user makes.
            local tags = headline:get_tags()
            table.sort(tags)

            local origin = trim(headline:get_property(KEYS.PROP_ORIGIN))
            table.insert(
                nodes,
                require("org-roam.core.file.node"):new({
                    id = id,
                    origin = origin,
                    range = require("org-roam.core.file.range"):from_node(
                        assert(headline.headline:parent(), "headline missing parent")
                    ),
                    file = file.filename,
                    mtime = file.metadata.mtime,
                    title = headline:get_title(),
                    aliases = require("org-roam.core.file.utils").parse_property_value(
                        trim(headline:get_property(KEYS.PROP_ALIASES)) or ""
                    ),
                    tags = tags,
                    level = headline:get_level(),
                    linked = {},
                })
            )
        end
    end

    -- If we have no nodes, we're done and can return early to avoid processing links
    local node_tree = make_node_tree(nodes)
    if not node_tree then
        return M:new({ filename = file.filename })
    end

    -- Build links with full ranges and connect them to nodes
    local links = {}
    for _, link in ipairs(file:get_links()) do
        local id = trim(link.url:get_id())
        local range = link.range
        if id and range then
            -- Figure out the full range from the file and add the link to our list
            local roam_range = require("org-roam.core.file.range"):from_org_file_and_range(file, range)
            table.insert(
                links,
                require("org-roam.core.file.link"):new({
                    kind = "regular",
                    range = roam_range,
                    path = link.url:to_string(),
                    description = link.desc,
                })
            )

            -- Figure out the node that contains the link
            ---@type org-roam.core.file.Node|nil
            local node = node_tree:find_smallest_data({
                roam_range.start.offset,
                roam_range.end_.offset,
                match = "contains",
            })

            -- Update the node's data to contain the link position
            if node then
                if not node.linked[id] then
                    node.linked[id] = {}
                end

                ---@type org-roam.core.file.Position
                local pos = vim.deepcopy(roam_range.start)

                table.insert(node.linked[id], pos)
            end
        end
    end

    local roam_file = M:new({
        filename = file.filename,
        links = links,
        nodes = nodes,
    })

    -- Clear old file instance from cache
    local old_key = CACHE.hashes[file.filename]
    if old_key and CACHE.files[old_key] then
        CACHE.files[old_key] = nil
    end

    -- Update cache with new file instance
    CACHE.hashes[file.filename] = key
    CACHE.files[key] = roam_file

    return roam_file
end

return M
