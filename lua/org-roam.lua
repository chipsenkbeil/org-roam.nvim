-------------------------------------------------------------------------------
-- ORG-ROAM.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

-- Verify that we have orgmode available
if not pcall(require, "orgmode") then
    error("missing dependency: orgmode")
end

---@class OrgRoam
---@field api org-roam.Api
---@field config org-roam.Config
---@field db org-roam.Database
---@field evt org-roam.events.Emitter
---@field ext org-roam.Extensions
local M = {}

---Initializes the plugin.
---
---NOTE: This MUST be called before doing anything else!
---@param config org-roam.Config
function M:setup(config)
    require("org-roam.setup")(self, config)
end

return M
