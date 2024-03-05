-------------------------------------------------------------------------------
-- UI.LUA
--
-- User interface for org-roam.
-------------------------------------------------------------------------------

---@class org-roam.core.ui
local M = {}

---Wrapper around `vim.notify` that schedules the notification to avoid issues
---with it being triggered in a Lua loop callback, which is not allowed.
---@param msg string
---@param level? integer
---@param opts? table
function M.notify(msg, level, opts)
    vim.schedule(function()
        vim.notify(
            msg,
            level,
            vim.tbl_extend("force", opts or {}, { title = "org-roam" })
        )
    end)
end

---@param db org-roam.core.database.Database
---@param id org-roam.core.database.Id
function M.open_qflist_backlinks(db, id)
    local title = (function()
        ---@type org-roam.core.database.Node|nil
        local node = db:get(id)
        return node and node.title
    end)()

    local ids = vim.tbl_keys(db:get_backlinks(id))

    -- Build up our quickfix list items based on backlinks
    local items = {}
    for _, backlink_id in ipairs(ids) do
        ---@type org-roam.core.database.Node|nil
        local node = db:get(backlink_id)

        if node then
            local locs = node.linked[id]
            for _, loc in ipairs(locs or {}) do
                table.insert(items, {
                    filename = node.file,
                    lnum = loc.row + 1,
                    col = loc.column + 1,
                })
            end
        end
    end

    assert(vim.fn.setqflist({}, "r", {
        title = string.format("%s backlinks", title or "???"),
        items = items,
    }) == 0, "failed to set quickfix list")

    vim.cmd("copen")
end

return M
