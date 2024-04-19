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
---@field evt org-roam.Events
---@field ext org-roam.Extensions
---@field ui org-roam.UserInterface
local M = {}
M.__index = M

---Creates a new instance of the org-roam plugin.
---@param config? org-roam.Config
---@return OrgRoam
function M:new(config)
    local instance = {}
    setmetatable(instance, M)

    instance.api    = require("org-roam.api")(instance)
    instance.config = config or require("org-roam.config")(instance)
    instance.db     = require("org-roam.database")(instance)
    instance.evt    = require("org-roam.events")(instance)
    instance.ext    = require("org-roam.extensions")(instance)
    instance.ui     = require("org-roam.ui")(instance)

    return instance
end

---Initializes the plugin.
---@param config org-roam.Config
function M:setup(config)
    require("org-roam.setup")(self, config)
end

local INSTANCE = M:new()
return INSTANCE
