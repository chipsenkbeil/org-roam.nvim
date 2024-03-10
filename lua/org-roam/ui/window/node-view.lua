-------------------------------------------------------------------------------
-- NODE-VIEW.LUA
--
-- Specialized window representing an org-roam buffer for a particular node.
-------------------------------------------------------------------------------

local buffer = require("org-roam.buffer")
local database = require("org-roam.database")
local utils = require("org-roam.core.utils")
local Window = require("org-roam.core.ui.window")

---Renders a node within an orgmode buffer.
---@param id org-roam.core.database.Id
---@return string[] lines
local function render(id)
    local db = database()

    local lines = {}

    local backlinks = db:get_backlinks(id)
    table.insert(
        lines,
        string.format("* backlinks (%s)", vim.tbl_count(backlinks))
    )

    for backlink_id, _ in pairs(backlinks) do
        ---@type org-roam.core.database.Node|nil
        local node = db:get(backlink_id)

        if node then
            local locs = node.linked[id]
            for _, loc in ipairs(locs or {}) do
                local line = loc.row + 1
                table.insert(
                    lines,
                    string.format(
                        "** [[%s::%s][%s @ line %s]]",
                        node.file,
                        line,
                        node.title,
                        line
                    )
                )
            end
        end
    end

    return lines
end

---@class org-roam.ui.window.NodeViewWindow
---@field private __node org-roam.core.database.Id|fun():org-roam.core.database.Id
---@field private __window org-roam.core.ui.Window
local M = {}
M.__index = {}

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
    if id then
        table.insert(widgets, function()
            return render(id)
        end)
    else
        table.insert(widgets, function()
            ---@diagnostic disable-next-line:redefined-local
            local id = utils.async.wait(buffer.node_under_cursor)

            if id then
                return render(id)
            else
                return {}
            end
        end)
    end

    instance.__window = Window:new(vim.tbl_extend("keep", {
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

return M
