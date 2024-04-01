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

    local log = require("org-roam.core.log")
    local Profiler = require("org-roam.core.utils.profiler")

    local profiler = Profiler:new({ label = "org-roam.setup.load-database" })
    profiler:start()

    -- Load the database asynchronously
    require("org-roam.database"):load(function(err)
        log.info(profiler:stop():print_as_string())
        if err then
            require("org-roam.core.ui.notify").error(err)
        end
    end)
end

return M
