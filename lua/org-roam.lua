-------------------------------------------------------------------------------
-- ORG-ROAM.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

---@class org-roam.OrgRoam
---@field database org-roam.core.database.Database|nil
local M = {}

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    require("org-roam.setup")(opts, function(db)
        M.database = db
    end)
end

return M
