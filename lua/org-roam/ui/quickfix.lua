-------------------------------------------------------------------------------
-- QUICKFIX.LUA
--
-- Primary user interface controls for the quickfix list.
-------------------------------------------------------------------------------

local database = require("org-roam.database")

local M = {}

---Opens the quickfix list for the node `id`, populating with backlinks.
---
---If `show_preview` is true, will load a preview of the line containing
---the backlink.
---
---@param id org-roam.core.database.Id
---@param opts? {show_preview?:boolean}
function M.open_for_node(id, opts)
    local db = database()

    require("org-roam.core.ui.quickfix").open(
        db,
        id,
        vim.tbl_extend("keep", { backlinks = true }, opts or {})
    )
end

---Opens the quickfix list for the node under cursor, populating with backlinks.
---
---If `show_preview` is true, will load a preview of the line containing
---the backlink.
---
---@param opts? {show_preview?:boolean}
function M.open_for_node_under_cursor(opts)
    require("org-roam.buffer").node_under_cursor(function(id)
        if id then
            M.open_qflist_for_node(id, opts)
        end
    end)
end

return M
