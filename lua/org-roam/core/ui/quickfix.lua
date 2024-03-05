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
---@field lnum integer
---@field col integer
---@field text string

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

---@param db org-roam.core.database.Database
---@param id org-roam.core.database.Id
---@param opts? {backlinks?:boolean, show_preview?:boolean}
function M.open(db, id, opts)
    opts = opts or {}

    local title = (function()
        ---@type org-roam.core.database.Node|nil
        local node = db:get(id)
        return node and node.title
    end)()

    ---@type org-roam.core.ui.quickfix.Item[]
    local items = {}

    -- Build up our quickfix list items based on backlinks
    if opts.backlinks then
        vim.list_extend(items, get_backlinks_as_quickfix_items(db, id, opts))
    end

    -- Consistent ordering by title
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
