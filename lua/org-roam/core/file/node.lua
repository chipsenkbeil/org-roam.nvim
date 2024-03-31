-------------------------------------------------------------------------------
-- NODE.LUA
--
-- Abstraction for an org-roam node.
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- DETAILS ABOUT ORG-ROAM NODES
-------------------------------------------------------------------------------
-- Nodes have an id
--
-- :PROPERTIES:
-- :ID: <ID>
-- :END:
--
-- This can be a file node or headline.
--
-- Other properties (all optional)
-- :ROAM_EXCLUDE: t (if set to non-nil value, does a thing)
-- :ROAM_ALIASES: <text>
-- :ROAM_REFS: <ref>
--
-- Format for refs is one of
--
-- https://example.com (some website)
-- @thrun2005probabilistic (unique citation key)
-- [cite:@thrun2005probabilistic] (org-cite)
-- cite:thrun2005probabilistic (org-ref)
--
-- Note that text for aliases and refs is space-delimited, but supports
-- double-quotes to group spaced items together.
--
-- :ROAM_ALIASES: "one item" "two item" three four
-- :ROAM_REFS: @my_ref https://example.com/
--
-------------------------------------------------------------------------------
-- DETAILS ABOUT ORG-ROAM NODE PROPERTIES
-------------------------------------------------------------------------------
--
-- * Cached org-mode properties *
--
--     - outline level
--     - todo state (unsupported)
--     - priority (unsupported)
--     - scheduled (unsupported)
--     - deadline (unsupported)
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

---@class org-roam.core.file.Node
---@field id string #unique id associated with the node
---@field range org-roam.core.file.Range #range representing full node
---@field file string #path to file where node is located
---@field mtime integer #last time the node's file was modified (nanoseconds)
---@field title string #title of node, defaulting to file name
---@field aliases string[] #alternative titles associated with node
---@field tags string[] #tags tied to node
---@field level integer #heading level (0 means top-level)
---@field linked table<string, org-roam.core.file.Position[]> #ids of nodes referenced by this node, mapped to positions of the links
local M = {}
M.__index = M

---@class org-roam.core.file.Node.NewOpts
---@field id string
---@field range org-roam.core.file.Range
---@field file string
---@field mtime integer
---@field title? string
---@field aliases? string[]
---@field tags? string[]
---@field level? integer (0 means top-level)
---@field linked? table<string, {[1]:integer, [2]:integer}[]>

---Creates a new node.
---@param opts org-roam.core.file.Node.NewOpts
---@return org-roam.core.file.Node
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.id = opts.id
    instance.range = opts.range
    instance.file = opts.file
    instance.mtime = opts.mtime
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

---Computes a sha256 hash representing the node.
---@return string
function M:hash()
    local linked_keys = vim.tbl_keys(self.linked)
    table.sort(linked_keys)

    return vim.fn.sha256(table.concat({
        self.id,
        string.format("%s%s", self.range.start.offset, self.range.end_.offset),
        self.file,
        self.title,
        table.concat(self.aliases, ","),
        table.concat(self.tags, ","),
        tostring(self.level),
        vim.tbl_map(function(key)
            ---@param loc org-roam.core.file.Position
            return table.concat(vim.tbl_map(function(loc)
                return loc.offset
            end, self.linked[key]), ",")
        end, linked_keys),
    }))
end

return M
