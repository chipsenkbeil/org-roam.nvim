-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Contains global database logic used by the plugin.
-------------------------------------------------------------------------------

local io = require("org-roam.core.utils.io")
local Loader = require("org-roam.database.loader")
local log = require("org-roam.core.log")
local Profiler = require("org-roam.core.utils.profiler")
local Promise = require("orgmode.utils.promise")
local schema = require("org-roam.database.schema")

---@class org-roam.Database: org-roam.core.Database
---@field private __last_save integer
---@field private __loader org-roam.database.Loader
---@field private __database_path string
---@field private __directory string
local M = {}

---Creates a new, unloaded instance of the database.
---@param opts {db_path:string, directory:string}
---@return org-roam.Database
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.__last_save = -1
    instance.__loader = nil
    instance.__database_path = opts.db_path
    instance.__directory = opts.directory
    return instance
end

---@private
---@param key string
---@return any
function M:__index(key)
    ---@type org-roam.database.Loader|nil
    local loader = rawget(self, "__loader")

    -- Check the fields of the table, then the metatable
    -- of the table which includes methods defined below
    local self_value = rawget(self, key)
        or rawget(getmetatable(self) or {}, key)
    if self_value ~= nil then
        return self_value
    end

    -- Fall back ot the underlying database
    local db = loader and loader:database_sync()
    local db_value = db and db[key]

    -- If we are accessing the core database function,
    -- we need to wrap it as the "self" value that is
    -- passed to it may be our wrapper instead of the
    -- core database. So, we wrap our function, check
    -- if the first value matches our wrapper, and
    -- swap it if that is the case.
    if type(db_value) == "function" then
        return function(this, ...)
            if this == self then
                this = db
            end

            return db_value(this, ...)
        end
    else
        return db_value
    end
end

---@private
---@return org-roam.database.Loader
function M:__get_loader()
    local loader = self.__loader
    if not loader then
        loader = Loader:new({
            database = self.__database_path,
            files = self.__directory,
        })
        self.__loader = loader
    end
    return loader
end

---Returns the path to the database on disk.
---@return string
function M:path()
    return self.__database_path
end

---Returns the path to the files directory.
---@return string
function M:files_path()
    return self.__directory
end

---Returns the internal database wrapped by this interface.
---@return OrgPromise<org-roam.core.Database>
function M:internal()
    return self:__get_loader():database()
end

---Returns the internal database wrapped by this interface.
---@param opts? {timeout?:integer}
---@return org-roam.core.Database
function M:internal_sync(opts)
    return self:__get_loader():database_sync(opts)
end

---Loads the database from disk and re-parses files.
---Returns a promise that receives a database reference and collection of files.
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
    log.fmt_debug("loading all files into database (force=%s)",
        opts.force or false)

    local profiler = Profiler:new({ label = "org-roam-load" })
    local rec_id = profiler:start()

    return self:__get_loader():load({
        force = opts.force,
    }):next(function(...)
        profiler:stop(rec_id)
        log.fmt_debug("loading all files into database took %s",
            profiler:time_taken_as_string({ recording = rec_id }))

        return ...
    end)
end

---@param opts {path:string, force?:boolean}
---@return OrgPromise<{file:OrgFile, nodes:org-roam.core.file.Node[]}>
function M:load_file(opts)
    log.fmt_debug("loading %s into database (force=%s)",
        opts.path, opts.force or false)

    local profiler = Profiler:new({ label = "org-roam-load-file" })
    local rec_id = profiler:start()

    return self:__get_loader():load_file({
        path = opts.path,
        force = opts.force,
    }):next(function(...)
        profiler:stop(rec_id)
        log.fmt_debug("loading %s into database took %s",
            opts.path,
            profiler:time_taken_as_string({ recording = rec_id }))

        return ...
    end)
end

---Saves the database to disk.
---
---Returns a promise of a boolean indicating if the database was actually
---written to disk, or if it was cached.
---@param opts? {force?:boolean}
---@return OrgPromise<boolean>
function M:save(opts)
    opts = opts or {}
    log.fmt_debug("saving database (force=%s)", opts.force or false)

    local profiler = Profiler:new({ label = "org-roam-save-database" })
    local rec_id = profiler:start()

    return self:__get_loader():database():next(function(db)
        -- If our last save was recent enough, do not actually save
        if not opts.force and self.__last_save >= db:changed_tick() then
            profiler:stop(rec_id)
            log.fmt_debug("saving database took %s (nothing to save)",
                profiler:time_taken_as_string({ recording = rec_id }))
            return Promise.resolve(false)
        end

        -- Refresh our data (no rescan or force) to make sure it is fresh
        return self:load():next(function()
            return Promise.new(function(resolve, reject)
                db:write_to_disk(self.__database_path, function(err)
                    if err then
                        -- NOTE: Scheduling to avoid potential textlock issue
                        vim.schedule(function()
                            reject(err)
                        end)
                        return
                    end

                    -- NOTE: Scheduling to avoid potential textlock issue
                    vim.schedule(function()
                        profiler:stop(rec_id)
                        log.fmt_debug("saving database took %s",
                            profiler:time_taken_as_string({ recording = rec_id }))

                        self.__last_save = db:changed_tick()
                        resolve(true)
                    end)
                end)
            end)
        end)
    end)
end

---Deletes the database cache from disk.
---@return OrgPromise<boolean>
function M:delete_disk_cache()
    return Promise.new(function(resolve, reject)
        io.stat(self.__database_path, function(err, stat)
            if err or not stat then
                return vim.schedule(function()
                    resolve(false)
                end)
            end

            io.unlink(self.__database_path, function(err, success)
                if err then
                    return vim.schedule(function()
                        reject(err)
                    end)
                end

                return vim.schedule(function()
                    resolve(success or false)
                end)
            end)
        end)
    end)
end

---Loads org files (or retrieves from cache) asynchronously.
---@param opts? {force?:boolean, skip?:boolean}
---@return OrgPromise<OrgFiles>
function M:files(opts)
    return self:__get_loader():files(opts)
end

---Loads org files (or retrieves from cache) synchronously.
---@param opts? {force?:boolean, timeout?:integer, skip?:boolean}
---@return OrgFiles
function M:files_sync(opts)
    return self:__get_loader():files_sync(opts)
end

---Inserts a node into the database.
---
---Returns a promise of the id tied to the node in the database.
---@param node org-roam.core.file.Node
---@param opts? {overwrite?:boolean}
---@return OrgPromise<string>
function M:insert(node, opts)
    opts = opts or {}

    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        return db:insert(node, {
            id = node.id,
            overwrite = opts.overwrite,
        })
    end)
end

---Retrieves a node from the database by its id.
---@param node org-roam.core.file.Node
---@param opts? {overwrite?:boolean, timeout?:integer}
---@return org-roam.core.file.Node|nil
function M:insert_sync(node, opts)
    opts = opts or {}
    return self:insert(node, opts):wait(opts.timeout)
end

---Retrieves a node from the database by its id.
---@param id org-roam.core.database.Id
---@return OrgPromise<org-roam.core.file.Node|nil>
function M:get(id)
    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        return db:get(id)
    end)
end

---Retrieves a node from the database by its id.
---@param id org-roam.core.database.Id
---@param opts? {timeout?:integer}
---@return org-roam.core.file.Node|nil
function M:get_sync(id, opts)
    opts = opts or {}
    return self:get(id):wait(opts.timeout)
end

---Retrieves nodes with the specified alias.
---@param alias string
---@return OrgPromise<org-roam.core.file.Node[]>
function M:find_nodes_by_alias(alias)
    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        local ids = db:find_by_index(schema.ALIAS, alias)
        return vim.tbl_values(db:get_many(ids))
    end)
end

---Retrieves nodes with the specified alias.
---@param alias string
---@param opts? {timeout?:integer}
---@return org-roam.core.file.Node[]
function M:find_nodes_by_alias_sync(alias, opts)
    opts = opts or {}
    return self:find_nodes_by_alias(alias):wait(opts.timeout)
end

---Retrieves nodes from the specified file.
---@param file string
---@return OrgPromise<org-roam.core.file.Node[]>
function M:find_nodes_by_file(file)
    -- NOTE: File paths are indexed after being resolved. We need to do the
    --       same here to ensure that symlinks are properly resolved so we can
    --       find them within our index!
    local path = vim.fn.resolve(file)

    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        local ids = db:find_by_index(schema.FILE, path)
        return vim.tbl_values(db:get_many(ids))
    end)
end

---Retrieves nodes from the specified file.
---@param file string
---@param opts? {timeout?:integer}
---@return org-roam.core.file.Node[]
function M:find_nodes_by_file_sync(file, opts)
    opts = opts or {}
    return self:find_nodes_by_file(file):wait(opts.timeout)
end

---Retrieves nodes with the specified origin.
---@param origin string
---@return OrgPromise<org-roam.core.file.Node[]>
function M:find_nodes_by_origin(origin)
    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        local ids = db:find_by_index(schema.ORIGIN, origin)
        return vim.tbl_values(db:get_many(ids))
    end)
end

---Retrieves nodes with the specified origin.
---@param origin string
---@param opts? {timeout?:integer}
---@return org-roam.core.file.Node[]
function M:find_nodes_by_origin_sync(origin, opts)
    opts = opts or {}
    return self:find_nodes_by_origin(origin):wait(opts.timeout)
end

---Retrieves nodes with the specified tag.
---@param tag string
---@return OrgPromise<org-roam.core.file.Node[]>
function M:find_nodes_by_tag(tag)
    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        local ids = db:find_by_index(schema.TAG, tag)
        return vim.tbl_values(db:get_many(ids))
    end)
end

---Retrieves nodes with the specified tag.
---@param tag string
---@param opts? {timeout?:integer}
---@return org-roam.core.file.Node[]
function M:find_nodes_by_tag_sync(tag, opts)
    opts = opts or {}
    return self:find_nodes_by_tag(tag):wait(opts.timeout)
end

---Retrieves nodes with the specified title.
---@param title string
---@return OrgPromise<org-roam.core.file.Node[]>
function M:find_nodes_by_title(title)
    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        local ids = db:find_by_index(schema.TITLE, title)
        return vim.tbl_values(db:get_many(ids))
    end)
end

---Retrieves nodes with the specified title.
---@param title string
---@param opts? {timeout?:integer}
---@return org-roam.core.file.Node[]
function M:find_nodes_by_title_sync(title, opts)
    opts = opts or {}
    return self:find_nodes_by_title(title):wait(opts.timeout)
end

---Retrieves ids of nodes linked from a file.
---
---By default, these are ids immediately linked within the file, but if `max_depth`
---is specified, then indirect links are included. The values of the returned
---table are the distance from the file with 1 being immediately connected.
---@param file string
---@param opts? {max_depth?:integer}
---@return OrgPromise<table<string, integer>>
function M:get_file_links(file, opts)
    return Promise.all({
        self:__get_loader():database(),
        self:find_nodes_by_file(file),
    }):next(function(results)
        ---@type org-roam.core.Database, org-roam.core.file.Node[]
        local db, nodes = results[1], results[2]
        local all_links = {}

        -- For each node, retrieve its links, and check for each link
        -- if we do not have it collected or if we do, but the distance
        -- is further away than this link's distance
        for _, node in ipairs(nodes) do
            local links = db:get_links(node.id, opts)
            for id, distance in pairs(links) do
                if not all_links[id] or all_links[id] > distance then
                    all_links[id] = distance
                end
            end
        end

        return all_links
    end)
end

---Retrieves ids of nodes linked from a file.
---
---By default, these are ids immediately linked within the file, but if `max_depth`
---is specified, then indirect links are included. The values of the returned
---table are the distance from the file with 1 being immediately connected.
---@param file string
---@param opts? {max_depth?:integer, timeout?:integer}
---@return table<string, integer>
function M:get_file_links_sync(file, opts)
    opts = opts or {}
    return self:get_file_links(file, opts):wait(opts.timeout)
end

---Retrieves ids of nodes linking to a file.
---
---By default, these are ids immediately linking to a node within the file, but
---if `max_depth` is specified, then indirect links are included. The values of
---the returned table are the distance from the file with 1 being immediately
---connected.
---@param file string
---@param opts? {max_depth?:integer}
---@return OrgPromise<table<string, integer>>
function M:get_file_backlinks(file, opts)
    return Promise.all({
        self:__get_loader():database(),
        self:find_nodes_by_file(file),
    }):next(function(results)
        ---@type org-roam.core.Database, org-roam.core.file.Node[]
        local db, nodes = results[1], results[2]
        local all_links = {}

        -- For each node, retrieve its backlinks, and check for each link
        -- if we do not have it collected or if we do, but the distance
        -- is further away than this link's distance
        for _, node in ipairs(nodes) do
            local links = db:get_backlinks(node.id, opts)
            for id, distance in pairs(links) do
                if not all_links[id] or all_links[id] > distance then
                    all_links[id] = distance
                end
            end
        end

        return all_links
    end)
end

---Retrieves ids of nodes linking to a file.
---
---By default, these are ids immediately linking to a node within the file, but
---if `max_depth` is specified, then indirect links are included. The values of
---the returned table are the distance from the file with 1 being immediately
---connected.
---@param file string
---@param opts? {max_depth?:integer, timeout?:integer}
---@return OrgPromise<table<string, integer>>
function M:get_file_backlinks_sync(file, opts)
    opts = opts or {}
    return self:get_file_backlinks(file, opts):wait(opts.timeout)
end

return M
