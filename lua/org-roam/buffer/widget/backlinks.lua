-------------------------------------------------------------------------------
-- BACKLINKS.LUA
--
-- Buffer widget that displays backlinks.
-------------------------------------------------------------------------------

---@class org-roam.buffer.widget.Backlinks: org-roam.buffer.Widget
---@field private predicate org-roam.buffer.widget.backlinks.Predicate
---@field private unique boolean
local M = require("org-roam.buffer.widget"):new()
M.__index = M

---@alias org-roam.buffer.widget.backlinks.Predicate
---|fun(backlink:org-roam.core.database.Node):boolean

---Creates a new backlinks widget.
---@param opts? {predicate?:org-roam.buffer.widget.backlinks.Predicate, unique?:boolean}
---@return org-roam.buffer.Widget
function M:new(opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)
    instance.unique = opts.unique or false
    instance.predicate = opts.predicate or function() return true end
    return instance
end

---@param opts org-roam.buffer.widget.ApplyOpts
function M:apply(opts)
    local bufnr = opts.buffer
    local db = opts.database
    local node = opts.node

    local bl_ids = vim.tbl_keys(db:get_backlinks(node.id))
    if #bl_ids > 0 then
        local lines = { string.format("** Backlinks (%s)", #bl_ids) }

        vim.list_extend(lines, vim.tbl_filter(
        -- Filter out nil lines
            function(n) return n ~= nil end,

            ---@param id org-roam.core.database.Id
            vim.tbl_map(function(id)
                ---@type org-roam.core.database.Node|nil
                ---@diagnostic disable-next-line:redefined-local
                local node = db:get(id)
                if node then
                    return string.format(
                        "*** [[id:%s][%s]] ([[#][Top]])",
                        id,
                        node.title
                    )
                end
            end, bl_ids)
        ))

        vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, lines)
    end
end

return M
