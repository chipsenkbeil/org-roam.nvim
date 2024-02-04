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
    local Instance = require("org-roam.core.config.instance")
    local instance = Instance:new(opts)

    -- Merge our configuration options into our global config
    local config = require("org-roam.core.config")
    local exclude = { "new", "__index" }
    for key, value in pairs(instance) do
        if not vim.tbl_contains(exclude, key) then
            config[key] = value
        end
    end
end

return M
