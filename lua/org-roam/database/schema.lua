-------------------------------------------------------------------------------
-- SCHEMA.LUA
--
-- Contains database schema definitions and logic.
-------------------------------------------------------------------------------

---@enum org-roam.database.Schema
local M = {
    ALIAS = "alias",
    FILE = "file",
    TAG = "tag",
}

---Updates a schema (series of indexes) for the specified database.
---@param db org-roam.core.Database
---@return org-roam.core.Database
function M:update(db)
    ---@param name string
    local function field(name)
        ---@param node org-roam.core.file.Node
        ---@return org-roam.core.database.IndexKeys
        return function(node)
            return node[name]
        end
    end

    local new_indexes = {}
    for name, indexer in pairs({
        [self.ALIAS] = field("aliases"),
        [self.FILE] = field("file"),
        [self.TAG] = field("tags"),
    }) do
        if not db:has_index(name) then
            db:new_index(name, indexer)
            table.insert(new_indexes, name)
        end
    end

    if #new_indexes > 0 then
        db:reindex({ indexes = new_indexes })
    end

    return db
end

return M
