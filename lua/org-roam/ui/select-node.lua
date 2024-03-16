-------------------------------------------------------------------------------
-- SELECT-NODE.LUA
--
-- Opens a dialog to select a node, returning its id.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local Select = require("org-roam.core.ui.select")

---Opens up a selection dialog populated with nodes (titles and aliases).
---@overload fun(cb:fun(id:org-roam.core.database.Id))
---@param opts {auto_select?:boolean, init_input?:string}
---@param cb fun(id:org-roam.core.database.Id)
return function(opts, cb)
    if type(opts) == "function" then
        cb = opts
        opts = {}
    end
    opts = opts or {}

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

    ---@type org-roam.core.ui.select.Opts
    local select_opts = vim.tbl_extend("keep", {
        items = items,
        prompt = " (node) ",
        ---@param item {id:org-roam.core.database.Id, label:string}
        format = function(item)
            return string.format("%s (%s)", item.label, item.id)
        end,
    }, opts or {})

    Select:new(select_opts)
        :on_choice(function(item) cb(item.id) end)
        :open()
end
