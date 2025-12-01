-------------------------------------------------------------------------------
-- SELECT-NODE.LUA
--
-- Opens a dialog to select a node, returning its id.
-------------------------------------------------------------------------------

---@class (exact) org-roam.ui.SelectNodeOpts
---@field allow_select_missing? boolean
---@field auto_select? boolean
---@field exclude? string[]
---@field include? string[]
---@field init_input? string
---@field node_to_items? fun(node:org-roam.core.file.Node):org-roam.config.ui.SelectNodeItems

---@param roam OrgRoam
---@param opts org-roam.ui.SelectNodeOpts
---@return org-roam.core.ui.Select
local function roam_select_node(roam, opts)
    local node_to_items = opts.node_to_items or roam.config.ui.select.node_to_items

    -- TODO: Make this more optimal. Probably involves supporting
    --       an async function to return items instead of an
    --       item list so we can query the database by name
    --       and by aliases to get candidate ids.
    ---@type {id:org-roam.core.database.Id, label:string, value:any}[]
    local items = {}
    for _, id in ipairs(opts.include or roam.database:ids()) do
        local skip = false

        -- If we were given an exclusion list, check if the id is in that list
        -- and if so we will skip including this node in our dialog
        if opts.exclude and vim.tbl_contains(opts.exclude, id) then
            skip = true
        end

        if not skip then
            local node = roam.database:get_sync(id)
            if node then
                local node_items = node_to_items(node)
                for _, item in ipairs(node_items) do
                    if type(item) == "string" then
                        table.insert(items, {
                            id = id,
                            label = item,
                            value = item,
                        })
                    elseif type(item) == "table" then
                        table.insert(items, {
                            id = id,
                            label = item.label,
                            value = item.value,
                        })
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
        ---@param item {id:org-roam.core.database.Id, label:string, value:any}
        format = function(item)
            return item.label
        end,
        cancel_on_no_init_matches = true,
    }, opts or {})

    return require("org-roam.core.ui.select"):new(select_opts)
end

---@param roam OrgRoam
---@return org-roam.ui.SelectNodeApi
return function(roam)
    ---@class org-roam.ui.SelectNodeApi
    local M = {}

    ---Opens up a selection dialog populated with nodes (titles and aliases).
    ---@param opts? org-roam.ui.SelectNodeOpts
    ---@return org-roam.ui.NodeSelect
    function M.select_node(opts)
        opts = opts or {}

        ---@class org-roam.ui.NodeSelect
        local select = { __select = roam_select_node(roam, opts) }

        ---@param f fun(selection:{id:org-roam.core.database.Id, label:string, value:any})
        ---@return org-roam.ui.NodeSelect
        function select:on_choice(f)
            self.__select:on_choice(f)
            return self
        end

        ---@param f fun(label:string)
        ---@return org-roam.ui.NodeSelect
        function select:on_choice_missing(f)
            self.__select:on_choice_missing(f)
            return self
        end

        ---@param f fun()
        ---@return org-roam.ui.NodeSelect
        function select:on_cancel(f)
            self.__select:on_cancel(f)
            return self
        end

        ---@return integer win
        function select:open()
            return self.__select:open()
        end

        return select
    end

    return M
end
