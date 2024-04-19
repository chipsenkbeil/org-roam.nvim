-------------------------------------------------------------------------------
-- SELECT-NODE.LUA
--
-- Opens a dialog to select a node, returning its id.
-------------------------------------------------------------------------------

local Select = require("org-roam.core.ui.select")

---@param roam OrgRoam
---@param opts {allow_select_missing?:boolean, auto_select?:boolean, exclude?:string[], include?:string[], init_input?:string}
---@param cb fun(selection:{id:org-roam.core.database.Id|nil, label:string})
---@param cancel_cb fun()
local function roam_select_node(roam, opts, cb, cancel_cb)
    -- TODO: Make this more optimal. Probably involves supporting
    --       an async function to return items instead of an
    --       item list so we can query the database by name
    --       and by aliases to get candidate ids.
    ---@type {id:org-roam.core.database.Id, label:string}
    local items = {}
    for _, id in ipairs(opts.include or roam.db:ids()) do
        local skip = false

        -- If we were given an exclusion list, check if the id is in that list
        -- and if so we will skip including this node in our dialog
        if opts.exclude and vim.tbl_contains(opts.exclude, id) then
            skip = true
        end

        if not skip then
            local node = roam.db:get_sync(id)
            if node then
                table.insert(items, { id = id, label = node.title })
                for _, alias in ipairs(node.aliases) do
                    -- Avoid repeat of alias that is same as title
                    if alias ~= node.title then
                        table.insert(items, { id = id, label = alias })
                    end
                end
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
        format = function(item) return item.label end,
        cancel_on_no_init_matches = true,
    }, opts or {})

    Select:new(select_opts)
        :on_choice(cb)
        :on_choice_missing(function(label) cb({ id = nil, label = label }) end)
        :on_cancel(cancel_cb)
        :open()
end

---@param roam OrgRoam
---@return org-roam.ui.SelectNodeApi
return function(roam)
    ---@class org-roam.ui.SelectNodeApi
    local M = {}

    ---Opens up a selection dialog populated with nodes (titles and aliases).
    ---@overload fun(cb:fun(selection:{id:org-roam.core.database.Id|nil, label:string}))
    ---@param opts {allow_select_missing?:boolean, auto_select?:boolean, exclude?:string[], include?:string[], init_input?:string}
    ---@param cb fun(selection:{id:org-roam.core.database.Id|nil, label:string})
    ---@param cancel_cb? fun()
    function M.select_node(opts, cb, cancel_cb)
        if type(opts) == "function" then
            cb = opts
            opts = {}
        end
        opts = opts or {}
        if type(cancel_cb) ~= "function" then
            cancel_cb = function() end
        end
        roam_select_node(roam, opts, cb, cancel_cb)
    end

    return M
end
