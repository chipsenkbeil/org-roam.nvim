-------------------------------------------------------------------------------
-- FILE.LUA
--
-- Represents an org-roam file, containing the associated nodes and other data.
-------------------------------------------------------------------------------

local IntervalTree = require("org-roam.core.utils.tree")
local Link         = require("org-roam.core.file.link")
local Node         = require("org-roam.core.file.node")
local Range        = require("org-roam.core.file.range")
local utils        = require("org-roam.core.file.utils")

---@class org-roam.core.File
---@field filename string
---@field links org-roam.core.file.Link[]
---@field nodes table<string, org-roam.core.file.Node>
local M            = {}
M.__index          = M

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
    local ids = vim.tbl_flatten({ ... })
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
function M:get_nodes_list()
    return vim.tbl_values(self.nodes)
end

---@param nodes org-roam.core.file.Node
---@return org-roam.core.utils.IntervalTree|nil
local function make_node_tree(nodes)
    if #nodes == 0 then
        return
    end

    ---@param node org-roam.core.file.Node
    return IntervalTree:from_list(vim.tbl_map(function(node)
        return {
            node.range.start.offset,
            node.range.end_.offset,
            node,
        }
    end, nodes))
end

---@param file OrgFile
---@return org-roam.core.File
function M:from_org_file(file)
    local nodes = {}

    -- Build up our file-level node
    local id = file:get_property("id")
    if id then
        table.insert(nodes, Node:new({
            id = id,
            range = Range:new(
                { row = 0, column = 0, offset = 0 },
                { row = math.huge, column = math.huge, offset = math.huge }
            ),
            file = file.filename,
            mtime = file.metadata.mtime,
            title = file:get_directive_property("title"),
            aliases = utils.parse_property_value(file:get_property("roam_aliases") or ""),
            tags = file:get_filetags(),
            level = 0,
            linked = {},
        }))
    end

    -- Build up our section-level nodes
    for _, headline in ipairs(file:get_headlines()) do
        local id = headline:get_property("id")
        if id then
            -- NOTE: By default, this will get filetags and respect tag inheritance
            --       for nested headlines. If this is turned off in orgmode, then
            --       this only returns tags for the headline itself. We're going
            --       to use this and let that be a decision the user makes.
            local tags = headline:get_tags()
            table.sort(tags)

            table.insert(nodes, Node:new({
                id = id,
                range = Range:from_node(headline.headline:parent()),
                file = file.filename,
                mtime = file.metadata.mtime,
                title = headline:get_title(),
                aliases = utils.parse_property_value(headline:get_property("roam_aliases") or ""),
                tags = tags,
                level = headline:get_level(),
                linked = {},
            }))
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
        local id = link.url:get_id()
        local range = link.range
        if id and range then
            -- Figure out the full range from the file and add the link to our list
            local roam_range = Range:from_org_file_and_range(file, range)
            table.insert(links, Link:new({
                kind = "regular",
                range = roam_range,
                path = link.url:to_string(),
                description = link.desc,
            }))

            -- Figure out the node that contains the link
            ---@type org-roam.core.file.Node|nil
            local node = node_tree:find_last_data({
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

    return M:new({
        filename = file.filename,
        links = links,
        nodes = nodes,
    })
end

return M
