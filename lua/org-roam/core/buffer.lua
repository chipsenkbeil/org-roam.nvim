-------------------------------------------------------------------------------
-- BUFFER.LUA
--
-- Utilities related to operating on org roam buffers.
-------------------------------------------------------------------------------

local IntervalTree = require("org-roam.core.utils.tree.interval")
local Scanner = require("org-roam.core.scanner")

local BUFFER_DIRTY_FLAG = "org-roam-buffer-dirty"

---Internal cache of buffer -> tree of node ids used to look up nodes
---within buffers
---@type table<integer, org-roam.core.utils.tree.IntervalTree>
local NODE_TREE_CACHE = {}

-------------------------------------------------------------------------------
-- PUBLIC
-------------------------------------------------------------------------------

---@class org-roam.core.buffer
local M = {}

---Sets the dirty flag of buffer to `value`.
---@param bufnr integer
---@param value boolean
function M.set_dirty_flag(bufnr, value)
    vim.b[bufnr][BUFFER_DIRTY_FLAG] = value
end

---Returns true if the buffer has a dirty flag set to true.
---@param bufnr integer
---@return boolean
function M.is_dirty(bufnr)
    return vim.b[bufnr][BUFFER_DIRTY_FLAG] == true
end

---Determines the id of the node under the cursor.
---@param cb fun(id:org-roam.core.database.Id|nil)
function M.node_under_cursor(cb)
    local bufnr = vim.api.nvim_win_get_buf(0)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local offset = vim.api.nvim_buf_get_offset(bufnr, cursor[1] - 1) + cursor[2]

    ---@return org-roam.core.database.Id|nil
    local function get_id()
        local is_dirty = M.is_dirty(bufnr)
        local tree = NODE_TREE_CACHE[bufnr]

        if is_dirty or not tree then
            -- TODO: Can we just index by filename in the database
            --       and `find_by_index` to get nodes connected to the
            --       file represented by the buffer to build this
            --       up versus re-parsing the buffer?
            local contents = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
            local scan = Scanner.scan(contents)

            if #scan.nodes > 0 then
                tree = IntervalTree:from_list(
                ---@param node org-roam.core.database.Node
                    vim.tbl_map(function(node)
                        return {
                            node.range.start.offset,
                            node.range.end_.offset,
                            node.id,
                        }
                    end, scan.nodes)
                )
            end

            -- Reset dirty flag as we've parsed
            M.set_dirty_flag(bufnr, false)

            -- Update cache pointer
            NODE_TREE_CACHE[bufnr] = tree
        end

        -- Find id of deepest node containing the offset
        if tree then
            return tree:find_last_data({ offset, match = "contains" })
        end
    end

    vim.schedule(function()
        cb(get_id())
    end)
end

return M
