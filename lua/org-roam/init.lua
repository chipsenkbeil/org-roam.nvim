-------------------------------------------------------------------------------
-- INIT.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

---@class org-roam.OrgRoam
local M = {}

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    local Config = require("org-roam.core.config")
    local config = Config:new(opts)

    ---@diagnostic disable-next-line:invisible
    Config:__set_global(config)
end

return M
