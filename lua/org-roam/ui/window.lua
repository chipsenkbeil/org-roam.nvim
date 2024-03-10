-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Primary user interface controls for org-roam specialized windows.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local NodeViewWindow = require("org-roam.ui.window.node-view")

---@type org-roam.ui.window.NodeViewWindow|nil
local CURSOR_NODE_VIEW

---@type table<org-roam.core.database.Id, org-roam.ui.window.NodeViewWindow>
local NODE_VIEW = {}

local M = {}

---Launch an org-roam buffer that tracks the node currently at point.
---
---This means that the content of the buffer changes as the point is moved,
---if necessary.
function M.toggle_node_view()
    if not CURSOR_NODE_VIEW then
        CURSOR_NODE_VIEW = NodeViewWindow:new()
    end

    CURSOR_NODE_VIEW:toggle()
end

---Launch an org-roam buffer for a specific node without visiting its file.
---
---Unlike `toggle_roam_buffer`, you can have multiple such buffers and their
---content won’t be automatically replaced with a new node at point.
---
---If an `id` is not specified, a prompt will appear to specify the id.
---@param id? org-roam.core.database.Id
function M.toggle_fixed_node_view(id)
    local db = database()

    vim.ui.input({
        prompt = "node> ",
        completion = "custom,v:lua.require('org-roam.competion').SelectFixedNode",
    }, function(input)
        if input and input ~= "" then
        end
    end)

    if not NODE_VIEW[id] then
        NODE_VIEW[id] = NodeViewWindow:new({ id = id })
    end

    NODE_VIEW[id]:toggle()
end

return M
