-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- High-level utility functions leveraged by org-roam.
-------------------------------------------------------------------------------

local IntervalTree = require("org-roam.core.utils.tree.interval")
local Scanner = require("org-roam.core.scanner")

---Internal cache of buffer -> cache of node ids used to look up
---nodes within buffers.
---@type table<integer, {tick:integer, tree:org-roam.core.utils.tree.IntervalTree|nil}>
local CACHE = {}

local M = {}

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
            word = vim.treesitter.get_node_text(ts_node, 0)
        end
    end
    return word
end

---Returns a copy of the node under cursor of the current buffer.
---
---NOTE: This caches the state of the buffer (nodes), returning the pre-cached
---      result when possible. The cache is discarded whenever the current
---      buffer is detected as changed as seen via `b:changedtick`.
---
---@param cb fun(id:org-roam.core.database.Node|nil)
function M.node_under_cursor(cb)
    local bufnr = vim.api.nvim_win_get_buf(0)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local offset = vim.api.nvim_buf_get_offset(bufnr, cursor[1] - 1) + cursor[2]

    ---@return org-roam.core.database.Node|nil
    local function get_node()
        local cache = CACHE[bufnr]
        ---@type integer
        local tick = vim.b[bufnr].changedtick

        local tree = cache and cache.tree
        local is_dirty = tick ~= (cache and cache.tick)

        -- If the buffer has changed or we had no cache, update
        if is_dirty or not cache then
            -- TODO: Can we just index by filename in the database
            --       and `find_by_index` to get nodes connected to the
            --       file represented by the buffer to build this
            --       up versus re-parsing the buffer?
            local contents = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
            local scan = Scanner.scan(contents, {
                path = vim.api.nvim_buf_get_name(bufnr),
            })

            if #scan.nodes > 0 then
                tree = IntervalTree:from_list(
                ---@param node org-roam.core.database.Node
                    vim.tbl_map(function(node)
                        return {
                            node.range.start.offset,
                            node.range.end_.offset,
                            node,
                        }
                    end, scan.nodes)
                )
            end

            -- Update cache pointer to reflect the current state
            CACHE[bufnr] = {
                tree = tree,
                tick = tick,
            }
        end

        -- Find id of deepest node containing the offset
        if tree then
            return tree:find_last_data({ offset, match = "contains" })
        end
    end

    vim.schedule(function()
        cb(get_node())
    end)
end

return M
