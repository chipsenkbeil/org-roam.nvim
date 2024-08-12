-------------------------------------------------------------------------------
-- PLUGIN.LUA
--
-- Setup logic for roam plugin modifications.
-------------------------------------------------------------------------------

local log = require("org-roam.core.log")

---@param roam OrgRoam
return function(roam)
    -- Provide a wrapper around `open_at_point` from orgmode mappings so we can
    -- attempt to jump to an id referenced by our database first, and then fall
    -- back to orgmode's id handling second.
    --
    -- This is needed as the default `open_at_point` only respects orgmode's
    -- files list and not org-roam's files list; so, we need to manually intercept!
    ---@diagnostic disable-next-line:duplicate-set-field
    require("orgmode").org_mappings.open_at_point = function(self)
        local row, col = vim.fn.getline("."), vim.fn.col(".") or 0
        local link = require("orgmode.org.hyperlinks").at_pos(row, col)
        local id = link and link.link and link.link.id
        local node = id and roam.database:get_sync(id)

        -- If we found a node, open the file at the start of the node
        if node then
            log.fmt_debug("Detected node %s under at (%d,%d)", node.id, row, col)
            local winnr = vim.api.nvim_get_current_win()
            vim.cmd.edit(node.file)

            -- NOTE: Schedule so we have time to process loading the buffer first!
            vim.schedule(function()
                -- Ensure that we do not jump past our buffer's last line!
                local bufnr = vim.api.nvim_win_get_buf(winnr)
                local line = math.min(vim.api.nvim_buf_line_count(bufnr), node.range.start.row + 1)

                vim.api.nvim_win_set_cursor(winnr, { line, 0 })
            end)

            return
        end

        -- Fall back to the default implementation
        return require("orgmode.org.mappings").open_at_point(self)
    end
end
