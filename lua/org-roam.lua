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
local M = {}

---Called to initialize the org-roam plugin.
---@param config org-roam.Config
function M.setup(config)
    require("org-roam.setup")(config)

    local CONFIG  = require("org-roam.config")
    local db      = require("org-roam.database")
    local Promise = require("orgmode.utils.promise")

    -- Load the database asynchronously
    db:load():next(function()
        -- If we are persisting to disk, do so now as the database may
        -- have changed post-load
        if CONFIG.database.persist then
            return db:save()
        else
            return Promise.resolve(nil)
        end
    end):catch(function(err)
        require("org-roam.core.ui.notify").error(err)
    end)
end

return M
