-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Contains global database logic used by the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")

local Loader = require("org-roam.database.loader")
local Promise = require("orgmode.utils.promise")
local schema = require("org-roam.database.schema")

---@class org-roam.Database: org-roam.core.Database
---@field private __cache {modified:table<string, integer>}
---@field private __loader org-roam.database.Loader
---@field private __database_path string
---@field private __directory string
local M = {}

---Creates a new, unloaded instance of the database.
---@param opts? {db_path?:string, directory?:string}
---@return org-roam.Database
function M:new(opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)
    instance.__cache = {}
    instance.__loader = nil
    instance.__database_path = opts.db_path or CONFIG.database.path
    instance.__directory = opts.directory or CONFIG.directory
    return instance
end

---@private
---@param key string
---@return any
function M:__index(key)
    ---@type org-roam.database.Loader|nil
    local loader = rawget(self, "__loader")

    -- Check the fields of the table, then the metatable
    -- of the table which includes methods defined below,
    -- and finally fall back to the underlying database
    return rawget(self, key)
        or rawget(getmetatable(self) or {}, key)
        or (loader and loader:database_sync()[key])
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

---Loads the database from disk and re-parses files.
---Callback receives a database reference and collection of files.
---@param opts? {force?:boolean}
---@return OrgPromise<{database:org-roam.core.Database, files:OrgFiles}>
function M:load(opts)
    opts = opts or {}
    return self:__get_loader():load({
        force = opts.force,
    })
end

---@param opts {path:string, force?:boolean}
---@return OrgPromise<{file:OrgFile, nodes:org-roam.core.file.Node[]}>
function M:load_file(opts)
    return self:__get_loader():load_file({
        path = opts.path,
        force = opts.force,
    })
end

---Saves the database to disk.
---@return OrgPromise<nil>
function M:save()
    ---@diagnostic disable-next-line:missing-return-value
    return self:load():next(function(results)
        local db = results.database

        return Promise.new(function(resolve, reject)
            db:write_to_disk(self.__database_path, function(err)
                if err then
                    vim.schedule(function()
                        reject(err)
                    end)
                    return
                end

                vim.schedule(function()
                    resolve(nil)
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
---@return org-roam.core.file.Node|nil
function M:get_sync(id)
    return self:get(id):wait()
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
---@return org-roam.core.file.Node[]
function M:find_nodes_by_alias_sync(alias)
    return self:find_nodes_by_alias(alias):wait()
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
---@return org-roam.core.file.Node[]
function M:find_nodes_by_file_sync(file)
    return self:find_nodes_by_file(file):wait()
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
---@return org-roam.core.file.Node[]
function M:find_nodes_by_tag_sync(tag)
    return self:find_nodes_by_tag(tag):wait()
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
---@return org-roam.core.file.Node[]
function M:find_nodes_by_title_sync(title)
    return self:find_nodes_by_title(title):wait()
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
---@param opts? {max_depth?:integer}
---@return table<string, integer>
function M:get_file_links_sync(file, opts)
    ---@diagnostic disable-next-line:param-type-mismatch
    return self:get_file_links(file, opts):wait()
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
---@param opts? {max_depth?:integer}
---@return OrgPromise<table<string, integer>>
function M:get_file_backlinks_sync(file, opts)
    ---@diagnostic disable-next-line:param-type-mismatch
    return self:get_file_backlinks(file, opts):wait()
end

local INSTANCE = M:new()
return INSTANCE
