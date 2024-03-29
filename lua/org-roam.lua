-------------------------------------------------------------------------------
-- ORG-ROAM.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

-- Verify that we have orgmode available
if not pcall(require, "orgmode") then
    error("missing dependency: orgmode")
end

---@class org-roam.OrgRoam
---@field files OrgFiles
local M = {}

---Called to initialize the org-roam plugin.
---@param config org-roam.Config
function M.setup(config)
    require("org-roam.setup")(M, config)

    -- Load the database asynchronously
    require("org-roam.database"):__load(function(err)
        if err then
            require("org-roam.core.ui.notify").error(err)
        end
    end)
end

return M
