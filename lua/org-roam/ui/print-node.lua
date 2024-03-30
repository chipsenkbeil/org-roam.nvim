-------------------------------------------------------------------------------
-- PRINT-NODE.LUA
--
-- Prints information about a node.
-------------------------------------------------------------------------------

local db = require("org-roam.database")
local utils = require("org-roam.utils")

---@param opts? {id?:org-roam.core.database.Id}
return function(opts)
    opts = opts or {}

    ---@param node org-roam.core.file.Node
    local function print_node(node)
        print(node.id)
    end

    if opts.id then
        local node = db:get_sync(opts.id)
        if node then
            print_node(node)
        end
    else
        utils.node_under_cursor(function(node)
            if node then
                print_node(node)
            end
        end)
    end
end
