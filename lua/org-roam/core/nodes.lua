-------------------------------------------------------------------------------
-- NODES.LUA
--
-- Represents a collection of nodes tied to some org file.
-------------------------------------------------------------------------------

local Node  = require("org-roam.core.nodes.node")
local Range = require("org-roam.core.nodes.range")
local utils = require("org-roam.core.nodes.utils")

---@class org-roam.core.Nodes
---@field private __nodes table<org-roam.core.database.Id, org-roam.core.database.Node>
local M     = {}
M.__index   = M

---Creates a new collection of org-roam nodes.
---@param nodes org-roam.core.database.Node[]|nil
---@return org-roam.core.Nodes
function M:new(nodes)
    local instance = {}
    setmetatable(instance, M)

    instance.__nodes = {}
    for _, node in ipairs(nodes or {}) do
        instance.__nodes[node.id] = node
    end

    return instance
end

---Retrieves a node from the collection by its id.
---@param id org-roam.core.database.Id
---@return org-roam.core.database.Node
function M:get(id)
    return self.__nodes[id]
end

---Retrieves nodes from the collection by their id.
---@param ... org-roam.core.database.Id|org-roam.core.database.Id[]
---@return org-roam.core.database.Node[]
function M:get_many(...)
    local ids = vim.tbl_flatten({ ... })
    local nodes = {}

    for _, id in ipairs(ids) do
        local node = self:get(id)
        if node then
            table.insert(nodes, node)
        end
    end

    return nodes
end

---Returns nodes as a list.
---@return org-roam.core.database.Node[]
function M:as_list()
    return vim.tbl_values(self.__nodes)
end

---@param file OrgFile
---@return org-roam.core.Nodes
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
                title = headline:get_title(),
                aliases = utils.parse_property_value(headline:get_property("roam_aliases") or ""),
                tags = tags,
                level = headline:get_level(),
                linked = {},
            }))
        end
    end

    return self:new(nodes)
end

return M
