-------------------------------------------------------------------------------
-- ORG-ROAM.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

---@class org-roam.OrgRoam
---@field private __database org-roam.core.database.Database|nil
local M = {
    __database = nil,
}

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    require("org-roam.setup")(opts, function(db)
        M.__database = db
    end)
end

---Opens the quickfix list for the node `id`, populating with backlinks.
---
---If `show_preview` is true, will load a preview of the line containing
---the backlink.
---
---@param id org-roam.core.database.Id
---@param opts? {show_preview?:boolean}
function M.open_qflist_for_node(id, opts)
    local db = assert(M.__database, "not initialized")

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
function M.open_qflist_for_node_under_cursor(opts)
    require("org-roam.core.buffer").node_under_cursor(function(id)
        if id then
            M.open_qflist_for_node(id, opts)
        end
    end)
end

function M.print_node_under_cursor()
    require("org-roam.core.buffer").node_under_cursor(function(id)
        if id then
            print(id)
        end
    end)
end

return M
