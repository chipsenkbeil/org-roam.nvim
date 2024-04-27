-------------------------------------------------------------------------------
-- NODE-BUFFER.LUA
--
-- API to view of a node's backlinks, citations, and unlinked references.
-------------------------------------------------------------------------------

local Buffer = require("org-roam.ui.node-buffer.buffer")
local Promise = require("orgmode.utils.promise")
local utils = require("org-roam.utils")
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
---@param opts? {focus?:boolean}
---@return OrgPromise<integer|nil>
local function roam_toggle_buffer(roam, opts)
    opts = opts or {}

    -- Create our handler for node changes if we haven't done so before
    if not STATE.cursor_update_initialized then
        STATE.cursor_update_initialized = true
        roam.events.on_cursor_node_changed(function(node)
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
        return Promise.new(function(resolve)
            utils.node_under_cursor(function(node)
                buffer:set_id(node and node.id)
                local win = Window:new({
                    buffer = buffer:to_internal_buffer(),
                    open = roam.config.ui.node_buffer.open,
                }):open()

                if opts.focus then
                    vim.api.nvim_set_current_win(win)
                end

                resolve(win)
            end)
        end)
    else
        for _, win in ipairs(windows) do
            vim.api.nvim_win_close(win, true)
        end

        return Promise.resolve(nil)
    end
end

---Launch an org-roam buffer for a specific node without visiting its file.
---
---Unlike `toggle_roam_buffer`, you can have multiple such buffers and their
---content won’t be automatically replaced with a new node at point.
---
---If an `id` is not specified, a prompt will appear to specify the id.
---@param roam OrgRoam
---@param opts? {id?:org-roam.core.database.Id, focus?:boolean}
---@return OrgPromise<integer|nil>
local function roam_toggle_fixed_buffer(roam, opts)
    opts = opts or {}
    return Promise.new(function(resolve)
        ---@param id org-roam.core.database.Id
        ---@diagnostic disable-next-line:redefined-local
        local function toggle_node_buffer(id)
            print("... TOGGLE NODE BUFFER: " .. id)
            ---@type org-roam.ui.NodeBuffer|nil
            local buffer = STATE.fixed_node_buffers[id]
            print("... BUFFER EXISTS: " .. (buffer and "yes" or "no"))

            -- Create the buffer if it does not exist or is deleted
            if not buffer or not buffer:is_valid() then
                buffer = Buffer:new(roam, {
                    id = id,
                })

                STATE.fixed_node_buffers[id] = buffer
                print("... CREATED NEW BUFFER")
            end

            local windows = buffer:windows_for_tabpage(0)
            print("... WINDOWS FOR BUFFER: " .. vim.inspect(windows))

            -- If we have no window containing the buffer, create one; otherwise,
            -- close all of the windows containing the buffer
            if #windows == 0 then
                print("... CREATING WIN FOR BUF " .. buffer:bufnr())
                local win = Window:new({
                    buffer = buffer:to_internal_buffer(),
                    open = roam.config.ui.node_buffer.open,
                }):open()

                if opts.focus then
                    vim.api.nvim_set_current_win(win)
                end

                print("... CREATED NEW WIN: " .. vim.inspect(win))
                resolve(win)
            else
                for _, win in ipairs(windows) do
                    vim.api.nvim_win_close(win, true)
                end

                print("... CLOSED WINS")
                resolve(nil)
            end
        end

        if opts.id then
            toggle_node_buffer(opts.id)
        else
            roam.ui.select_node()
                :on_choice(function(choice)
                    toggle_node_buffer(choice.id)
                end)
                :on_cancel(function()
                    resolve(nil)
                end)
                :open()
        end
    end)
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
    ---Returns a promise containing the handle of the created window or
    ---nil if windows containing the node buffer were closed instead.
    ---
    ---@param opts? {fixed?:boolean|org-roam.core.database.Id, focus?:boolean}
    ---@return OrgPromise<integer|nil>
    function M.toggle_node_buffer(opts)
        opts = opts or {}

        local fixed = opts.fixed

        if type(fixed) == "boolean" and fixed then
            return roam_toggle_fixed_buffer(roam, { focus = opts.focus })
        elseif type(fixed) == "string" then
            return roam_toggle_fixed_buffer(roam, { id = fixed, focus = opts.focus })
        else
            return roam_toggle_buffer(roam, { focus = opts.focus })
        end
    end

    return M
end
