-------------------------------------------------------------------------------
-- ORG-ROAM.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

---@class org-roam.OrgRoam
---@field private __database org-roam.core.database.Database|nil
local M = {
    __database = nil,
}

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    require("org-roam.setup")(opts, function(db)
        M.__database = db
    end)
end

---Opens the quickfix list for the node `id`, populating with backlinks.
---
---If `show_preview` is true, will load a preview of the line containing
---the backlink.
---
---@param id org-roam.core.database.Id
---@param opts? {show_preview?:boolean}
function M.open_qflist_for_node(id, opts)
    local db = assert(M.__database, "not initialized")

    require("org-roam.core.ui.quickfix").open(
        db,
        id,
        vim.tbl_extend("keep", { backlinks = true }, opts or {})
    )
end

---Opens the quickfix list for the node under cursor, populating with backlinks.
---
---If `show_preview` is true, will load a preview of the line containing
---the backlink.
---
---@param opts? {show_preview?:boolean}
function M.open_qflist_for_node_under_cursor(opts)
    require("org-roam.core.buffer").node_under_cursor(function(id)
        if id then
            M.open_qflist_for_node(id, opts)
        end
    end)
end

function M.print_node_under_cursor()
    require("org-roam.core.buffer").node_under_cursor(function(id)
        if id then
            print(id)
        end
    end)
end

local roam_buffer = (function()
    local win = require("org-roam.core.ui.window"):new()
    local initialized = false

    ---@param buffer org-roam.core.ui.Buffer
    ---@param db org-roam.core.database.Database
    ---@param id org-roam.core.database.Id
    local function render(buffer, db, id)
        local target_id = id

        local backlinks = db:get_backlinks(id)
        buffer:append_lines({
            string.format("* backlinks (%s)", vim.tbl_count(backlinks)),
            force = true,
        })

        for id, _ in pairs(backlinks) do
            ---@type org-roam.core.database.Node|nil
            local node = db:get(id)

            if node then
                local locs = node.linked[target_id]
                for _, loc in ipairs(locs or {}) do
                    local line = loc.row + 1
                    buffer:append_lines({
                        string.format("** [[%s::%s][%s @ line %s]]", node.file, line, node.title, line),
                        force = true,
                    })
                end
            end
        end
    end

    ---Toggles window, taking an optional id to target a specific node.
    ---@param db org-roam.core.database.Database
    ---@param id org-roam.core.database.Id
    return function(db, id)
        local buffer = win:buffer()

        if not initialized then
            initialized = true

            buffer:add_widget(function(b)
                render(b, db, id)
            end)
        end

        if not win:is_open() then
            buffer:render()
        end

        win:toggle()
    end
end)()

---@param id? org-roam.core.database.Id
function M.toggle_roam_buffer(id)
    local db = assert(M.__database, "not initialized")
    if id then
        roam_buffer(db, id)
        return
    end

    require("org-roam.core.buffer").node_under_cursor(function(id)
        if id then
            roam_buffer(db, id)
            return
        end
    end)
end

return M
