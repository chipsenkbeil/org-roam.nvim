-------------------------------------------------------------------------------
-- LOADER.LUA
--
-- Core logic to load all components of the database.
-------------------------------------------------------------------------------

local Database = require("org-roam.core.database")
local File     = require("org-roam.core.file")
local io       = require("org-roam.core.utils.io")
local OrgFiles = require("orgmode.files")
local path     = require("org-roam.core.utils.path")
local Promise  = require("orgmode.utils.promise")
local unpack   = require("org-roam.core.utils.table").unpack

---@class org-roam.database.Loader
---@field force boolean
---@field path {database:string, files:string[]}
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
        files = vim.tbl_flatten({ opts.files }),
    }

    -- For file specified, check if they are explicitly
    -- org or org_archive, otherwise we assume directories
    -- and need to transform to be globs
    for i, file in ipairs(instance.path.files) do
        local ext = vim.fn.fnamemodify(file, ":e")
        local is_org = ext == "org" or ext == "org_archive"
        if not is_org then
            instance.path.files[i] = path.join(file, "**", "*")
        end
    end

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

---@param left string[]
---@param right string[]
---@return {left:string[], right:string[], both:string[]}
local function find_distinct(left, right)
    table.sort(left)
    table.sort(right)

    local lset = {}
    local rset = {}
    local bset = {}

    local i = 1
    local j = 1
    while i <= #left and j <= #right do
        -- Both same, then we add to the set of both
        -- Otherwise if left comes before right, we add to left
        -- Otherwise we add to right set
        if left[i] == right[i] then
            table.insert(bset, left[i])
            i = i + 1
            j = j + 1
        elseif left[i] < right[i] then
            table.insert(lset, left[i])
            i = i + 1
        elseif left[i] > right[i] then
            table.insert(rset, right[i])
            j = j + 1
        end
    end

    vim.list_extend(lset, vim.list_slice(left, i))
    vim.list_extend(rset, vim.list_slice(right, j))

    return { left = lset, right = rset, both = bset }
end

---Loads the database from disk, re-parses files, and scans to see if
---nodes need to be refreshed and refreshes them.
---@return OrgPromise<{database:org-roam.core.Database, files:OrgFiles}>
function M:load()
    local force = self.force

    -- Reload all org-roam files
    return Promise.all({
        load_database(self.path.database),
        OrgFiles:new({ paths = self.path.files }):load(true),
    }):next(function(results)
        ---@type org-roam.core.Database
        local db = results[1]

        ---@type OrgFiles
        local files = results[2]

        -- Figure out which files are new, deleted, or modified
        -- Left-only means deleted
        -- Right-only means new
        -- Both means modified
        local filenames = find_distinct(
            db:iter_index_keys("file"):collect(),
            files:filenames()
        )

        -- For each deleted file, remove from database
        for _, filename in ipairs(filenames.left) do
            for _, id in ipairs(db:find_by_index("file", filename)) do
                db:remove(id)
            end
        end

        -- For each new file, insert into database
        for _, filename in ipairs(filenames.right) do
            local file = files:load_file_sync(filename)
            if file then
                -- Construct information from org file
                local roam_file = File:from_org_file(file)

                -- Add in parsed nodes
                for id, node in pairs(roam_file.nodes) do
                    db:insert(node, { id = id })
                end
            end
        end

        -- For each modified file, check the modified time (any node will do)
        -- to see if we need to refresh nodes for a file
        for _, filename in ipairs(filenames.both) do
            local ids = db:find_by_index("file", filename)
            local node = ids[1] and db:get(ids[1])
            if node then
                local mtime = node.mtime
                local file = files:load_file_sync(filename)
                if file and (force or file.metadata.mtime > mtime) then
                    -- Construct information from org file
                    local roam_file = File:from_org_file(file)

                    -- Clear out existing nodes as some might have moved file
                    for _, id in ipairs(ids) do
                        db:remove(id)
                    end

                    -- Add in parsed nodes and link them again
                    for id, node in pairs(roam_file.nodes) do
                        db:insert(node, { id = id })
                    end
                end
            end
        end

        -- Re-link all nodes to one another. We do this because removing
        -- and re-inserting nodes can lose the links from other nodes
        -- that were made previously
        for id in db:iter_ids() do
            local node = db:get(id)
            local ids = (node and vim.tbl_keys(node.linked)) or {}
            if #ids > 0 then
                db:link(id, unpack(ids))
            end
        end

        return { database = db, files = files }
    end)
end

return M
