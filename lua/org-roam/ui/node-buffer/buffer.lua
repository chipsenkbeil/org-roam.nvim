-------------------------------------------------------------------------------
-- BUFFER.LUA
--
-- Specialized buffer representing an org-roam buffer for a particular node.
-------------------------------------------------------------------------------

local Buffer = require("org-roam.core.ui.buffer")
local C = require("org-roam.core.ui.component")
local Emitter = require("org-roam.core.utils.emitter")
local highlighter = require("org-roam.core.ui.highlighter")
local notify = require("org-roam.core.ui.notify")
local tbl_utils = require("org-roam.core.utils.table")
local WindowPicker = require("org-roam.core.ui.window-picker")

local EVENTS = {
    REFRESH = "refresh",
}

local KEYBINDINGS = {
    OPEN_LINK = {
        key = "<Enter>",
        desc = "open a link in another window",
        order = 1,
    },
    EXPAND = {
        key = "<Tab>",
        desc = "expand/collapse a link",
        order = 2,
    },
    EXPAND_ALL = {
        key = "<S-Tab>",
        desc = "expand/collapse all links",
        order = 3,
    },
    REFRESH_BUFFER = {
        key = "<C-r>",
        desc = "refresh buffer",
        order = 4,
    },
}

---Mapping of kind -> highlight group.
local HL = {
    NODE_TITLE    = "Title",
    NODE_ORIGIN   = "Title",
    COMMENT       = "Comment",
    KEYBINDING    = "WarningMsg",
    SECTION_LABEL = "Title",
    SECTION_COUNT = "Normal",
    LINK_TITLE    = "Title",
    LINK_LOCATION = "WarningMsg",
    NORMAL        = "Normal",
    PREVIEW_LINE  = "PMenu",
}

---Mapping of kind -> icon.
local ICONS = {
    ---Shown next to a link when the preview is visible.
    EXPANDED_PREVIEW = "▼",

    ---Shown next to a link when the preview is invisible.
    UNEXPANDED_PREVIEW = "▶",
}

---Cache of key -> lines that persists across all windows.
---Key is `path.row.col`.
---@type table<string, {sha256:string, lines:string[]}>
local CACHE = {}

---Global event emitter to ensure all windows stay accurate.
local EMITTER = Emitter:new()

---Highlights lazy ranges in the window as org syntax.
---
---NOTE: This function must be the same for global highlighting to work, so define it here
---@param buf integer
---@param ns_id integer
---@param ranges {[1]:integer, [2]:integer}[] # (start, end) base-zero, end-exclusive
local function lazy_highlight_for_org(buf, ns_id, ranges)
    highlighter.highlight_ranges_as_org(buf, ranges, {
        ephemeral = true,
        namespace = ns_id,
    })
end

---Loads file at `path` and figures out the lines of text to use for a preview.
---@param roam OrgRoam
---@param path string
---@param cursor {[1]:integer, [2]:integer} # cursor position indexed (1, 0)
---@return org-roam.core.ui.Line[]
local function load_lines_at_cursor(roam, path, cursor)
    ---Figures out where we are located and retrieves relevant lines.
    ---
    ---Previews can be calculated in a variety of ways:
    ---1. If we are in a directive, we return the entire directive (directive)
    ---2. If we are in a list, we return the entire list (list)
    ---3. If we are in a heading, we return the heading's text (item)
    ---4. If we are in a paragraph, we return the entire paragraph (paragraph)
    ---5. If we are in a drawer, we return the entire drawer (drawer)
    ---6. If we are in a property drawer, we return the entire drawer (property_drawer)
    ---7. If we are in a table, we return the entire table (table)
    ---8. Otherwise, capture the entire element and return it (element)
    ---@param file OrgFile
    ---@return string[]
    local function file_to_lines(file)
        local node = file:get_node_at_cursor(cursor)
        local container_types = {
            "directive",
            "list",
            "item",
            "paragraph",
            "drawer",
            "property_drawer",
            "table",
            "element", -- This should be a catchall
        }

        while node and not vim.tbl_contains(container_types, node:type()) do
            node = node:parent()

            local ty = node and node:type() or ""
            local pty = node and node:parent() and node:parent():type() or ""

            -- Check if we're actually in a list item and advance up out of paragraph
            if ty == "paragraph" and pty == "listitem" then
                node = node:parent()
            end
        end

        if not node then
            return {}
        end

        -- Load the text and split it by line, removing
        -- any starting or ending blank links
        local text = file:get_node_text(node)
        text = string.gsub(text, "^%s*\n", "")
        text = string.gsub(text, "\n%s*$", "")
        return vim.split(text, "\n", { plain = true })
    end

    -- Get the lines that are available right now
    local key = string.format("%s.%s.%s", path, cursor[1], cursor[2])
    local lines = (CACHE[key] or {}).lines or {}

    -- Kick off a reload of lines
    roam.db
        :load_file({ path = path })
        :next(function(results)
            local file = results.file

            -- Calculate a digest and see if its different
            ---@cast file -nil
            local sha256 = vim.fn.sha256(file.content)
            local is_new = not CACHE[key] or CACHE[key].sha256 ~= sha256

            -- Update our cache
            CACHE[key] = {
                sha256 = sha256,
                lines = file_to_lines(file),
            }

            -- If our file has changed, re-render
            if is_new then
                -- NOTE: Introduce a delay before the refresh as this can
                --       trigger refreshing while the buffer is rendering,
                --       which would result in the refresh being discarded
                --       and the update not actually taking place.
                vim.defer_fn(function()
                    EMITTER:emit(EVENTS.REFRESH)
                end, 100)
            end

            return results
        end)
        :catch(function(err) notify.error(err) end)

    ---@param line string
    return vim.tbl_map(function(line)
        -- Because this can have a performance hit & flickering, we only
        -- do lazy highlighting as org syntax if enabled
        if roam.config.ui.node_buffer.highlight_previews then
            return C.lazy(line, lazy_highlight_for_org, { global = true })
        else
            return { C.text(line) }
        end
    end, lines)
end

---@class org-roam.ui.NodeBufferState
---@field expanded table<org-roam.core.database.Id, table<integer, table<integer, boolean>>> #mapping of id -> zero-indexed row -> col -> boolean

---Renders a node within an orgmode buffer.
---@param roam OrgRoam
---@param this org-roam.ui.NodeBuffer
---@param node org-roam.core.file.Node|org-roam.core.database.Id
---@param details {fixed:boolean}
---@return org-roam.core.ui.Line[] lines
local function render(roam, this, node, details)
    ---@diagnostic disable-next-line:invisible
    local state = this.__state

    ---@type org-roam.core.ui.Line[]
    local lines = {}

    -- If given an id instead of a node, load it here
    if type(node) == "string" then
        ---@diagnostic disable-next-line:cast-local-type
        node = roam.db:get_sync(node)
    end

    if node then
        -- Insert lines explaining available keys (if enabled)
        if roam.config.ui.node_buffer.show_keybindings then
            -- Get our bindings to display in help, in
            -- a defined and consistent order
            local bindings = vim.tbl_values(KEYBINDINGS)
            table.sort(bindings, function(a, b) return a.order < b.order end)

            for _, binding in ipairs(bindings) do
                table.insert(lines, {
                    C.hl("Press ", HL.COMMENT),
                    C.hl(binding.key, HL.KEYBINDING),
                    C.hl(" to " .. binding.desc, HL.COMMENT),
                })
            end

            -- Insert a blank line as a divider
            table.insert(lines, "")
        end

        -- Insert a full line that contains the node's title
        table.insert(lines, {
            C.hl(
                string.format("%sNode: ", details.fixed and "Fixed " or ""),
                HL.NORMAL
            ),
            C.hl(node.title, HL.NODE_TITLE),
        })

        -- If we have an origin for the node, display it next
        if node.origin then
            local origin_node = roam.db:get_sync(node.origin)
            if origin_node then
                local function do_open()
                    local win = vim.api.nvim_get_current_win()
                    local filter = function(winnr) return winnr ~= win end

                    WindowPicker
                        :new({
                            autoselect = true,
                            filter = filter,
                        })
                        :on_choice(function(winnr)
                            roam.utils.goto_node({
                                node = origin_node,
                                win = winnr,
                            })
                        end)
                        :open()
                end

                table.insert(lines, {
                    C.hl(
                        "Origin: ",
                        HL.NORMAL
                    ),
                    C.hl(origin_node.title, HL.NODE_ORIGIN),
                    C.action(KEYBINDINGS.OPEN_LINK.key, do_open),
                })
            end
        end

        -- Insert a blank line as a divider
        table.insert(lines, "")

        -- Ensure our rendering of backlinks is a consistent order
        local backlink_ids = vim.tbl_keys(roam.db:get_backlinks(node.id))
        table.sort(backlink_ids)

        local function do_expand_all()
            if not state.expanded then
                state.expanded = {}
            end
            local is_expanded
            for _, backlink_id in pairs(backlink_ids) do
                local backlink_node = roam.db:get_sync(backlink_id)

                if backlink_node then
                    local locs = backlink_node.linked[node.id]
                    for _, loc in ipairs(locs or {}) do
                        -- Zero-indexed row/column
                        local row = loc.row
                        local col = loc.column

                        -- Get the expanded state of the first link to use for everything
                        if is_expanded == nil then
                            is_expanded =
                                tbl_utils.get(state.expanded, backlink_node.id, row, col)
                                or false
                        end

                        if not state.expanded[backlink_node.id] then
                            state.expanded[backlink_node.id] = {}
                        end

                        if not state.expanded[backlink_node.id][row] then
                            state.expanded[backlink_node.id][row] = {}
                        end

                        state.expanded[backlink_node.id][row][col] = not is_expanded
                    end
                end
            end
            EMITTER:emit(EVENTS.REFRESH)
        end

        local backlink_lines = {}
        local backlink_links_cnt = 0
        for _, backlink_id in ipairs(backlink_ids) do
            local backlink_node = roam.db:get_sync(backlink_id)

            if backlink_node then
                local locs = backlink_node.linked[node.id]
                for i, loc in ipairs(locs or {}) do
                    -- Check if we are only showing one link
                    -- per node as per configuration
                    if i > 1 and roam.config.ui.node_buffer.unique then
                        break
                    end

                    -- One-indexed row/column
                    local row = loc.row + 1
                    local col = loc.column + 1

                    -- Update the total links we have
                    backlink_links_cnt = backlink_links_cnt + 1

                    ---@type boolean
                    local is_expanded = tbl_utils.get(
                        state.expanded,
                        backlink_node.id,
                        row - 1,
                        col - 1
                    ) or false

                    local function do_expand()
                        if not state.expanded then
                            state.expanded = {}
                        end

                        if not state.expanded[backlink_node.id] then
                            state.expanded[backlink_node.id] = {}
                        end

                        if not state.expanded[backlink_node.id][row - 1] then
                            state.expanded[backlink_node.id][row - 1] = {}
                        end

                        state.expanded[backlink_node.id][row - 1][col - 1] = not is_expanded
                        EMITTER:emit(EVENTS.REFRESH)
                    end

                    local function do_open()
                        local win = vim.api.nvim_get_current_win()
                        local filter = function(winnr) return winnr ~= win end

                        WindowPicker
                            :new({
                                autoselect = true,
                                filter = filter,
                            })
                            :on_choice(function(winnr)
                                vim.api.nvim_set_current_win(winnr)
                                vim.cmd("e " .. backlink_node.file)

                                -- NOTE: We need to schedule to ensure the file has loaded
                                --       into the buffer before we try to move the cursor!
                                vim.schedule(function()
                                    vim.api.nvim_win_set_cursor(winnr, { row, col - 1 })
                                end)
                            end)
                            :open()
                    end

                    -- Get prefix based on expansion status
                    local prefix = C.hl(ICONS.UNEXPANDED_PREVIEW, HL.LINK_TITLE)
                    if is_expanded then
                        prefix = C.hl(ICONS.EXPANDED_PREVIEW, HL.LINK_TITLE)
                    end

                    local line = C.group(
                        prefix,
                        C.text(" "),
                        C.hl(backlink_node.title, HL.LINK_TITLE),
                        C.text(" "),
                        C.hl("@ " .. row .. "," .. col - 1, HL.LINK_LOCATION)
                    )

                    -- Insert line containing node's title and line location
                    table.insert(backlink_lines, {
                        line,
                        C.action(KEYBINDINGS.EXPAND.key, do_expand),
                        C.action(KEYBINDINGS.OPEN_LINK.key, do_open),
                    })

                    -- If we have toggled for this location, show the preview
                    if is_expanded then
                        vim.list_extend(backlink_lines, load_lines_at_cursor(
                            roam, backlink_node.file, { row, col - 1 }
                        ))
                    end
                end
            end
        end

        -- Add backlinks section
        table.insert(lines, {
            C.hl("Backlinks", HL.SECTION_LABEL),
            C.hl(" (" .. backlink_links_cnt .. ")", HL.SECTION_COUNT),
        })
        vim.list_extend(lines, backlink_lines)

        -- Add some global actions: keybindings that can be used anywhere
        table.insert(lines, {
            C.action(
                KEYBINDINGS.EXPAND_ALL.key,
                do_expand_all,
                { global = true }
            ),
            C.action(
                KEYBINDINGS.REFRESH_BUFFER.key,
                function()
                    highlighter.clear_cache()
                    EMITTER:emit(EVENTS.REFRESH, { force = true })
                end,
                { global = true }
            ),
        })
    end

    return lines
end

---@class org-roam.ui.NodeBuffer
---@field private __buffer org-roam.core.ui.Buffer
---@field private __id org-roam.core.database.Id|nil
---@field private __state org-roam.ui.NodeBufferState
local M = {}
M.__index = M

---Creates a new node-view buffer.
---@param roam OrgRoam
---@param opts? {id?:org-roam.core.database.Id}
---@return org-roam.ui.NodeBuffer
function M:new(roam, opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)

    instance.__id = opts.id
    instance.__state = { expanded = {} }

    ---Cached instance of render that maintains the last id rendered
    ---if our window suddenly loses any viable target.
    local cached_render = (function()
        ---@type org-roam.core.database.Id|nil
        local last_id = nil

        ---@return org-roam.core.ui.Line[]
        return function()
            local id = instance.__id or last_id
            last_id = id
            if id then
                return render(roam, instance, id, { fixed = opts.id ~= nil })
            else
                return {}
            end
        end
    end)()

    local buffer = Buffer:new({
        filetype = "org-roam-node-buffer",
        modifiable = false,
        buftype = "nofile",
        swapfile = false,
    }):add_component(cached_render)
    instance.__buffer = buffer

    -- For this kind of buffer, always force normal mode.
    -- NOTE: This exists because fixed node buffers seem
    --       to start in insert mode.
    vim.api.nvim_create_autocmd("BufEnter", {
        buffer = buffer:bufnr(),
        callback = function()
            vim.cmd("stopinsert")
        end,
    })

    vim.api.nvim_create_autocmd("BufReadCmd", {
        buffer = buffer:bufnr(),
        callback = function()
            -- NOTE: Perform blocking as we need to populate immediately.
            buffer:render({ sync = true })
        end,
    })

    EMITTER:on(EVENTS.REFRESH, function(refresh_opts)
        -- NOTE: We MUST schedule this and not render directly
        --       as that will fail with api calls not allowed
        --       in our fast loop!
        vim.schedule(function()
            buffer:render(refresh_opts)
        end)
    end)

    return instance
end

---@return org-roam.core.database.Id|nil
function M:get_id()
    return self.__id
end

---@param id org-roam.core.database.Id|nil
function M:set_id(id)
    local is_new_id = id ~= nil and id ~= self.__id

    self.__id = id

    if is_new_id then
        EMITTER:emit(EVENTS.REFRESH)
    end
end

---@return integer
function M:bufnr()
    return self.__buffer:bufnr()
end

---@return boolean
function M:is_valid()
    return self.__buffer:is_valid()
end

---@return integer[]
function M:windows()
    return self.__buffer:windows()
end

---@param tabpage integer
---@return integer[]
function M:windows_for_tabpage(tabpage)
    return self.__buffer:windows_for_tabpage(tabpage)
end

---@return org-roam.core.ui.Buffer
function M:to_internal_buffer()
    return self.__buffer
end

return M
