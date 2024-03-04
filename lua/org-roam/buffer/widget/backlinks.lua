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
                local backlink_node = db:get(id)
                if backlink_node then
                    if not (self.predicate)(backlink_node) then
                        return
                    end

                    ---@diagnostic disable-next-line:redefined-local
                    local lines = {}
                    local locs = backlink_node.linked[node.id] or {}
                    for _, loc in ipairs(locs) do
                        local row, _ = loc[1], loc[2]
                        table.insert(lines, string.format(
                            "*** [[file:%s::%s][%s]] ([[#][Top]])",
                            node.file,
                            row,
                            node.title
                        ))
                    end

                    -- TODO: Store linked locations within node data,
                    --       which we will use to construct the full
                    --       link versus it just linking to the file.
                    --
                    --       Additionally, with that information, we
                    --       will retrieve a preview of the link by
                    --       loading the file, parsing it, and
                    --       extracting the line it is on.
                    --
                    --       We also should consider rebuilding this
                    --       to be async to avoid blocking when
                    --       loading a bunch of nodes. First thought
                    --       is supplying a function we call to feed
                    --       lines to append, and another to indicate
                    --       being finished. The buffer manager would
                    --       have some visual to show loading/done.
                    --
                    --       file:sometext::NNN is the only format that
                    --       supports jumping to a specific line. Notice
                    --       that it does not support column. So if we
                    --       want to support jumping to the start of a
                    --       link within a line then we either need to
                    --
                    --       a. Use quickfix list
                    --       b. Use custom buffer (not org) that has
                    --          custom binding to jump to specific location
                    return lines
                end
            end, bl_ids)
        ))

        vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, lines)
    end
end

return M
