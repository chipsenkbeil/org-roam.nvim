-------------------------------------------------------------------------------
-- PRINT-NODE.LUA
--
-- Prints information about a node.
-------------------------------------------------------------------------------

local database = require("org-roam.database")

---@param opts? {id?:org-roam.core.database.Id}
return function(opts)
    opts = opts or {}

    ---@param node org-roam.core.database.Node
    local function print_node(node)
        print(node.id)
    end

    if opts.id then
        local db = database()
        local node = db:get(opts.id)
        if node then
            print_node(node)
        end
    else
        require("org-roam.buffer").node_under_cursor(function(node)
            if node then
                print_node(node)
            end
        end)
    end
end
