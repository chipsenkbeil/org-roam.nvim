-------------------------------------------------------------------------------
-- SELECT-NODE.LUA
--
-- Opens a dialog to select a node, returning its id.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local Select = require("org-roam.core.ui.select")

---Opens up a selection dialog populated with nodes (titles and aliases).
---@overload fun(cb:fun(selection:{id:org-roam.core.database.Id, label:string}))
---@param opts {auto_select?:boolean, init_input?:string}
---@param cb fun(selection:{id:org-roam.core.database.Id, label:string})
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

    -- Build our prompt, updating it to a left-hand side
    -- style if we have neovim 0.10+ which supports inlining
    local prompt = "(node {sel}/{cnt})"
    if vim.fn.has("nvim-0.10") == 1 then
        prompt = "{sel}/{cnt} node> "
    end

    ---@type org-roam.core.ui.select.Opts
    local select_opts = vim.tbl_extend("keep", {
        items = items,
        prompt = prompt,
        ---@param item {id:org-roam.core.database.Id, label:string}
        format = function(item)
            return string.format("%s (%s)", item.label, item.id)
        end,
    }, opts or {})

    Select:new(select_opts)
        :on_choice(cb)
        :open()
end
