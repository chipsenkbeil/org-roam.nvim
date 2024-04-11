-------------------------------------------------------------------------------
-- API.LUA
--
-- Contains the API for the roam plugin.
-------------------------------------------------------------------------------

local CompletionApi  = require("org-roam.api.completion")
local NodeApi        = require("org-roam.api.node")
local open_quickfix  = require("org-roam.ui.quickfix")
local open_node_view = require("org-roam.ui.node-view")

---@class org-roam.Api
local M              = {}

M.capture_node       = NodeApi.capture
M.complete_node      = CompletionApi.complete_node_under_cursor
M.find_node          = NodeApi.find
M.insert_node        = NodeApi.insert
M.open_node_buffer   = open_node_view
M.open_quickfix_list = open_quickfix

return M
