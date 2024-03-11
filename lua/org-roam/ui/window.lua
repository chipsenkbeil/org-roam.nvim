-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Primary user interface controls for org-roam specialized windows.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local NodeViewWindow = require("org-roam.ui.window.node-view")
local Select = require("org-roam.core.ui.select")

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

    ---@param id org-roam.core.database.Id
    local function toggle_view(id)
        if id then
            if not NODE_VIEW[id] then
                NODE_VIEW[id] = NodeViewWindow:new({ id = id })
            end

            NODE_VIEW[id]:toggle()
        end
    end

    if id then
        toggle_view(id)
    else
        Select:new({ items = db:ids(), prompt = " (node) " })
            :on_choice(function(id) toggle_view(id) end)
            :open()
    end
end

return M
