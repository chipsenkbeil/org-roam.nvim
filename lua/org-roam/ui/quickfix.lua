-------------------------------------------------------------------------------
-- QUICKFIX.LUA
--
-- Opens a quickfix list for org-roam.
-------------------------------------------------------------------------------

local database = require("org-roam.database")
local io = require("org-roam.core.utils.io")
local utils = require("org-roam.utils")

---@class org-roam.ui.quickfix.Item
---@field filename string
---@field module string
---@field lnum? integer
---@field col? integer
---@field text? string

---@param db org-roam.core.Database
---@param id org-roam.core.database.Id
---@return org-roam.ui.quickfix.Item[]
local function get_links_as_quickfix_items(db, id)
    local ids = vim.tbl_keys(db:get_links(id))

    local items = {}
    for _, link_id in ipairs(ids) do
        ---@type org-roam.core.database.Node|nil
        local node = db:get(link_id)
        if node then
            table.insert(items, {
                filename = node.file,
                module = node.title,
            })
        end
    end

    return items
end

---@param db org-roam.core.Database
---@param id org-roam.core.database.Id
---@param opts? {show_preview?:boolean}
---@return org-roam.ui.quickfix.Item[]
local function get_backlinks_as_quickfix_items(db, id, opts)
    opts = opts or {}
    local ids = vim.tbl_keys(db:get_backlinks(id))

    local items = {}
    for _, backlink_id in ipairs(ids) do
        ---@type org-roam.core.database.Node|nil
        local node = db:get(backlink_id)

        if node then
            -- If showing preview of the link, we load the
            -- file tied to the node exactly once
            local lines = {}
            if opts.show_preview then
                local _, data = io.read_file_sync(node.file)
                if data then
                    lines = vim.split(data, "\n", { plain = true })
                end
            end

            local locs = node.linked[id]
            for _, loc in ipairs(locs or {}) do
                table.insert(items, {
                    filename = node.file,
                    module = node.title,
                    lnum = loc.row + 1,
                    col = loc.column + 1,
                    text = vim.trim(lines[loc.row + 1] or ""),
                })
            end
        end
    end

    return items
end

---Opens the quickfix list.
---
---NOTE: Cannot be called from a lua loop callback!
---@param db org-roam.core.Database
---@param id org-roam.core.database.Id
---@param opts? {backlinks?:boolean, links?:boolean, show_preview?:boolean}
local function open(db, id, opts)
    opts = opts or {}

    local title = (function()
        ---@type org-roam.core.database.Node|nil
        local node = db:get(id)
        return node and node.title
    end)()

    -- Determine if we want to prefix our modules, which
    -- we do if we have more than one set of items to
    -- retrieve so we can clarify which is which
    local prefix_module = (function()
        local cnt = 0
        cnt = cnt + (opts.links and 1 or 0)
        cnt = cnt + (opts.backlinks and 1 or 0)
        return cnt
    end)() > 1

    ---@type org-roam.ui.quickfix.Item[]
    local items = {}

    -- Build up our quickfix list items based on links
    if opts.links then
        local qfitems = get_links_as_quickfix_items(db, id)

        if prefix_module then
            ---@param item org-roam.ui.quickfix.Item
            qfitems = vim.tbl_map(function(item)
                item.module = string.format("(link) %s", item.module)
                return item
            end, qfitems)
        end

        vim.list_extend(items, qfitems)
    end

    -- Build up our quickfix list items based on backlinks
    if opts.backlinks then
        local qfitems = get_backlinks_as_quickfix_items(db, id, opts)

        if prefix_module then
            ---@param item org-roam.ui.quickfix.Item
            qfitems = vim.tbl_map(function(item)
                item.module = string.format("(backlink) %s", item.module)
                return item
            end, qfitems)
        end

        vim.list_extend(items, qfitems)
    end

    -- Consistent ordering by title
    ---@param a org-roam.ui.quickfix.Item
    ---@param b org-roam.ui.quickfix.Item
    table.sort(items, function(a, b)
        return a.module < b.module
    end)

    assert(vim.fn.setqflist({}, "r", {
        title = string.format("org-roam (%s)", title or "???"),
        items = items,
    }) == 0, "failed to set quickfix list")

    vim.cmd("copen")
end

---@class org-roam.ui.quickfix.Opts
---@field id? org-roam.core.database.Id #target id, or opens select ui if not provided
---@field backlinks? boolean #if true, shows backlinks
---@field links? boolean #if true, shows links
---@field show_preview? boolean #if true, loads preview of linked content

---@param opts? org-roam.ui.quickfix.Opts
return function(opts)
    opts = opts or {}

    local db = database()

    if opts.id then
        open(db, opts.id, opts)
    else
        utils.node_under_cursor(function(node)
            if node then
                open(db, node.id, opts)
            end
        end)
    end
end
