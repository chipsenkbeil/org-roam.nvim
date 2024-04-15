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
local M = setmetatable({}, {
    __index = function(tbl, key)
        local value = rawget(tbl, key)
        if type(value) == "nil" then
            local init_list = { "api", "config", "db", "evt", "ext" }
            if vim.tbl_contains(init_list, key) then
                error(table.concat({
                    "Roam plugin not yet initialized!",
                    "Cannot access roam." .. key .. ".",
                    "Invoke roam:setup(...) first.",
                }, " "))
            end
        end
        return value
    end,
})

---Initializes the plugin.
---
---NOTE: This MUST be called before doing anything else!
---@param config org-roam.Config
function M:setup(config)
    require("org-roam.setup")(self, config)
end

return M
