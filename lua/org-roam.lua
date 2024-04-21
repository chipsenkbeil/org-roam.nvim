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
---@field events org-roam.Events
---@field ext org-roam.Extensions
---@field setup org-roam.Setup
---@field ui org-roam.UserInterface
---@field utils org-roam.Utils
local M = {}
M.__index = M

---Creates a new instance of the org-roam plugin.
---@param config? org-roam.Config
---@return OrgRoam
function M:new(config)
    local instance = {}
    setmetatable(instance, M)

    local Config    = require("org-roam.config")
    local Database  = require("org-roam.database")

    -- Use the supplied config, or leverage the default
    config          = config or Config:new()

    instance.api    = require("org-roam.api")(instance)
    instance.config = Config:new():replace(config or {})
    instance.db     = Database:new({
        db_path = instance.config.database.path,
        directory = instance.config.directory,
    })
    instance.events = require("org-roam.events")(instance)
    instance.ext    = require("org-roam.extensions")(instance)
    instance.setup  = require("org-roam.setup")(instance)
    instance.ui     = require("org-roam.ui")(instance)
    instance.utils  = require("org-roam.utils")

    return instance
end

local INSTANCE = M:new()
return INSTANCE
