-------------------------------------------------------------------------------
-- API.LUA
--
-- Contains the API for the roam plugin.
-------------------------------------------------------------------------------

---@param roam OrgRoam
---@return org-roam.Api
return function(roam)
    local AliasApi      = require("org-roam.api.alias")(roam)
    local CompletionApi = require("org-roam.api.completion")(roam)
    local NodeApi       = require("org-roam.api.node")(roam)
    local OriginApi     = require("org-roam.api.origin")(roam)

    ---@class org-roam.Api
    local M             = {}

    M.add_alias         = AliasApi.add_alias
    M.add_origin        = OriginApi.add_origin
    M.capture_node      = NodeApi.capture
    M.complete_node     = CompletionApi.complete_node_under_cursor
    M.find_node         = NodeApi.find
    M.goto_next_node    = OriginApi.goto_next_node
    M.goto_prev_node    = OriginApi.goto_prev_node
    M.insert_node       = NodeApi.insert
    M.remove_alias      = AliasApi.remove_alias
    M.remove_origin     = OriginApi.remove_origin

    return M
end
