-------------------------------------------------------------------------------
-- QUICKFIX.LUA
--
-- Opens a quickfix list for org-roam.
-------------------------------------------------------------------------------

---@class org-roam.ui.quickfix.Item
---@field filename string
---@field module string
---@field lnum? integer
---@field col? integer
---@field text? string

---@param roam OrgRoam
---@param id org-roam.core.database.Id
---@return org-roam.ui.quickfix.Item[]
local function roam_get_links_as_quickfix_items(roam, id)
    ---@type org-roam.core.database.Id[]
    local ids = vim.tbl_keys(roam.database:get_links(id))

    local items = {}
    for _, link_id in ipairs(ids) do
        local node = roam.database:get_sync(link_id)
        if node then
            table.insert(items, {
                filename = node.file,
                module = node.title,
            })
        end
    end

    return items
end

---@param roam OrgRoam
---@param id org-roam.core.database.Id
---@param opts? {show_preview?:boolean}
---@return org-roam.ui.quickfix.Item[]
local function roam_get_backlinks_as_quickfix_items(roam, id, opts)
    opts = opts or {}

    ---@type org-roam.core.database.Id[]
    local ids = vim.tbl_keys(roam.database:get_backlinks(id))

    local items = {}
    for _, backlink_id in ipairs(ids) do
        local node = roam.database:get_sync(backlink_id)

        if node then
            -- If showing preview of the link, we load the
            -- file tied to the node exactly once
            local lines = {}
            if opts.show_preview then
                ---@type boolean, string|nil
                local ok, data = require("org-roam.core.utils.io").read_file(node.file):wait()

                if ok and data then
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
---@param roam OrgRoam
---@param id org-roam.core.database.Id
---@param opts? {backlinks?:boolean, links?:boolean, show_preview?:boolean}
local function roam_open(roam, id, opts)
    opts = opts or {}

    local title = (function()
        local node = roam.database:get_sync(id)
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
        local qfitems = roam_get_links_as_quickfix_items(roam, id)

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
        local qfitems = roam_get_backlinks_as_quickfix_items(roam, id, opts)

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

---@param roam OrgRoam
---@return org-roam.ui.QuickfixApi
return function(roam)
    ---@class org-roam.ui.QuickfixApi
    local M = {}

    ---@class org-roam.ui.quickfix.Opts
    ---@field id? org-roam.core.database.Id #target id, or opens select ui if not provided
    ---@field backlinks? boolean #if true, shows backlinks
    ---@field links? boolean #if true, shows links
    ---@field show_preview? boolean #if true, loads preview of linked content

    ---Creates and opens a new quickfix list.
    ---
    ---* `id`: id of node, or opens a selection dialog to pick a node
    ---* `backlinks`: if true, shows node's backlinks
    ---* `links`: if true, shows node's links
    ---* `show_preview`: if true, loads preview of each link's content
    ---
    ---@param opts? org-roam.ui.quickfix.Opts
    ---@return OrgPromise<boolean>
    function M.open_qflist(opts)
        opts = opts or {}

        return require("orgmode.utils.promise").new(function(resolve)
            if opts.id then
                roam_open(roam, opts.id, opts)
                resolve(true)
            else
                require("org-roam.utils").node_under_cursor(function(node)
                    if node then
                        roam_open(roam, node.id, opts)
                        resolve(true)
                    else
                        resolve(false)
                    end
                end)
            end
        end)
    end

    return M
end
