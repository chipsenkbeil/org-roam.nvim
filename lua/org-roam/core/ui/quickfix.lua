-------------------------------------------------------------------------------
-- QUICKFIX.LUA
--
-- Quickfix interface for org-roam.
-------------------------------------------------------------------------------

local utils = require("org-roam.core.utils")

---@class org-roam.core.ui.quickfix
local M = {}

---@class org-roam.core.ui.quickfix.Item
---@field filename string
---@field module string
---@field lnum? integer
---@field col? integer
---@field text? string

---@param db org-roam.core.database.Database
---@param id org-roam.core.database.Id
---@return org-roam.core.ui.quickfix.Item[]
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

---@param db org-roam.core.database.Database
---@param id org-roam.core.database.Id
---@param opts? {show_preview?:boolean}
---@return org-roam.core.ui.quickfix.Item[]
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
                local _, data = utils.io.read_file_sync(node.file)
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

---@class org-roam.core.ui.quickfix.OpenOpts
---@field backlinks? boolean
---@field links? boolean
---@field show_preview? boolean

---@param db org-roam.core.database.Database
---@param id org-roam.core.database.Id
---@param opts? org-roam.core.ui.quickfix.OpenOpts
function M.open(db, id, opts)
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

    ---@type org-roam.core.ui.quickfix.Item[]
    local items = {}

    -- Build up our quickfix list items based on links
    if opts.links then
        local qfitems = get_links_as_quickfix_items(db, id)

        if prefix_module then
            ---@param item org-roam.core.ui.quickfix.Item
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
            ---@param item org-roam.core.ui.quickfix.Item
            qfitems = vim.tbl_map(function(item)
                item.module = string.format("(backlink) %s", item.module)
                return item
            end, qfitems)
        end

        vim.list_extend(items, qfitems)
    end

    -- Consistent ordering by title
    ---@param a org-roam.core.ui.quickfix.Item
    ---@param b org-roam.core.ui.quickfix.Item
    table.sort(items, function(a, b)
        return a.module < b.module
    end)

    assert(vim.fn.setqflist({}, "r", {
        title = string.format("%s backlinks", title or "???"),
        items = items,
    }) == 0, "failed to set quickfix list")

    vim.cmd("copen")
end

return M
