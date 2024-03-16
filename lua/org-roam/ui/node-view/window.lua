-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Specialized window representing an org-roam buffer for a particular node.
-------------------------------------------------------------------------------

local async = require("org-roam.core.utils.async")
local database = require("org-roam.database")
local utils = require("org-roam.utils")
local Window = require("org-roam.core.ui.window")

---Renders a node within an orgmode buffer.
---@param node org-roam.core.database.Node|org-roam.core.database.Id
---@return org-roam.core.ui.Line[] lines
local function render(node)
    local db = database()

    ---@type org-roam.core.ui.Line[]
    local lines = {}

    ---@param ... string
    local function append(...)
        vim.list_extend(lines, { ... })
    end

    -- If given an id instead of a node, load it here
    if type(node) == "string" then
        node = db:get(node)
    end

    if node then
        -- Insert a full line that contains the node's title
        table.insert(lines, { { node.title, "Title" } })

        -- Insert a multi-highlighted line for backlinks
        local backlinks = db:get_backlinks(node.id)
        local bcnt = vim.tbl_count(backlinks)
        table.insert(lines, {
            { "Backlinks",         "Title" },
            { " (" .. bcnt .. ")", "Normal" },
        })

        for backlink_id, _ in pairs(backlinks) do
            ---@type org-roam.core.database.Node|nil
            local backlink_node = db:get(backlink_id)

            if backlink_node then
                local locs = backlink_node.linked[node.id]
                for _, loc in ipairs(locs or {}) do
                    local line = loc.row + 1

                    -- Insert line containing node's title and (top)
                    table.insert(lines, {
                        { backlink_node.title, "Title" },
                        { " ",                 "Normal" },
                        { "@ line " .. line,   "Identifier" },
                        { " (",                "Normal" },
                        { "top",               "Comment" },
                        { ")",                 "Normal" },
                    })

                    -- TODO: Insert the content for the file at the position
                    table.insert(lines, "TODO: line content")
                    table.insert(lines, "TODO: line content")
                    table.insert(lines, "TODO: line content")

                    -- Add a blank line to separate
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

    -- Hard-code the widgets list to be our custom renderer that uses
    -- the id we provided or looks up the id whenever render is called
    local widgets = {}
    local id = opts.id
    local name = "org-roam-node-view-cursor"
    if id then
        name = "org-roam-node-view-id-" .. id
        table.insert(widgets, function()
            return render(id)
        end)
    else
        table.insert(widgets, function()
            ---@type org-roam.core.database.Node|nil
            local node = async.wait(utils.node_under_cursor)
            if node then
                return render(node)
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
    return self.__window:close()
end

---@return boolean
function M:is_open()
    return self.__window:is_open()
end

---Opens the window if closed, or closes if open.
function M:toggle()
    return self.__window:toggle()
end

---Re-renders the window manually.
function M:render()
    self.__window:render()
end

return M
