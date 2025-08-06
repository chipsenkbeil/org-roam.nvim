-------------------------------------------------------------------------------
-- SELECT-NODE.LUA
--
-- Opens a dialog to select a node, returning its id.
-------------------------------------------------------------------------------

local Select = require("org-roam.core.ui.select")

local function gather_node_tags(node)
    local tags
    if #node.tags ~= 0 then
        tags = ":" .. table.concat(node.tags, ":") .. ":"
    else
        tags = ""
    end
    return tags
end


local function gather_node_aliases(node)
    local aliases
    if #node.aliases ~= 0 then
        aliases = "/" .. table.concat(node.aliases, ":") .. "/"
    else
        aliases = ""
    end
    return aliases
end

local function get_value(node, key)
    local value = ""
    if key == "title" then
        value = node.title
    elseif key == "tags" then
        value = gather_node_tags(node)
    elseif key == "alias" then
        value = gather_node_aliases(node)
    elseif key == "separator" then
        value = "|||"
    end
    return value
end

local function format_node_for_display(node, display_template, available_width)

    local function replace_values(key, width)
        width = tonumber(width) or 0
        local value = get_value(node, key)
        if width > 0 and #value > width then
                value = value:sub(1, width)
            end
        return value
    end

    local intermediate_template = string.gsub(display_template, "{([%w_]+):?(%d*)}", replace_values)
    local parts = vim.split(intermediate_template, "|||", { plain = true })
    local left = parts[1]
    local right = parts[2] or ""

    local spaces_required = available_width - string.len(left) - string.len(right)
    if spaces_required < 1 then spaces_required = 1 end
    local spacing = string.rep(" ", spaces_required)
    return left .. spacing .. right
end

---@param roam OrgRoam
---@param opts {allow_select_missing?:boolean, auto_select?:boolean, exclude?:string[], include?:string[], init_input?:string}
---@return org-roam.core.ui.Select
local function roam_select_node(roam, opts)
    -- TODO: Make this more optimal. Probably involves supporting
    --       an async function to return items instead of an
    --       item list so we can query the database by name
    --       and by aliases to get candidate ids.
    ---@type {id:org-roam.core.database.Id, label:string}
    local items = {}
    local window_width = vim.o.columns - 2

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
                -- local label = format_node_for_display(node, roam.node_display_template, window_width)
                local label = format_node_for_display(node, roam.config.node_display_template, window_width)
                table.insert(items, { id = id, label = label })
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
            return item.label
        end,
        cancel_on_no_init_matches = true,
    }, opts or {})

    return Select:new(select_opts)
end

---@param roam OrgRoam
---@return org-roam.ui.SelectNodeApi
return function(roam)
    ---@class org-roam.ui.SelectNodeApi
    local M = {}

    ---Opens up a selection dialog populated with nodes (titles and aliases).
    ---@param opts? {allow_select_missing?:boolean, auto_select?:boolean, exclude?:string[], include?:string[], init_input?:string}
    ---@return org-roam.ui.NodeSelect
    function M.select_node(opts)
        opts = opts or {}

        ---@class org-roam.ui.NodeSelect
        local select = { __select = roam_select_node(roam, opts) }

        ---@param f fun(selection:{id:org-roam.core.database.Id, label:string})
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
