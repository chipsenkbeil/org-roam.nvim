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

local EVENTS = {
    CACHE_UPDATED = "cache-updated",
}

---@param cache table<string, {mtime:integer, queued:boolean, lines:string[]}>
---@param opts {emitter:org-roam.core.utils.Emitter, id:org-roam.core.database.Id, path:string, row:integer, col:integer, n:integer, prefix:string}
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

                    ---@diagnostic disable-next-line:redefined-local
                    io.read_file(opts.path, function(err, data)
                        item.queued = false

                        if err then
                            notify.error(err)
                            return
                        end

                        ---@cast data -nil
                        ---@diagnostic disable-next-line:redefined-local
                        local lines = vim.split(data, "\n", { plain = true })
                        local start = math.max(opts.row - opts.n, 1)
                        local end_ = math.min(opts.row + opts.n, #lines)
                        item.lines = vim.list_slice(lines, start, end_)

                        -- Clean up our lines by finding the minimum leading whitespace
                        -- and removing it from each line
                        local cnt = math.min(tbl_utils.unpack(vim.tbl_map(function(line)
                            local cnt = 0
                            for c in string.gmatch(line, ".") do
                                if c ~= " " and c ~= "\t" then
                                    break
                                end
                                cnt = cnt + 1
                            end
                            return cnt
                        end, item.lines)))

                        for i = 1, #item.lines do
                            item.lines[i] = string.sub(item.lines[i], cnt + 1)
                        end

                        -- Schedule a re-render at this point
                        opts.emitter:emit(EVENTS.CACHE_UPDATED)
                    end)
                end
            end)
        end)
    end

    local max_line_len = math.max(tbl_utils.unpack(vim.tbl_map(function(line)
        return string.len(line)
    end, lines)))

    return vim.tbl_map(function(line)
        local padding = math.max(0, max_line_len - string.len(line))
        return {
            { opts.prefix,              HL.NORMAL },
            { line,                     HL.PREVIEW_LINE },
            { string.rep(" ", padding), HL.PREVIEW_LINE },
        }
    end, lines)
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
        table.insert(lines, { { node.title, HL.NODE_TITLE } })

        -- Insert a blank line as a divider
        table.insert(lines, "")

        -- Insert a multi-highlighted line for backlinks
        local backlinks = db:get_backlinks(node.id)
        local bcnt = vim.tbl_count(backlinks)
        table.insert(lines, {
            { "Backlinks",         HL.SECTION_LABEL },
            { " (" .. bcnt .. ")", HL.SECTION_COUNT },
        })

        for backlink_id, _ in pairs(backlinks) do
            ---@type org-roam.core.database.Node|nil
            local backlink_node = db:get(backlink_id)

            if backlink_node then
                local locs = backlink_node.linked[node.id]
                for _, loc in ipairs(locs or {}) do
                    local row = loc.row + 1
                    local col = loc.column + 1

                    -- Insert line containing node's title and line location
                    table.insert(lines, {
                        { backlink_node.title,       HL.LINK_TITLE },
                        { " ",                       HL.NORMAL },
                        { "@ " .. row .. "," .. col, HL.LINK_LOCATION },
                    })

                    -- Add a blank line before content
                    table.insert(lines, "")

                    vim.list_extend(lines, get_cached_lines(cache, {
                        emitter = emitter,
                        id = node.id,
                        path = node.file,
                        row = row,
                        col = col,
                        n = 1,         -- lines to show above and below
                        prefix = "  ", -- prefix to add to each line
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
    local name = "org-roam-node-view-cursor"
    if id then
        name = "org-roam-node-view-id-" .. id
        table.insert(widgets, function()
            return render(id, emitter, cache)
        end)
    else
        table.insert(widgets, function()
            ---@type org-roam.core.database.Node|nil
            local node = async.wait(utils.node_under_cursor)
            if node then
                return render(node, emitter, cache)
            else
                return {}
            end
        end)
    end

    instance.__window = Window:new(vim.tbl_extend("keep", {
        bufopts = {
            name = name,
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
