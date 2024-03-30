-------------------------------------------------------------------------------
-- LOADER.LUA
--
-- Core logic to load all components of the database.
-------------------------------------------------------------------------------

local Database  = require("org-roam.core.database")
local File      = require("org-roam.core.file")
local io        = require("org-roam.core.utils.io")
local join_path = require("org-roam.core.utils.path").join
local OrgFiles  = require("orgmode.files")
local Promise   = require("orgmode.utils.promise")
local Schema    = require("org-roam.database.schema")
local unpack    = require("org-roam.core.utils.table").unpack

---@class org-roam.database.Loader
---@field path {database:string, files:string[]}
---@field __db org-roam.core.Database #cache of loaded database
---@field __files OrgFiles #cache of loaded org files
local M         = {}
M.__index       = M

---Creates a new org-roam database loader.
---@param opts {database:string, files:string|string[]}
---@return org-roam.database.Loader
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

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
            instance.path.files[i] = join_path(file, "**", "*")
        end
    end

    return instance
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

---@param db org-roam.core.Database
---@param file OrgFile|nil
local function insert_new_file_into_database(db, file)
    if not file then return end
    local roam_file = File:from_org_file(file)
    for id, node in pairs(roam_file.nodes) do
        db:insert(node, { id = id })
        db:link(id, unpack(vim.tbl_keys(node.linked)))
    end
end

---@param db org-roam.core.Database
---@param filename string
local function remove_file_from_database(db, filename)
    for _, id in ipairs(db:find_by_index(Schema.INDEX.FILE, filename)) do
        db:remove(id)
    end
end

---@param db org-roam.core.Database
---@param file OrgFile|nil
---@param opts? {force?:boolean}
local function modify_file_in_database(db, file, opts)
    opts = opts or {}
    if not file then return end

    local ids = db:find_by_index(Schema.INDEX.FILE, file.filename)
    if #ids == 0 then return end

    ---@type integer
    local mtime = db:get(ids[1]).mtime

    if opts.force or file.metadata.mtime > mtime then
        -- Construct information from org file
        local roam_file = File:from_org_file(file)

        -- Clear out existing nodes as some might have moved file,
        -- maintaining a mapping of which nodes linked to removed
        -- nodes so we can restore if they are re-injected
        ---@type {[string]:string[]}
        local node_backlinks = {}
        for _, id in ipairs(ids) do
            node_backlinks[id] = vim.tbl_keys(db:get_backlinks(id))
            db:remove(id)
        end

        -- Add in parsed nodes and link them again
        for id, node in pairs(roam_file.nodes) do
            -- Because overwriting may remove and break links, we
            -- capture those references prior to re-inserting
            if db:has(id) then
                node_backlinks[id] = vim.tbl_keys(db:get_backlinks(id))
            end

            db:insert(node, { id = id, overwrite = true })
            db:link(id, unpack(vim.tbl_keys(node.linked)))
        end

        -- Repair links that were severed by earlier removal
        for target_id, origin_ids in pairs(node_backlinks) do
            if db:has(target_id) then
                for _, id in ipairs(origin_ids) do
                    if db:has(id) then
                        db:link(id, target_id)
                    end
                end
            end
        end
    end
end

---Loads all files into the database. If files have not been modified
---from current database record, they will be ignored.
---
---@param opts? {force?:boolean}
---@return OrgPromise<{database:org-roam.core.Database, files:OrgFiles}>
function M:load(opts)
    opts = opts or {}
    local force = opts.force or false

    -- Reload all org-roam files
    return Promise.all({
        self:__load_database(),
        self:__load_org_files({ force = force }),
    }):next(function(results)
        ---@type org-roam.core.Database, OrgFiles
        local db, files = results[1], results[2]

        -- Figure out which files are new, deleted, or modified
        -- Left-only means deleted
        -- Right-only means new
        -- Both means modified
        local filenames = find_distinct(
            db:iter_index_keys(Schema.INDEX.FILE):collect(),
            files:filenames()
        )

        -- For each deleted file, remove from database
        for _, filename in ipairs(filenames.left) do
            remove_file_from_database(db, filename)
        end

        -- For each new file, insert into database
        for _, filename in ipairs(filenames.right) do
            insert_new_file_into_database(db, files:load_file_sync(filename))
        end

        -- For each modified file, check the modified time (any node will do)
        -- to see if we need to refresh nodes for a file
        for _, filename in ipairs(filenames.both) do
            modify_file_in_database(db, files:load_file_sync(filename))
        end

        -- Re-link all nodes to one another. We do this because removing
        -- and re-inserting nodes can lose the links from other nodes
        -- that were made previously
        --[[ for id in db:iter_ids() do
            local node = db:get(id)
            local ids = (node and vim.tbl_keys(node.linked)) or {}
            if #ids > 0 then
                db:link(id, unpack(ids))
            end
        end ]]

        return { database = db, files = files }
    end)
end

---Loads a file into the database.
---
---@param opts {path:string}
---@return OrgPromise<{file:OrgFile, nodes:org-roam.core.file.Node[]}>
function M:load_file(opts)
    return Promise.all({
        self:__load_database(),
        self:__load_org_files({ skip = true }),
    }):next(function(results)
        ---@type org-roam.core.Database, OrgFiles
        local db, files = results[1], results[2]

        return files:load_file(opts.path):next(function(file)
            -- Determine if the file already exists through nodes in the db
            local has_file = #db:find_by_index(Schema.INDEX.FILE, file.filename) > 0

            if has_file then
                modify_file_in_database(db, file)
            else
                insert_new_file_into_database(db, file)
            end

            return {
                file = file,
                nodes = db:find_by_index(Schema.INDEX.FILE, file.filename),
            }
        end)
    end)
end

---@private
---@return OrgPromise<org-roam.core.Database>
function M:__load_database()
    return self.__db and Promise.resolve(self.__db) or Promise.new(function(resolve, reject)
        -- Load our database from disk if it is available
        io.stat(self.path.database, function(unavailable)
            if unavailable then
                local db = Database:new()
                Schema.update(db)
                self.__db = db
                return resolve(db)
            end

            Database:load_from_disk(self.path.database, function(err, db)
                if err then
                    return reject(err)
                end

                ---@cast db -nil
                Schema.update(db)
                self.__db = db
                return resolve(db)
            end)
        end)
    end)
end

---@private
---@param opts? {force?:boolean, skip?:boolean}
---@return OrgPromise<OrgFiles>
function M:__load_org_files(opts)
    opts = opts or {}

    -- Grab or create org files (not loaded)
    local files = self.__files or OrgFiles:new({ paths = self.path.files })
    self.__files = files

    -- If not skipping, perform loading/reloading of org files
    if not opts.skip then
        return files:load(opts.force)
    else
        return Promise.resolve(files)
    end
end

return M
