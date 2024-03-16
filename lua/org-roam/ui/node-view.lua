-------------------------------------------------------------------------------
-- NODE-VIEW.LUA
--
-- Toggles a view of a node's backlinks, citations, and unlinked references.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local select_node = require("org-roam.ui.select-node")
local Window = require("org-roam.ui.node-view.window")

---@type org-roam.ui.window.NodeViewWindow|nil
local CURSOR_NODE_VIEW

---@type table<org-roam.core.database.Id, org-roam.ui.window.NodeViewWindow>
local NODE_VIEW = {}

---Launch an org-roam buffer that tracks the node currently at point.
---
---This means that the content of the buffer changes as the point is moved,
---if necessary.
local function toggle_node_view()
    if not CURSOR_NODE_VIEW then
        CURSOR_NODE_VIEW = Window:new()
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
local function toggle_fixed_node_view(id)
    ---@param id org-roam.core.database.Id
    local function toggle_view(id)
        if id then
            if not NODE_VIEW[id] then
                NODE_VIEW[id] = Window:new({ id = id })
            end

            NODE_VIEW[id]:toggle()
        end
    end

    if id then
        toggle_view(id)
    else
        select_node(function(selection)
            toggle_view(selection.id)
        end)
    end
end

---Toggles an org-roam buffer, either for a cursor or for a fixed id.
---
---If `id` is `true` or an string, will load a fixed buffer, otherwise
---the buffer will change based on the node under cursor.
---
---@param opts? {fixed?:boolean|org-roam.core.database.Id}
return function(opts)
    opts = opts or {}

    local fixed = opts.fixed
    if type(fixed) == "boolean" and fixed then
        toggle_fixed_node_view()
    elseif type(fixed) == "string" then
        toggle_fixed_node_view(fixed)
    else
        toggle_node_view()
    end
end
