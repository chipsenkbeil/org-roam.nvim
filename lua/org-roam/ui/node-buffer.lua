-------------------------------------------------------------------------------
-- NODE-BUFFER.LUA
--
-- API to view of a node's backlinks, citations, and unlinked references.
-------------------------------------------------------------------------------

local utils = require("org-roam.utils")
local Buffer = require("org-roam.ui.node-buffer.buffer")
local Window = require("org-roam.core.ui.window")

local STATE = {
    ---@type org-roam.ui.NodeBuffer|nil
    cursor_node_buffer = nil,

    ---@type boolean
    cursor_update_initialized = false,

    ---@type table<org-roam.core.database.Id, org-roam.ui.NodeBuffer>
    fixed_node_buffers = {},
}

---Toggles the org-roam node buffer.
---
---If none exists, create it and open a window to show it.
---If one already exists and is visible, closes it.
---If one exists and is hidden, open a window and show it.
---@param roam OrgRoam
local function roam_toggle_buffer(roam)
    -- Create our handler for node changes if we haven't done so before
    if not STATE.cursor_update_initialized then
        STATE.cursor_update_initialized = true
        roam.evt.on_cursor_node_changed(function(node)
            local buffer = STATE.cursor_node_buffer
            if node and buffer then
                buffer:set_id(node.id)
            end
        end)
    end

    -- If we don't have the buffer or it no longer exists, create it
    if not STATE.cursor_node_buffer or not STATE.cursor_node_buffer:is_valid() then
        STATE.cursor_node_buffer = Buffer:new(roam)
    end

    -- Grab the buffer and see how many windows are showing it
    local buffer = STATE.cursor_node_buffer --[[ @cast buffer -nil ]]
    local windows = buffer:windows_for_tabpage(0)

    -- If we have no window containing the buffer, create one; otherwise,
    -- close all of the windows containing the buffer
    if #windows == 0 then
        -- Manually trigger a capture of the node under cursor to start
        -- as the event above won't do anything at first
        utils.node_under_cursor(function(node)
            buffer:set_id(node and node.id)
            Window:new({
                buffer = buffer:to_internal_buffer(),
                open = roam.config.ui.node_buffer.open,
            }):open()
        end)
    else
        for _, win in ipairs(windows) do
            vim.api.nvim_win_close(win, true)
        end
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
local function roam_toggle_fixed_buffer(roam, id)
    ---@param id org-roam.core.database.Id
    ---@diagnostic disable-next-line:redefined-local
    local function toggle_node_buffer(id)
        ---@type org-roam.ui.NodeBuffer|nil
        local buffer = STATE.fixed_node_buffers[id]

        -- Create the buffer if it does not exist or is deleted
        if not buffer or not buffer:is_valid() then
            buffer = Buffer:new(roam, {
                id = id,
            })

            STATE.fixed_node_buffers[id] = buffer
        end

        local windows = buffer:windows_for_tabpage(0)

        -- If we have no window containing the buffer, create one; otherwise,
        -- close all of the windows containing the buffer
        if #windows == 0 then
            Window:new({
                buffer = buffer:to_internal_buffer(),
                open = roam.config.ui.node_buffer.open,
            }):open()
        else
            for _, win in ipairs(windows) do
                vim.api.nvim_win_close(win, true)
            end
        end
    end

    if id then
        toggle_node_buffer(id)
    else
        roam.ui.select_node(function(selection)
            if selection.id then
                toggle_node_buffer(selection.id)
            end
        end)
    end
end

---@param roam OrgRoam
---@return org-roam.ui.NodeBufferApi
return function(roam)
    ---@class org-roam.ui.NodeBufferApi
    local M = {}

    ---Toggles an org-roam buffer, either for the cursor or for a fixed id.
    ---
    ---If `id` is `true` or an string, will load a fixed buffer, otherwise
    ---the buffer will change based on the node under cursor.
    ---
    ---@param opts? {fixed?:boolean|org-roam.core.database.Id}
    function M.open_node_buffer(opts)
        opts = opts or {}

        local fixed = opts.fixed
        if type(fixed) == "boolean" and fixed then
            roam_toggle_fixed_buffer(roam)
        elseif type(fixed) == "string" then
            roam_toggle_fixed_buffer(roam, fixed)
        else
            roam_toggle_buffer(roam)
        end
    end

    return M
end
