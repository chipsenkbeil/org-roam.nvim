-------------------------------------------------------------------------------
-- EXTENSIONS.LUA
--
-- Contains extensions that can be loaded into the plugin.
--
-- See https://www.orgroam.com/manual.html#Extensions
-------------------------------------------------------------------------------

---@param roam OrgRoam
---@return org-roam.Extensions
return function(roam)
    ---@class org-roam.Extensions
    local M = {}

    M.dailies = require("org-roam.extensions.dailies")(roam)
    M.export = require("org-roam.extensions.export")(roam)
    M.graph = require("org-roam.extensions.graph")(roam)
    M.protocol = require("org-roam.extensions.protocol")(roam)

    return M
end
