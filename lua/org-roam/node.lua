-------------------------------------------------------------------------------
-- NODE.LUA
--
-- Abstraction for an org-roam node.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- DETAILS ABOUT ORG-ROAM NODES
-------------------------------------------------------------------------------
--
-- * Cached org-mode properties *
--
--     - outline level
--     - todo state
--     - priority
--     - scheduled
--     - deadline
--     - tags
--
-- * Custom org-roam properties *
--
--     - Each node has a single title. For file nodes, this is specified with
--       the '#+title' property for the file. For headline nodes, this is the
--       main text.
--
--     - Nodes can also have multiple aliases. Aliases allow searching for
--       nodes via an alternative name. For example, one may want to assign
--       a well-known acronym (AI) to a node titled "Artificial Intelligence".
--
--     - Tags for top-level (file) nodes are pulled from the variable
--       org-file-tags, which is set by the #+filetags keyword, as well as
--       other tags the file may have inherited. Tags for headline level nodes
--       are regular Org tags. Note that the #+filetags keyword results in tags
--       being inherited by headers within the file. This makes it impossible
--       for selective tag inheritance: i.e. either tag inheritance is turned
--       off, or all headline nodes will inherit the tags from the file node.
--       This is a design compromise of Org-roam.
--
-------------------------------------------------------------------------------

---@class org-roam.node.Node
---@field id string
---@field file string
---@field title string
---@field aliases string[]
---@field tags string[]
---@field level integer (0 means top-level)
---@field linked org-roam.node.Node[]
local M = {}
M.__index = M

---@class org-roam.node.Node.NewOpts
---@field id string
---@field file string
---@field title? string
---@field aliases? string[]
---@field tags? string[]
---@field level? integer (0 means top-level)
---@field linked? string[]

---Creates a new node.
---@param opts org-roam.node.Node.NewOpts
---@return org-roam.node.Node
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.id = opts.id
    instance.file = opts.file
    instance.title = opts.title or (function()
        local filename = vim.fs.basename(opts.file)

        -- Remove .org extension if it exists
        if vim.endswith(filename, ".org") then
            filename = string.sub(filename, 1, string.len(filename) - 4)
        end

        return filename
    end)()
    instance.aliases = opts.aliases or {}
    instance.tags = opts.tags or {}
    instance.level = opts.level or 0
    instance.linked = opts.linked or {}

    return instance
end

---Returns whether or not this node is considered a file node.
---@return boolean
function M:is_file_node()
    return self.level == 0
end

---Returns whether or not this node is considered a headline node.
---@return boolean
function M:is_headline_node()
    return self.level ~= 0
end

return M
