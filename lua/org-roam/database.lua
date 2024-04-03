-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Contains global database logic used by the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")

local Emitter = require("org-roam.core.utils.emitter")
local join_path = require("org-roam.core.utils.path").join
local Loader = require("org-roam.database.loader")
local Promise = require("orgmode.utils.promise")
local schema = require("org-roam.database.schema")

local EVENTS = {
    LOADED = "loaded",
    SAVED = "saved",
}

---@class org-roam.Database: org-roam.core.Database
---@field private __cache {modified:table<string, integer>}
---@field private __emitter org-roam.core.utils.Emitter
---@field private __loader org-roam.database.Loader
---@field private __path string
local M = {}

---Creates a new, unloaded instance of the database.
---@param opts? {path?:string}
---@return org-roam.Database
function M:new(opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)
    instance.__cache = {}
    instance.__emitter = Emitter:new()
    instance.__loader = nil
    instance.__path = opts.path or CONFIG.database.path
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
        loader = Loader:new({ database = self.__path, files = CONFIG.directory })
        self.__loader = loader
    end
    return loader
end

---Returns the path to the database on disk.
---@return string
function M:path()
    return self.__path
end

---Loads the database from disk and re-parses files.
---Callback receives a database reference and collection of files.
---@param opts? {force?:boolean}
---@return OrgPromise<{database:org-roam.core.Database, files:OrgFiles}>
function M:load(opts)
    opts = opts or {}

    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader()
        :load({ force = opts.force })
        :next(function(results)
            self.__emitter:emit(EVENTS.LOADED, nil, results.database, results.files)
            return results
        end)
end

---@param opts {path:string, force?:boolean}
---@return OrgPromise<{file:OrgFile, nodes:org-roam.core.file.Node[]}>
function M:load_file(opts)
    return self:__get_loader():load_file({ path = opts.path })
end

---Saves the database to disk.
---@return OrgPromise<nil>
function M:save()
    ---@diagnostic disable-next-line:missing-return-value
    return self:load():next(function(results)
        local db = results.database

        return Promise.new(function(resolve, reject)
            db:write_to_disk(self.__path, function(err)
                if err then
                    reject(err)
                    return
                end

                resolve(nil)
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
        return db:get_many(ids)
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
    ---@diagnostic disable-next-line:missing-return-value
    return self:__get_loader():database():next(function(db)
        local ids = db:find_by_index(schema.FILE, file)
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

local INSTANCE = M:new()
return INSTANCE
