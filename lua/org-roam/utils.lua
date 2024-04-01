-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- High-level utility functions leveraged by org-roam.
-------------------------------------------------------------------------------

local File = require("org-roam.core.file")
local IntervalTree = require("org-roam.core.utils.tree")
local OrgFile = require("orgmode.files.file")

---@class (exact) org-roam.utils.BufferCache
---@field file org-roam.core.File
---@field link_tree org-roam.core.utils.IntervalTree|nil
---@field node_tree org-roam.core.utils.IntervalTree|nil
---@field tick integer

---Internal cache of buffer -> cache of node ids used to look up
---nodes within buffers.
---@type table<integer, org-roam.utils.BufferCache>
local CACHE = {}

local M = {}

---@param bufnr integer
---@return org-roam.utils.BufferCache
local function get_buffer_cache(bufnr)
    local cache = CACHE[bufnr]
    ---@type integer
    local tick = vim.b[bufnr].changedtick

    local is_dirty = tick ~= (cache and cache.tick)

    -- If the buffer has changed or we had no cache, update
    if is_dirty or not cache then
        -- TODO: Can we just index by filename in the database
        --       and `find_by_index` to get nodes connected to the
        --       file represented by the buffer to build this
        --       up versus re-parsing the buffer?
        ---@type OrgFile
        local orgfile = OrgFile:new({
            filename = vim.api.nvim_buf_get_name(bufnr),
            lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        })

        -- Trigger parsing of content, which should use string treesitter parser
        orgfile:parse()

        -- Convert file into roam version
        local file = File:from_org_file(orgfile)

        ---@type org-roam.core.utils.IntervalTree|nil
        local node_tree
        if not vim.tbl_isempty(file.nodes) then
            node_tree = IntervalTree:from_list(
            ---@param node org-roam.core.file.Node
                vim.tbl_map(function(node)
                    return {
                        node.range.start.offset,
                        node.range.end_.offset,
                        node,
                    }
                end, vim.tbl_values(file.nodes))
            )
        end

        ---@type org-roam.core.utils.IntervalTree|nil
        local link_tree
        if #file.links > 0 then
            link_tree = IntervalTree:from_list(
            ---@param link org-roam.core.file.Link
                vim.tbl_map(function(link)
                    return {
                        link.range.start.offset,
                        link.range.end_.offset,
                        link,
                    }
                end, file.links)
            )
        end

        -- Update cache pointer to reflect the current state
        CACHE[bufnr] = {
            file = file,
            link_tree = link_tree,
            node_tree = node_tree,
            tick = tick,
        }
    end

    return CACHE[bufnr]
end

---Retrieves the expression under cursor. In the case that
---an expression is not found or not within an orgmode buffer,
---the current word under cursor via `<cword>` is returned.
---@return string
function M.expr_under_cursor()
    -- Figure out our word, trying out treesitter
    -- if we are in an orgmode buffer, otherwise
    -- defaulting back to the vim word under cursor
    local word = vim.fn.expand("<cword>")
    if vim.api.nvim_buf_get_option(0, "filetype") == "org" then
        ---@type TSNode|nil
        local ts_node = vim.treesitter.get_node()
        if ts_node and ts_node:type() == "expr" then
            ---@type string
            word = vim.treesitter.get_node_text(ts_node, 0)
        end
    end
    return word
end

---Looks for a link under cursor. If it exists, the raw parsed link is returned.
---@return org-roam.core.file.Link|nil
function M.link_under_cursor()
    local bufnr = vim.api.nvim_win_get_buf(0)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local offset = vim.api.nvim_buf_get_offset(bufnr, cursor[1] - 1) + cursor[2]

    local cache = get_buffer_cache(bufnr)
    local tree = cache and cache.link_tree
    if tree then
        return tree:find_smallest_data({ offset, match = "contains" })
    end
end

---Returns a copy of the node under cursor of the current buffer.
---
---NOTE: This caches the state of the buffer (nodes), returning the pre-cached
---      result when possible. The cache is discarded whenever the current
---      buffer is detected as changed as seen via `b:changedtick`.
---
---@param cb fun(id:org-roam.core.file.Node|nil)
function M.node_under_cursor(cb)
    local bufnr = vim.api.nvim_win_get_buf(0)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local offset = vim.api.nvim_buf_get_offset(bufnr, cursor[1] - 1) + cursor[2]

    ---@return org-roam.core.file.Node|nil
    local function get_node()
        local cache = get_buffer_cache(bufnr)
        local tree = cache and cache.node_tree

        -- Find id of deepest node containing the offset
        if tree then
            return tree:find_smallest_data({ offset, match = "contains" })
        end
    end

    vim.schedule(function()
        cb(get_node())
    end)
end

---Converts a title into a slug that is acceptable in filenames.
---@param title string
---@return string
function M.title_to_slug(title)
    -- For conversion, we do the following steps:
    --
    -- 1. Convert anything not alphanumeric into an underscore
    -- 2. Remove consecutive underscores in favor of just one
    -- 3. Remove underscore at beginning
    -- 4. Remove underscore at end
    title = string.gsub(title, "%W", "_")
    title = string.gsub(title, "__", "_")
    title = string.gsub(title, "^_", "_")
    title = string.gsub(title, "_$", "_")
    return title
end

---@private
M.__cache = CACHE

return M
