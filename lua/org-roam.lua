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

---@param id org-roam.core.database.Id
function M.open_qflist_for_node(id)
    local db = assert(M.__database, "not initialized")
    require("org-roam.core.ui").open_qflist_backlinks(db, id)
end

function M.open_qflist_for_node_under_cursor()
    require("org-roam.core.buffer").node_under_cursor(function(id)
        if id then
            M.open_qflist_for_node(id)
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
