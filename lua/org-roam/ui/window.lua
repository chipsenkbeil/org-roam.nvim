-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Primary user interface controls for org-roam specialized windows.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local NodeViewWindow = require("org-roam.ui.window.node-view")
local Select = require("org-roam.core.ui.select")

---@type org-roam.ui.window.NodeViewWindow|nil
local CURSOR_NODE_VIEW

---@type table<org-roam.core.database.Id, org-roam.ui.window.NodeViewWindow>
local NODE_VIEW = {}

local M = {}

---Launch an org-roam buffer that tracks the node currently at point.
---
---This means that the content of the buffer changes as the point is moved,
---if necessary.
function M.toggle_node_view()
    if not CURSOR_NODE_VIEW then
        CURSOR_NODE_VIEW = NodeViewWindow:new()
    end

    CURSOR_NODE_VIEW:toggle()
end

---Launch an org-roam buffer for a specific node without visiting its file.
---
---Unlike `toggle_roam_buffer`, you can have multiple such buffers and their
---content won’t be automatically replaced with a new node at point.
---
---If an `id` is not specified, a prompt will appear to specify the id.
---@param id? org-roam.core.database.Id
function M.toggle_fixed_node_view(id)
    local db = database()

    ---@param id org-roam.core.database.Id
    local function toggle_view(id)
        if id then
            if not NODE_VIEW[id] then
                NODE_VIEW[id] = NodeViewWindow:new({ id = id })
            end

            NODE_VIEW[id]:toggle()
        end
    end

    if id then
        toggle_view(id)
    else
        M.select_node(toggle_view)
    end
end

---Opens up a selection dialog populated with nodes (titles and aliases).
---@param cb fun(id:org-roam.core.database.Id)
---@param opts? {auto_select?:boolean, init_filter?:string}
function M.select_node(cb, opts)
    local db = database()

    -- TODO: Make this more optimal. Probably involves supporting
    --       an async function to return items instead of an
    --       item list so we can query the database by name
    --       and by aliases to get candidate ids.
    ---@type {id:org-roam.core.database.Id, label:string}
    local items = {}
    for _, id in ipairs(db:ids()) do
        ---@type org-roam.core.database.Node|nil
        local node = db:get(id)
        if node then
            table.insert(items, { id = id, label = node.title })
            for _, alias in ipairs(node.aliases) do
                table.insert(items, { id = id, label = alias })
            end
        end
    end

    local select_opts = vim.tbl_extend("keep", {
        items = items,
        prompt = " (node) ",
        ---@param item {id:org-roam.core.database.Id, label:string}
        format_item = function(item)
            return string.format("%s (%s)", item.label, item.id)
        end,
    }, opts or {})

    Select:new(select_opts)
        :on_choice(function(item) cb(item.id) end)
        :open()
end

return M
