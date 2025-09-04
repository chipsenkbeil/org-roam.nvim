-------------------------------------------------------------------------------
-- LOADER.LUA
--
-- Core logic to load all components of the database.
-------------------------------------------------------------------------------

local Database = require("org-roam.core.database")
local File = require("org-roam.core.file")
local io = require("org-roam.core.utils.io")
local join_path = require("org-roam.core.utils.path").join
local log = require("org-roam.core.log")
local OrgFiles = require("orgmode.files")
local Promise = require("orgmode.utils.promise")
local schema = require("org-roam.database.schema")

---@class org-roam.database.Loader
---@field path {database:string, files:string[]}
---@field __db org-roam.core.Database #cache of loaded database
---@field __files OrgFiles #cache of loaded org files
---@field __load_state nil|OrgPromise<org-roam.core.Database>|true
local M = {}
M.__index = M

---Creates a new org-roam database loader.
---@param opts {database:string, files:string|string[]}
---@return org-roam.database.Loader
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.path = {
        database = opts.database,
        files = vim.iter(opts.files):flatten():totable(),
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
        local litem = left[i]
        local ritem = right[j]

        -- Both same, then we add to the set of both
        -- Otherwise if left comes before right, we add to left
        -- Otherwise we add to right set
        if litem == ritem then
            table.insert(bset, litem)
            i = i + 1
            j = j + 1
        elseif litem < ritem then
            table.insert(lset, litem)
            i = i + 1
        elseif litem > ritem then
            table.insert(rset, ritem)
            j = j + 1
        end
    end

    vim.list_extend(lset, vim.list_slice(left, i))
    vim.list_extend(rset, vim.list_slice(right, j))

    return { left = lset, right = rset, both = bset }
end

---@param db org-roam.core.Database
---@param filename string
---@return integer removed_node_cnt
local function remove_file_from_database(db, filename)
    local cnt = 0
    for _, id in ipairs(db:find_by_index(schema.FILE, filename)) do
        db:remove(id)
        cnt = cnt + 1
    end
    return cnt
end

---@param db org-roam.core.Database
---@param file OrgFile
---@param opts? {force?:boolean}
---@return integer modified_node_cnt
local function modify_file_in_database(db, file, opts)
    opts = opts or {}

    local ids = db:find_by_index(schema.FILE, file.filename)
    if #ids == 0 then
        log.fmt_debug("modify file (%s) in database canceled (no node)", file.filename)
        return 0
    end

    ---@type integer
    local mtime = db:get(ids[1]).mtime

    -- Skip if not forcing and the file hasn't changed since
    -- the last time we inserted/modified nodes
    if not opts.force and file.metadata.mtime == mtime then
        log.fmt_debug("modify file (%s) in database canceled (no change)", file.filename)
        return 0
    end

    -- Construct information from org file
    local roam_file = File:from_org_file(file)
    local cnt = 0

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
        db:link(id, vim.tbl_keys(node.linked))
        cnt = cnt + 1
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

    return cnt
end

---@param db org-roam.core.Database
---@param file OrgFile
---@param opts? {force?:boolean}
---@return integer inserted_node_cnt
local function insert_new_file_into_database(db, file, opts)
    -- NOTE: We have this in place because of the nature of asynchronous
    --       operations where at the time of scheduling the insertion
    --       there was no file but now there is a file.
    --
    --       I'm not sure if this is needed. We may never encounter
    --       this situation, but I'm leaving it in for now.
    local has_file = not vim.tbl_isempty(db:find_by_index(schema.FILE, file.filename))
    if has_file then
        return modify_file_in_database(db, file, opts)
    end

    local roam_file = File:from_org_file(file)
    local cnt = 0
    for id, node in pairs(roam_file.nodes) do
        db:insert(node, { id = id })
        db:link(id, vim.tbl_keys(node.linked))
        cnt = cnt + 1
    end
    return cnt
end

---Loads all files into the database. If files have not been modified
---from current database record, they will be ignored.
---
---If `force` is "scan", the directory will be searched again for files
---and they will be reloaded. Modification of database records will not be
---forced.
---
---If `force` is true, the directory will be searched again for files,
---they will be reloaded, and modifications of database records will be forced.
---@param opts? {force?:boolean|"scan"}
---@return OrgPromise<{database:org-roam.core.Database, files:OrgFiles}>
function M:load(opts)
    opts = opts or {}
    local force_modify = opts.force == true
    local force_scan = opts.force == "scan" or opts.force == true

    -- Reload all org-roam files
    return Promise.all({
        self:database(),
        self:files({ force = force_scan }),
    }):next(function(results)
        ---@type org-roam.core.Database, OrgFiles
        local db, files = results[1], results[2]

        -- Figure out which files are new, deleted, or modified
        -- Left-only means deleted
        -- Right-only means new
        -- Both means modified
        local filenames = find_distinct(db:iter_index_keys(schema.FILE):collect(), files:filenames())

        local promises = { remove = {}, insert = {}, modify = {} }

        -- For each deleted file, remove from database
        for _, filename in ipairs(filenames.left) do
            table.insert(
                promises.remove,
                Promise.new(function(resolve)
                    vim.schedule(function()
                        log.fmt_debug("removing from database: %s", filename)
                        resolve(remove_file_from_database(db, filename))
                    end)
                end)
            )
        end

        -- For each new file, insert into database
        for _, filename in ipairs(filenames.right) do
            -- Retrieve the changedtick of the file since we do not store that
            -- in our node, and check if the reloaded file has an updated tick
            --
            -- If it does, then that means it was refreshed from tick instead
            -- of mtime, so we need to force a modification since mtime will
            -- appear to have not changed
            local maybe_file = files.all_files[filename]
            local changedtick = maybe_file and maybe_file.metadata.changedtick or 0

            table.insert(
                promises.insert,
                files:load_file(filename):next(function(file)
                    if file then
                        log.fmt_debug("inserting into database: %s", file.filename)
                        return insert_new_file_into_database(db, file, {
                            force = force_modify or file.metadata.changedtick ~= changedtick,
                        })
                    else
                        return 0
                    end
                end)
            )
        end

        -- For each modified file, check the modified time (any node will do)
        -- to see if we need to refresh nodes for a file
        for _, filename in ipairs(filenames.both) do
            -- Retrieve the changedtick of the file since we do not store that
            -- in our node, and check if the reloaded file has an updated tick
            --
            -- If it does, then that means it was refreshed from tick instead
            -- of mtime, so we need to force a modification since mtime will
            -- appear to have not changed
            local maybe_file = files.all_files[filename]
            local changedtick = maybe_file and maybe_file.metadata.changedtick or 0

            table.insert(
                promises.modify,
                files:load_file(filename):next(function(file)
                    if file then
                        log.fmt_debug("modifying in database: %s", file.filename)
                        return modify_file_in_database(db, file, {
                            force = force_modify or file.metadata.changedtick ~= changedtick,
                        })
                    else
                        return 0
                    end
                end)
            )
        end

        return Promise.all(promises.remove)
            :next(function()
                return Promise.all(promises.insert)
            end)
            :next(function()
                return Promise.all(promises.modify)
            end)
            :next(function()
                return { database = db, files = files }
            end)
    end)
end

---Loads a file into the database.
---
---Note that this does NOT populate `OrgFiles` standard files list
---even if the file is within the directory. It just populates
---a separate file.
---
---@param opts {path:string, force?:boolean}
---@return OrgPromise<{file:OrgFile, nodes:org-roam.core.file.Node[]}>
function M:load_file(opts)
    return Promise.all({
        self:database(),
        self:files({ skip = true }),
    }):next(function(results)
        ---@type org-roam.core.Database, OrgFiles
        local db, files = results[1], results[2]

        -- Retrieve the changedtick of the file since we do not store that
        -- in our node, and check if the reloaded file has an updated tick
        --
        -- If it does, then that means it was refreshed from tick instead
        -- of mtime, so we need to force a modification since mtime will
        -- appear to have not changed
        local maybe_file = files.all_files[opts.path]
        local changedtick = maybe_file and maybe_file.metadata.changedtick or 0

        -- This both loads the file and adds it to our file path if not there already
        return Promise.new(function(resolve, reject)
            files
                :add_to_paths(opts.path)
                :next(function(file)
                    -- If false, means failed to add the file
                    if not file then
                        reject("invalid path to org file: " .. opts.path)
                        return file
                    end

                    -- Determine if the file already exists through nodes in the db
                    local ids = db:find_by_index(schema.FILE, file.filename)
                    local has_file = not vim.tbl_isempty(ids)

                    if has_file then
                        log.fmt_debug("modifying in database: %s", file.filename)
                        modify_file_in_database(db, file, {
                            force = opts.force or file.metadata.changedtick ~= changedtick,
                        })
                    else
                        log.fmt_debug("inserting into database: %s", file.filename)
                        insert_new_file_into_database(db, file, {
                            force = opts.force or file.metadata.changedtick ~= changedtick,
                        })

                        -- To allow a newly created roam file to be accessible for refiling and other
                        -- convenience features of orgmode, it must be add to the orgmode database.
                        -- Although it might be expected, that files:add_to_paths already does that,
                        -- this is currently not the case.
                        -- So the next line is a workaround to achieve this goal. Some rework at orgmodes
                        -- file-loading is to be expected and when it's done, this line can be removed.
                        require("orgmode").files:add_to_paths(file.filename)
                    end

                    resolve({
                        file = file,
                        nodes = vim.tbl_values(db:get_many(db:find_by_index(schema.FILE, file.filename))),
                    })

                    return file
                end)
                :catch(reject)
        end)
    end)
end

---Loads database (or retrieves from cache) asynchronously.
---@return OrgPromise<org-roam.core.Database>
function M:database()
    local state = self.__load_state
    if state == nil then
        local promise = io.stat(self.path.database)
            :next(function()
                return Database:load_from_disk(self.path.database)
                    :next(function(db)
                        schema:update(db)
                        self.__db = db
                        self.__load_state = true
                        return nil
                    end)
                    :catch(function(err)
                        log.fmt_error("Failed to load database: %s", err)
                        -- Punt error to the outer `catch` so it can create the database.
                        error(err)
                    end)
            end)
            :catch(function()
                local db = Database:new()
                schema:update(db)
                self.__db = db
                self.__load_state = true
            end)
        -- Awkward assignment dance to keep the lua_ls type checker happy.
        state = promise:next(function()
            return self.__db
        end)
        self.__load_state = state
        return state
    elseif state == true then
        return Promise.resolve(self.__db)
    else
        return state
    end
end

---Loads database (or retrieves from cache) synchronously.
---@param opts? {timeout?:integer}
---@return org-roam.core.Database
function M:database_sync(opts)
    return self:database():wait(opts and opts.timeout)
end

---Loads org files (or retrieves from cache) asynchronously.
---@param opts? {force?:boolean, skip?:boolean}
---@return OrgPromise<OrgFiles>
function M:files(opts)
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

---Loads org files (or retrieves from cache) synchronously.
---@param opts? {force?:boolean, timeout?:integer, skip?:boolean}
---@return OrgFiles
function M:files_sync(opts)
    opts = opts or {}
    return self:files(opts):wait(opts.timeout)
end

return M
