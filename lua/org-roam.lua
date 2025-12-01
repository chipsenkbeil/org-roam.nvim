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
---@field database org-roam.Database
---@field ext org-roam.Extensions
---@field setup org-roam.Setup
---@field ui org-roam.UserInterface
---@field utils org-roam.Utils
---@field __augroup integer (internal autocmd group)
local M = {}

---@private
---Invoked when a field is missing, which should be any plugin field that
---has not been accessed before. Upon first access, the field will be
---populated from the lazy declaration and available for future access.
function M.__index(tbl, key)
    -- Check the metatable first for missing value
    local value = rawget(getmetatable(tbl) or tbl, key)
    if value then
        return value
    end

    -- Otherwise, load it from the lazy table
    local lazy = rawget(tbl, "__lazy")
    value = lazy and lazy[key] and lazy[key]()
    if value then
        tbl[key] = value
        lazy[key] = nil
        return value
    end
end

---Creates a new instance of the org-roam plugin.
---@param config? org-roam.Config
---@return OrgRoam
function M:new(config)
    local instance = {}
    setmetatable(instance, M)

    -- For our fields, we will be lazily loading them as needed
    local lazy = {}

    lazy.api = function()
        return require("org-roam.api")(instance)
    end

    lazy.config = function()
        local Config = require("org-roam.config")
        config = config or Config:new()
        return Config:new():replace(config or {})
    end

    lazy.database = function()
        local Database = require("org-roam.database")
        return Database:new({
            db_path = instance.config.database.path,
            directory = instance.config.directory,
            org_files = instance.config.org_files,
        })
    end

    lazy.ext = function()
        return require("org-roam.extensions")(instance)
    end

    lazy.setup = function()
        return require("org-roam.setup")(instance)
    end

    lazy.ui = function()
        return require("org-roam.ui")(instance)
    end

    lazy.utils = function()
        return require("org-roam.utils")
    end

    -- Create our distinct group id we use for autocmds
    instance.__augroup = vim.api.nvim_create_augroup("org-roam.nvim", {})

    instance.__lazy = lazy
    return instance
end

local INSTANCE = M:new()
return INSTANCE
