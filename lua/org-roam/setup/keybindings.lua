-------------------------------------------------------------------------------
-- KEYBINDINGS.LUA
--
-- Setup logic for roam keybindings.
-------------------------------------------------------------------------------

local notify = require("org-roam.core.ui.notify")

---@alias org-roam.config.NvimMode
---| "n"
---| "v"
---| "x"
---| "s"
---| "o"
---| "i"
---| "l"
---| "c"
---| "t"

---@param lhs string|{lhs:string, modes:org-roam.config.NvimMode[]}|nil
---@param desc string
---@param cb fun()
local function assign(lhs, desc, cb)
    if type(cb) ~= "function" then return end
    if not lhs then return end

    local modes = { "n" }
    if type(lhs) == "table" then
        modes = lhs.modes
        lhs = lhs.lhs
    end

    if vim.trim(lhs) == "" or #modes == 0 then return end

    for _, mode in ipairs(modes) do
        vim.api.nvim_set_keymap(mode, lhs, "", {
            desc = desc,
            noremap = true,
            callback = cb,
        })
    end
end

---Retrievies selection if in visual mode.
---Returns "unsupported" if blockwise-visual mode.
---Returns false if not in visual/linewise-visual mode.
---@param roam OrgRoam
---@return {title:string, ranges:org-roam.utils.Range[]}|"unsupported"|false
local function get_visual_selection(roam)
    ---@type string
    local mode = vim.api.nvim_get_mode()["mode"]

    -- Handle visual mode and linewise visual mode
    -- (ignore blockwise-visual mode)
    if mode == "v" or mode == "V" then
        local lines, ranges = roam.utils.get_visual_selection({ single_line = true })
        local title = lines[1] or ""

        return { title = title, ranges = ranges }
    elseif mode == "\x16" then
        -- Force exit visual block mode
        local ESC_FEEDKEY = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
        vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)

        vim.schedule(function()
            notify.echo_error("node insertion not supported for blockwise-visual mode")
        end)

        return "unsupported"
    else
        return false
    end
end

---@param roam OrgRoam
local function assign_core_keybindings(roam)
    -- User can remove all bindings by setting this to nil
    local bindings = roam.config.bindings or {}

    assign(
        bindings.add_alias,
        "Adds an alias to the roam node under cursor",
        function()
            roam.api.add_alias()
        end
    )

    assign(
        bindings.remove_alias,
        "Removes an alias from the roam node under cursor",
        function()
            roam.api.remove_alias()
        end
    )

    assign(
        bindings.add_origin,
        "Adds an origin to the roam node under cursor",
        function()
            roam.api.add_origin()
        end
    )

    assign(
        bindings.remove_origin,
        "Removes the origin from the roam node under cursor",
        function()
            roam.api.remove_origin()
        end
    )

    assign(
        bindings.goto_prev_node,
        "Goes to the previous node sequentially based on origin of the node under cursor",
        function()
            roam.api.goto_prev_node()
        end
    )

    assign(
        bindings.goto_next_node,
        "Goes to the next node sequentially based on origin of the node under cursor",
        function()
            roam.api.goto_next_node()
        end
    )

    assign(
        bindings.quickfix_backlinks,
        "Open quickfix of backlinks for org-roam node under cursor",
        function()
            roam.ui.open_quickfix_list({
                backlinks = true,
                show_preview = true,
            })
        end
    )

    assign(
        bindings.toggle_roam_buffer,
        "Toggles org-roam buffer for node under cursor",
        function()
            roam.ui.toggle_node_buffer({
                focus = roam.config.ui.node_buffer.focus_on_toggle,
            })
        end
    )

    assign(
        bindings.toggle_roam_buffer_fixed,
        "Toggles org-roam buffer for a specific node, not changing",
        function()
            roam.ui.toggle_node_buffer({
                fixed = true,
                focus = roam.config.ui.node_buffer.focus_on_toggle,
            })
        end
    )

    assign(
        bindings.complete_at_point,
        "Completes link to a node based on expression under cursor",
        function()
            roam.api.complete_node()
        end
    )

    assign(
        { lhs = bindings.capture, modes = { "n", "v" } },
        "Opens org-roam capture window",
        function()
            local results = get_visual_selection(roam)
            local title
            if type(results) == "table" then
                title = results.title
            elseif results == "unsupported" then
                return
            end
            roam.api.capture_node({
                title = title,
            })
        end
    )

    assign(
        { lhs = bindings.find_node, modes = { "n", "v" } },
        "Finds org-roam node and moves to it, creating new one if missing",
        function()
            local results = get_visual_selection(roam)
            local title
            if type(results) == "table" then
                title = results.title
            elseif results == "unsupported" then
                return
            end
            roam.api.find_node({
                title = title,
            })
        end
    )

    assign(
        { lhs = bindings.insert_node, modes = { "n", "v" } },
        "Inserts at cursor position the selected node, creating new one if missing",
        function()
            local results = get_visual_selection(roam)
            local title, ranges
            if type(results) == "table" then
                title = results.title
                ranges = results.ranges
            elseif results == "unsupported" then
                return
            end
            roam.api.insert_node({
                title = title,
                ranges = ranges,
            })
        end
    )

    assign(
        { lhs = bindings.insert_node_immediate, modes = { "n", "v" } },
        "Inserts at cursor position the selected node, creating new one if missing without opening a capture buffer",
        function()
            local results = get_visual_selection(roam)
            local title, ranges
            if type(results) == "table" then
                title = results.title
                ranges = results.ranges
            elseif results == "unsupported" then
                return
            end
            roam.api.insert_node({
                immediate = true,
                title = title,
                ranges = ranges,
            })
        end
    )
end

---@param roam OrgRoam
local function assign_dailies_keybindings(roam)
    -- User can remove all bindings by setting this to nil
    local bindings = roam.config.extensions.dailies.bindings or {}

    assign(
        bindings.capture_date,
        "Capture a specific date's note",
        function()
            roam.ext.dailies.capture_date()
        end
    )

    assign(
        bindings.capture_today,
        "Capture today's note",
        function()
            roam.ext.dailies.capture_today()
        end
    )

    assign(
        bindings.capture_tomorrow,
        "Capture tomorrow's note",
        function()
            roam.ext.dailies.capture_tomorrow()
        end
    )

    assign(
        bindings.capture_yesterday,
        "Capture yesterday's note",
        function()
            roam.ext.dailies.capture_yesterday()
        end
    )

    assign(
        bindings.find_directory,
        "Navigate to dailies note directory",
        function()
            roam.ext.dailies.find_directory()
        end
    )

    assign(
        bindings.goto_date,
        "Navigate to a specific date's note",
        function()
            roam.ext.dailies.goto_date()
        end
    )

    assign(
        bindings.goto_today,
        "Navigate to today's note",
        function()
            roam.ext.dailies.goto_today()
        end
    )

    assign(
        bindings.goto_tomorrow,
        "Navigate to tomorrow's note",
        function()
            roam.ext.dailies.goto_tomorrow()
        end
    )

    assign(
        bindings.goto_yesterday,
        "Navigate to yesterday's note",
        function()
            roam.ext.dailies.goto_yesterday()
        end
    )

    assign(
        bindings.goto_next_date,
        "Navigate to the next available note",
        function()
            roam.ext.dailies.goto_next_date()
        end
    )

    assign(
        bindings.goto_prev_date,
        "Navigate to the previous available note",
        function()
            roam.ext.dailies.goto_prev_date()
        end
    )
end

---@param roam OrgRoam
return function(roam)
    assign_core_keybindings(roam)
    assign_dailies_keybindings(roam)
end
