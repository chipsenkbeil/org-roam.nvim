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
local tbl_utils = require("org-roam.core.utils.table")
local utils = require("org-roam.utils")
local Window = require("org-roam.core.ui.window")

local EVENTS = {
    CACHE_UPDATED = "cache-updated",
}

---@param cache table<string, {mtime:integer, queued:boolean, lines:string[]}>
---@param opts {emitter:org-roam.core.utils.Emitter, id:org-roam.core.database.Id, path:string, row:integer, col:integer}
---@return org-roam.core.ui.Line[]
local function get_cached_lines(cache, opts)
    local lines = {}
    local key = string.format("%s.%s.%s", opts.id, opts.row, opts.col)
    local item = cache[key]

    -- Populate the lines, or add a placeholder if not available
    if item and item.lines and item.mtime > 0 then
        vim.list_extend(lines, item.lines)
    else
        table.insert(lines, "<LOADING>")
    end

    -- If cached item doesn't exist, create a filler
    item = item or { mtime = 0, queued = false, lines = {} }
    cache[key] = item

    -- Schedule a check to see if the file has changed since we last fetched
    if not item.queued then
        item.queued = true

        vim.schedule(function()
            io.stat(opts.path, function(err, stat)
                if err then
                    item.queued = false
                    notify.error(err)
                    return
                end

                ---@cast stat -nil
                local mtime = stat.mtime.sec

                -- If the file has been modified since last checked,
                -- read the contents again to populate our cache
                if item.mtime < mtime then
                    item.mtime = mtime

                    -- NOTE: Loading a file cannot be done within the results of a stat,
                    --       so we need to schedule followup work.
                    vim.schedule(function()
                        require("orgmode.files")
                            :new({ paths = opts.path })
                            :load_file(opts.path)
                            :next(function(file)
                                ---@cast file OrgFile
                                -- Figure out where we are located as there are several situations
                                -- where we load content differently to preview:
                                --
                                -- 1. If we are in a list, we return the entire list (list)
                                -- 2. If we are in a heading, we return the heading's text (item)
                                -- 3. If we are in a paragraph, we return the entire paragraph (paragraph)
                                -- 4. If we are in a drawer, we return the entire drawer (drawer)
                                -- 5. If we are in a property drawer, we return the entire drawer (property_drawer)
                                -- 5. If we are in a table, we return the entire table (table)
                                -- 5. Otherwise, just return the line where we are
                                local node = file:get_node_at_cursor({ opts.row, opts.col - 1 })
                                local container_types = {
                                    "paragraph", "list", "item", "table", "drawer", "property_drawer",
                                }
                                while node and not vim.tbl_contains(container_types, node:type()) do
                                    node = node:parent()

                                    local ty = node and node:type() or ""
                                    local pty = node:parent() and node:parent():type() or ""

                                    -- Check if we're actually in a list item and advance up out of paragraph
                                    if ty == "paragraph" and pty == "listitem" then
                                        node = node:parent()
                                    end
                                end

                                if not node then
                                    return file
                                end

                                -- Load the text and split it by line
                                local text = file:get_node_text(node)
                                item.lines = vim.split(text, "\n", { plain = true })
                                item.queued = false

                                -- Schedule a re-render at this point
                                opts.emitter:emit(EVENTS.CACHE_UPDATED)
                                return file
                            end)
                    end)
                end
            end)
        end)
    end

    return lines
end

---Renders a node within an orgmode buffer.
---@param node org-roam.core.database.Node|org-roam.core.database.Id
---@param emitter org-roam.core.utils.Emitter
---@param cache table<string, {mtime:integer, queued:boolean, lines:string[]}>
---@return org-roam.core.ui.Line[] lines
local function render(node, emitter, cache)
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

                    vim.list_extend(lines, get_cached_lines(cache, {
                        emitter = emitter,
                        id = node.id,
                        path = node.file,
                        row = row,
                        col = col,
                    }))

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

    local emitter = Emitter:new()
    emitter:on(EVENTS.CACHE_UPDATED, function()
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
    local cache = {}
    local name = "org-roam-node-view-cursor.org"
    if id then
        name = "org-roam-node-view-id-" .. id .. ".org"
        table.insert(widgets, function()
            return render(id, emitter, cache)
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
                return render(node, emitter, cache)
            else
                return {}
            end
        end)
    end

    instance.__window = Window:new(vim.tbl_extend("keep", {
        bufopts = {
            name = name,
            filetype = "org",
        },
        widgets = widgets,
    }, opts))

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
