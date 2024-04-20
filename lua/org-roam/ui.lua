-------------------------------------------------------------------------------
-- UI.LUA
--
-- Contains the user interface for the roam plugin.
-------------------------------------------------------------------------------

---@param roam OrgRoam
---@return org-roam.UserInterface
return function(roam)
    local NodeBufferApi  = require("org-roam.ui.node-buffer")(roam)
    local QuickfixApi    = require("org-roam.ui.quickfix")(roam)
    local SelectNodeApi  = require("org-roam.ui.select-node")(roam)

    ---@class org-roam.UserInterface
    local M              = {}

    M.open_node_buffer   = NodeBufferApi.open_node_buffer
    M.open_quickfix_list = QuickfixApi.open_qflist
    M.select_node        = SelectNodeApi.select_node

    return M
end
