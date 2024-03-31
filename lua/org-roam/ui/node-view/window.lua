-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Specialized window representing an org-roam buffer for a particular node.
-------------------------------------------------------------------------------

local C = require("org-roam.core.ui.component")
local db = require("org-roam.database")
local Emitter = require("org-roam.core.utils.emitter")
local notify = require("org-roam.core.ui.notify")
local tbl_utils = require("org-roam.core.utils.table")
local Window = require("org-roam.core.ui.window")
local WindowPicker = require("org-roam.core.ui.window-picker")

local EVENTS = {
    REFRESH = "refresh",
}

---Mapping of kind -> highlight group.
local HL = {
    NODE_TITLE    = "Title",
    SECTION_LABEL = "Title",
    SECTION_COUNT = "Normal",
    LINK_TITLE    = "Title",
    LINK_LOCATION = "Identifier",
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

---Loads file at `path` and figures out the lines of text to use for a preview.
---@param path string
---@param cursor {[1]:integer, [2]:integer} # cursor position indexed (1, 0)
---@return org-roam.core.ui.Line[]
local function load_lines_at_cursor(path, cursor)
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

        -- Load the text and split it by line
        local text = file:get_node_text(node)
        return vim.split(text, "\n", { plain = true })
    end

    -- Get the lines that are available right now
    local key = string.format("%s.%s.%s", path, cursor[1], cursor[2])
    local lines = (CACHE[key] or {}).lines or {}

    -- Kick off a reload of lines
    require("org-roam.database"):load_file({
        path = path
    }, function(err, results)
        if err then
            notify.error(err)
            return
        end

        -- Calculate a digest and see if its different
        ---@cast results -nil
        local sha256 = vim.fn.sha256(results.file.content)
        local is_new = not CACHE[key] or CACHE[key].sha256 ~= sha256

        -- Update our cache
        CACHE[key] = {
            sha256 = sha256,
            lines = file_to_lines(results.file),
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
    end)

    ---@param line string
    return vim.tbl_map(function(line)
        -- TODO: How can we parse lines to get their highlight groups
        --       and build out our span of highlighted segments?
        return { C.text(line) }
    end, lines)
end

---@class org-roam.ui.window.NodeViewWindowState
---@field expanded table<org-roam.core.database.Id, table<integer, table<integer, boolean>>> #mapping of id -> zero-indexed row -> col -> boolean

---Renders a node within an orgmode buffer.
---@param this org-roam.ui.window.NodeViewWindow
---@param node org-roam.core.file.Node|org-roam.core.database.Id
---@return org-roam.core.ui.Line[] lines
local function render(this, node)
    ---@diagnostic disable-next-line:invisible
    local state = this.__state

    ---@type org-roam.core.ui.Line[]
    local lines = {}

    -- If given an id instead of a node, load it here
    if type(node) == "string" then
        ---@diagnostic disable-next-line:cast-local-type
        node = db:get_sync(node)
    end

    if node then
        -- Insert a full line that contains the node's title
        table.insert(lines, { C.hl(node.title, HL.NODE_TITLE) })

        -- Insert a blank line as a divider
        table.insert(lines, "")

        -- Insert a multi-highlighted line for backlinks
        local backlinks = db:get_backlinks(node.id)
        table.insert(lines, {
            C.hl("Backlinks", HL.SECTION_LABEL),
            C.hl(" (" .. vim.tbl_count(backlinks) .. ")", HL.SECTION_COUNT),
        })

        for backlink_id, _ in pairs(backlinks) do
            local backlink_node = db:get_sync(backlink_id)

            if backlink_node then
                local locs = backlink_node.linked[node.id]
                for _, loc in ipairs(locs or {}) do
                    -- One-indexed row/column
                    local row = loc.row + 1
                    local col = loc.column + 1

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
                                vim.cmd.edit(backlink_node.file)

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
                    table.insert(lines, {
                        line,
                        C.action("<Tab>", do_expand),
                        C.action("<Enter>", do_open),
                    })


                    -- If we have toggled for this location, show the preview
                    if is_expanded then
                        vim.list_extend(lines, load_lines_at_cursor(
                            backlink_node.file, { row, col - 1 }
                        ))
                    end
                end
            end
        end
    end

    return lines
end

---@class org-roam.ui.window.NodeViewWindow
---@field private __id org-roam.core.database.Id|nil
---@field private __state org-roam.ui.window.NodeViewWindowState
---@field private __window org-roam.core.ui.Window
local M = {}
M.__index = M

---@class org-roam.ui.window.NodeViewWindowOpts
---@field id? org-roam.core.database.Id
---@field open? string|fun():integer
---@field winopts? table<string, any>

---Creates a new node-view window.
---@param opts? org-roam.ui.window.NodeViewWindowOpts
---@return org-roam.ui.window.NodeViewWindow
function M:new(opts)
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
                return render(instance, id)
            else
                return {}
            end
        end
    end)()

    local window = Window:new(vim.tbl_extend("keep", {
        bufopts = {
            filetype = "org-roam-node-view",
            modifiable = false,
            buftype = "nofile",
            swapfile = false,
        },
        components = { cached_render },
    }, opts))
    instance.__window = window

    vim.api.nvim_create_autocmd("BufReadCmd", {
        buffer = window:bufnr(),
        callback = function()
            -- NOTE: Perform blocking as we need to populate immediately.
            window:render({ sync = true })
        end,
    })

    -- When our window first opens, trigger a refresh
    window:on_open(function()
        EMITTER:emit(EVENTS.REFRESH)
    end)

    EMITTER:on(EVENTS.REFRESH, function(refresh_opts)
        -- NOTE: We MUST schedule this and not render directly
        --       as that will fail with api calls not allowed
        --       in our fast loop!
        vim.schedule(function()
            window:render(refresh_opts)
        end)
    end)

    return instance
end

---Opens the window.
---@return integer handle
function M:open()
    return self.__window:open()
end

---Closes the window if it is open.
function M:close()
    if self.__window then
        self.__window:close()
    end
end

---@return boolean
function M:is_open()
    if self.__window then
        return self.__window:is_open()
    else
        return false
    end
end

---@return boolean
function M:has_original_buffer()
    if self.__window then
        return self.__window:has_original_buffer()
    else
        return false
    end
end

---Opens the window if closed, or closes if open.
function M:toggle()
    if self.__window then
        return self.__window:toggle()
    end
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

return M
