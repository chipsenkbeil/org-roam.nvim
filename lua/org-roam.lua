-------------------------------------------------------------------------------
-- ORG-ROAM.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local setup = require("org-roam.setup")

---@class org-roam.OrgRoam
local M = setmetatable({}, {
    __index = function(tbl, key)
        local lookups = { "org-roam.ui" }

        local value = nil

        for _, lookup in ipairs(lookups) do
            local obj = require(lookup)
            if obj and obj[key] ~= nil then
                value = obj[key]
                break
            end
        end

        return value
    end,
})

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    setup(opts)

    -- Load the database asynchronously
    database.load(function() end)
end

return M
