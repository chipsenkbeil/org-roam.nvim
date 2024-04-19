-------------------------------------------------------------------------------
-- NODE-VIEW.LUA
--
-- Toggles a view of a node's backlinks, citations, and unlinked references.
-------------------------------------------------------------------------------

local utils = require("org-roam.utils")
local Window = require("org-roam.ui.node-view.window")

---@type org-roam.ui.window.NodeViewWindow|nil
local CURSOR_NODE_VIEW

---@type table<org-roam.core.database.Id, org-roam.ui.window.NodeViewWindow>
local NODE_VIEW = {}

---Launch an org-roam buffer that tracks the node currently at point.
---
---This means that the content of the buffer changes as the point is moved,
---if necessary.
---@param roam OrgRoam
local function toggle_node_view(roam)
    -- Determine if we have a window that is open but not with our
    -- node-view buffer
    local invalid_window =
        (CURSOR_NODE_VIEW
            and CURSOR_NODE_VIEW:is_open()
            and CURSOR_NODE_VIEW:has_original_buffer())
        or false

    if not CURSOR_NODE_VIEW or invalid_window then
        CURSOR_NODE_VIEW = Window:new(roam, {
            open = roam.config.ui.node_view.open,
        })

        -- Whenever the node changes, rerender the window
        ---@param node org-roam.core.file.Node|nil
        roam.evt.on(roam.evt.KIND.CURSOR_NODE_CHANGED, function(node)
            if node then
                CURSOR_NODE_VIEW:set_id(node.id)
            end
        end)
    end

    if not CURSOR_NODE_VIEW:is_open() then
        -- Manually trigger a capture of the node under cursor to start
        -- as the event above won't do anything at first
        utils.node_under_cursor(function(node)
            CURSOR_NODE_VIEW:set_id(node and node.id)
            CURSOR_NODE_VIEW:open()
        end)
    elseif CURSOR_NODE_VIEW:has_original_buffer() then
        CURSOR_NODE_VIEW:close()
    else
        CURSOR_NODE_VIEW = nil
    end
end

---Launch an org-roam buffer for a specific node without visiting its file.
---
---Unlike `toggle_roam_buffer`, you can have multiple such buffers and their
---content won’t be automatically replaced with a new node at point.
---
---If an `id` is not specified, a prompt will appear to specify the id.
---@param roam OrgRoam
---@param id? org-roam.core.database.Id
local function toggle_fixed_node_view(roam, id)
    ---@param id org-roam.core.database.Id
    ---@diagnostic disable-next-line:redefined-local
    local function toggle_view(id)
        if id then
            if not NODE_VIEW[id] then
                NODE_VIEW[id] = Window:new(roam, {
                    id = id,
                    open = roam.config.ui.node_view.open,
                })
            end

            NODE_VIEW[id]:toggle()
        end
    end

    if id then
        toggle_view(id)
    else
        roam.ui.select_node(function(selection)
            if selection.id then
                toggle_view(selection.id)
            end
        end)
    end
end

---@param roam OrgRoam
---@return org-roam.ui.NodeViewApi
return function(roam)
    ---@class org-roam.ui.NodeViewApi
    local M = {}

    ---Toggles an org-roam buffer, either for a cursor or for a fixed id.
    ---
    ---If `id` is `true` or an string, will load a fixed buffer, otherwise
    ---the buffer will change based on the node under cursor.
    ---
    ---@param opts? {fixed?:boolean|org-roam.core.database.Id}
    function M.open_node_buffer(opts)
        opts = opts or {}

        local fixed = opts.fixed
        if type(fixed) == "boolean" and fixed then
            toggle_fixed_node_view(roam)
        elseif type(fixed) == "string" then
            toggle_fixed_node_view(roam, fixed)
        else
            toggle_node_view(roam)
        end
    end

    return M
end
