-------------------------------------------------------------------------------
-- LOADER.LUA
--
-- Core logic to load all components of the database.
-------------------------------------------------------------------------------

local Database = require("org-roam.core.database")
local File     = require("org-roam.core.file")
local io       = require("org-roam.core.utils.io")
local OrgFiles = require("orgmode.files")
local Promise  = require("orgmode.utils.promise")

---@class org-roam.database.Loader
---@field force boolean
---@field path {database:string, files:string|string[]}
local M        = {}
M.__index      = M

---Creates a new org-roam database loader.
---@param opts {database:string, files:string|string[], force?:boolean}
---@return org-roam.database.Loader
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.force = opts.force or false
    instance.path = {
        database = opts.database,
        files = opts.files,
    }

    return instance
end

---@param path string
---@return OrgPromise<org-roam.core.Database>
local function load_database(path)
    return Promise.new(function(resolve, reject)
        -- Load our database from disk if it is available
        io.stat(path, function(unavailable)
            if unavailable then
                return resolve(Database:new())
            end

            Database:load_from_disk(path, function(err, db)
                if err then
                    return reject(err)
                end

                return resolve(db)
            end)
        end)
    end)
end

---Loads the database from disk, re-parses files, and scans to see if
---nodes need to be refreshed and refreshes them.
---@return OrgPromise<{database:org-roam.core.Database, files:OrgFiles}>
function M:load()
    -- NOTE: We need to set paths to empty to avoid loading synchronously!
    local files = OrgFiles:new({ paths = {} })
    files.paths = self.path.files

    local force = self.force

    -- Reload all org-roam files
    return Promise.all({
        load_database(self.path.database),
        files:load(true), -- force loading
    }):next(function(results)
        ---@type org-roam.core.Database
        local db = results[1]

        -- For each file, check the modified time (any node will do) to
        -- see if we need to refresh nodes for a file
        for filename in db:iter_index_keys("file") do
            local ids = db:find_by_index("file", filename)
            local node = ids[1] and db:get(ids[1])
            if node then
                local mtime = node.mtime
                local file = files.all_files[filename]
                if force or (file and file.metadata.mtime > mtime) then
                    -- Construct information from org file
                    local roam_file = File:from_org_file(file)

                    -- Clear out existing nodes as some might have moved file
                    for _, id in ipairs(ids) do
                        db:remove(id)
                    end

                    -- Add in parsed nodes and link them again
                    for id, node in pairs(roam_file.nodes) do
                        db:insert(node, { id = id, overwrite = true })
                        db:link(id, unpack(vim.tbl_keys(node.linked)))
                    end
                end
            end
        end

        return { database = db, files = files }
    end)
end

return M
