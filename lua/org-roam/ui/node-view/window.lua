-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Specialized window representing an org-roam buffer for a particular node.
-------------------------------------------------------------------------------

local async = require("org-roam.core.utils.async")
local database = require("org-roam.database")
local Emitter = require("org-roam.core.utils.emitter")
local io = require("org-roam.core.utils.io")
local notify = require("org-roam.core.ui.notify")
local utils = require("org-roam.utils")
local Window = require("org-roam.core.ui.window")

local EVENTS = {
    REFRESH = "refresh",
}

---Cache of files that we've loaded for previewing contents.
---NOTE: We do not populate paths, but this is okay as we can
---      still load individual files, which get cached.
---@type OrgFiles
local ORG_FILES = require("orgmode.files"):new({ paths = {} })

---Cache of key -> lines that persists across all windows.
---Key is `path.row.col`.
---@type table<string, {sha256:string, lines:string[]}>
local CACHE = {}

---Global event emitter to ensure all windows stay accurate.
local EMITTER = Emitter:new()

---Loads file at `path` and figures out the lines of text to use for a preview.
---@param path string
---@param cursor {[1]:integer, [2]:integer} # cursor position indexed (1, 0)
---@return string[]
local function load_lines_at_cursor(path, cursor)
    -- Make zero-indexed row and column from cursor
    local row, col = cursor[1] - 1, cursor[2]

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
    local key = string.format("%s.%s.%s", path, row, col)
    local lines = (CACHE[key] or {}).lines or {}

    -- Kick off a reload of lines
    ORG_FILES:load_file(path):next(function(file)
        -- Calculate a digest and see if its different
        local sha256 = vim.fn.sha256(file.content)
        local is_new = not CACHE[key] or CACHE[key].sha256 ~= sha256

        -- If our file has changed, re-render
        if is_new then
            EMITTER:emit(EVENTS.REFRESH)
        end

        -- Update our cache
        CACHE[key] = {
            sha256 = sha256,
            lines = file_to_lines(file),
        }

        return file
    end)

    return lines
end

---Renders a node within an orgmode buffer.
---@param node org-roam.core.database.Node|org-roam.core.database.Id
---@return org-roam.core.ui.Line[] lines
local function render(node)
    local db = database()

    ---@type org-roam.core.ui.Line[]
    local lines = {}

    -- If given an id instead of a node, load it here
    if type(node) == "string" then
        node = db:get(node)
    end

    if node then
        -- Insert a full line that contains the node's title
        table.insert(lines, string.format("# %s", node.title))

        -- Insert a blank line as a divider
        table.insert(lines, "")

        -- Insert a multi-highlighted line for backlinks
        local backlinks = db:get_backlinks(node.id)
        table.insert(
            lines,
            string.format("* Backlinks (%s)", vim.tbl_count(backlinks))
        )

        for backlink_id, _ in pairs(backlinks) do
            ---@type org-roam.core.database.Node|nil
            local backlink_node = db:get(backlink_id)

            if backlink_node then
                local locs = backlink_node.linked[node.id]
                for _, loc in ipairs(locs or {}) do
                    -- One-indexed row/column
                    local row = loc.row + 1
                    local col = loc.column + 1

                    -- Insert line containing node's title and line location
                    table.insert(
                        lines,
                        string.format(
                            "** [[file://%s::%s][%s @ line %s]]",
                            backlink_node.file,
                            row,
                            backlink_node.title,
                            row
                        )
                    )

                    vim.list_extend(lines, load_lines_at_cursor(
                        node.file, { row, col - 1 }
                    ))

                    -- Add a blank line to separate post content
                    table.insert(lines, "")
                end
            end
        end
    end

    return lines
end

---@class org-roam.ui.window.NodeViewWindow
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

    EMITTER:on(EVENTS.REFRESH, function()
        -- NOTE: We MUST schedule this and not render directly
        --       as that will fail with api calls not allowed
        --       in our fast loop!
        vim.schedule(function()
            instance:render()
        end)
    end)

    -- Hard-code the widgets list to be our custom renderer that uses
    -- the id we provided or looks up the id whenever render is called
    local widgets = {}
    local id = opts.id
    local name = vim.fn.tempname() .. "-roam-node-view.org"
    if id then
        table.insert(widgets, function()
            return render(id)
        end)
    else
        ---@type org-roam.core.database.Node|nil
        local last_node = nil

        table.insert(widgets, function()
            local node = last_node

            -- Only refresh if we are in a different buffer
            -- NOTE: orgmode plugin prepends our directory in front of the name
            --       so we have to check if the name ends with our name.
            if not vim.endswith(vim.api.nvim_buf_get_name(0), name) then
                ---@type org-roam.core.database.Node|nil
                node = async.wait(utils.node_under_cursor)
            end

            if node then
                last_node = node
                return render(node)
            else
                return {}
            end
        end)
    end

    local window = Window:new(vim.tbl_extend("keep", {
        bufopts = {
            name = name,
            filetype = "org",
            modifiable = false,
            buftype = "nofile",
            swapfile = false,
            bufhidden = "delete", -- Completely remove the buffer once hidden
        },
        widgets = widgets,
    }, opts))
    instance.__window = window

    -- TODO: This is a hack to get orgmode to work properly for a "fake" buffer.
    --[[ window:buffer():on_post_render(function()
        local text = table.concat(vim.api.nvim_buf_get_lines(window:bufnr(), 0, -1, true), "\n")
        io.write_file(window:buffer():name(), text, function(err)
            if err then
                notify.debug("failed persisting node-view buffer: " .. err)
            end
        end)
    end) ]]

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

---Opens the window if closed, or closes if open.
function M:toggle()
    if self.__window then
        return self.__window:toggle()
    end
end

---Re-renders the window manually.
function M:render()
    if self.__window then
        self.__window:render()
    end
end

return M
