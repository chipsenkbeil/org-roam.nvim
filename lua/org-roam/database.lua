-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Contains global database logic used by the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")

local async = require("org-roam.core.utils.async")
local Database = require("org-roam.core.database")
local Emitter = require("org-roam.core.utils.emitter")
local File = require("org-roam.core.file")
local join_path = require("org-roam.core.utils.path").join
local Loader = require("org-roam.database.loader")

local notify = require("org-roam.core.ui.notify")

local EVENTS = {
    LOADED = "loaded",
    SAVED = "saved",
}

---@enum org-roam.database.Index
local INDEX = {
    ALIAS = "alias",
    FILE = "file",
    TAG = "tag",
}

local BASE_PATH = join_path(vim.fn.stdpath("data"), "org-roam.nvim")
local DATABASE_PATH = join_path(BASE_PATH, "db")

---@class org-roam.Database: org-roam.core.Database
---@field private __cache {modified:table<string, integer>}
---@field private __db org-roam.core.Database
---@field private __emitter org-roam.core.utils.Emitter
---@field private __files OrgFiles|nil
---@field private __loaded boolean|"loading"
local M = {}

---Creates a new, unloaded instance of the database.
---@return org-roam.Database
function M:new()
    local instance = {}
    setmetatable(instance, M)
    instance.__cache = {}
    instance.__db = Database:new()
    instance.__emitter = Emitter:new()
    instance.__loaded = false
    return instance
end

---@private
---@param key string
---@return any
function M:__index(key)
    -- Check the fields of the table, then the metatable
    -- of the tabe which includes methods defined below,
    -- and finally fall back to the underlying database
    return rawget(self, key)
        or rawget(getmetatable(self) or {}, key)
        or self.__db[key]
end

---Returns the path to the database on disk.
---@return string
function M:path()
    return DATABASE_PATH
end

---Returns true if the database has been loaded and is available.
---@return boolean
function M:is_loaded()
    return self.__loaded == true
end

---Loads the database from disk and re-parses files.
---@param cb fun(err:string|nil)
---@param opts? {force?:boolean}
function M:load(cb, opts)
    opts = opts or {}

    -- Register our callback to get called once when loaded
    self.__emitter:once(EVENTS.LOADED, cb)

    -- If we're already loaded, trigger now;
    -- if we're loading, exit as we'll trigger later
    if self:is_loaded() then
        self.__emitter:emit(EVENTS.LOADED)
        return
    elseif self.__loaded == "loading" then
        return
    end

    -- Mark as loading so we don't repeat ourselves
    self.__loaded = "loading"

    Loader:new({ database = DATABASE_PATH, files = CONFIG.directory })
        :load()
        :next(function(results)
            print("RESULTS", vim.inspect(results))
            self.__db = results.database
            self.__files = results.files
            self.__loaded = true
            self.__emitter:emit(EVENTS.LOADED)
            return results
        end)
        :catch(function(err)
            print("ERR", vim.inspect(err))
            self.__loaded = false
            self.__emitter:emit(EVENTS.LOADED, vim.inspect(err))
            return err
        end)
end

---@param opts {path:string, force?:boolean}
---@param cb fun(err:string|nil)
function M:load_file(opts, cb)
    local files = self.__files
    if not files then
        vim.schedule(function()
            cb("too early: database not yet loaded")
        end)
        return
    end

    ---@param file OrgFile
    local function on_success(file)
        local db = self.__db
        local ids = db:find_by_index("file", file.filename)
        local node = ids[1] and db:get(ids[1])
        if node then
            local mtime = node.mtime
            if opts.force or (file and file.metadata.mtime > mtime) then
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

    local function on_error(...)
        local errors = { ... }
        if #errors == 1 then
            cb(vim.inspect(errors[1]))
        else
            cb(vim.inspect(errors))
        end
    end

    files
        :load_file(opts.path)
        :next(on_success)
        :catch(on_error)
end

---Saves the database to disk.
---@param cb fun(err:string|nil)
function M:save(cb)
    self.__db:write_to_disk(DATABASE_PATH, function(err)
        if err then
            notify.error(err)
            cb(err)
            return
        end

        cb(nil)
    end)
end

---Retrieves a node from the database by its id.
---@param id org-roam.core.database.Id
---@param cb fun(node:org-roam.core.file.Node|nil)
function M:get(id, cb)
    self:load(function(err)
        if err then return cb(nil) end
        cb(self.__db:get(id))
    end)
end

---Retrieves a node from the database by its id.
---@param id org-roam.core.database.Id
---@return org-roam.core.file.Node|nil
function M:get_sync(id)
    return async.wrap(self.get)(self, id)
end

---Retrieves nodes with the specified alias.
---@param alias string
---@param cb fun(nodes:org-roam.core.file.Node[])
function M:find_nodes_by_alias(alias, cb)
    self:load(function(err)
        if err then return cb({}) end
        local ids = self.__db:find_by_index(INDEX.ALIAS, alias)
        cb(self.__db:get_many(ids))
    end)
end

---Retrieves nodes with the specified alias.
---@param alias string
---@return org-roam.core.file.Node[]
function M:find_nodes_by_alias_sync(alias)
    return async.wrap(self.find_nodes_by_alias_sync)(self, alias)
end

---Retrieves nodes from the specified file.
---@param file string
---@param cb fun(nodes:org-roam.core.file.Node[])
function M:find_nodes_by_file(file, cb)
    self:load(function(err)
        if err then return cb({}) end
        local ids = self.__db:find_by_index(INDEX.FILE, file)
        cb(self.__db:get_many(ids))
    end)
end

---Retrieves nodes from the specified file.
---@param file string
---@return org-roam.core.file.Node[]
function M:find_nodes_by_file_sync(file)
    return async.wrap(self.find_nodes_by_file_sync)(self, file)
end

---Retrieves nodes with the specified tag.
---@param tag string
---@param cb fun(nodes:org-roam.core.file.Node[])
function M:find_nodes_by_tag(tag, cb)
    self:load(function(err)
        if err then return cb({}) end
        local ids = self.__db:find_by_index(INDEX.TAG, tag)
        cb(self.__db:get_many(ids))
    end)
end

---Retrieves nodes with the specified tag.
---@param tag string
---@return org-roam.core.file.Node[]
function M:find_nodes_by_tag_sync(tag)
    return async.wrap(self.find_nodes_by_tag_sync)(self, tag)
end

---@private
---Applies a schema (series of indexes) to loaded database.
function M:__apply_database_schema()
    ---@param name string
    local function field(name)
        ---@param node org-roam.core.file.Node
        ---@return org-roam.core.database.IndexKeys
        return function(node)
            return node[name]
        end
    end

    local db = self.__db
    local new_indexes = {}
    for name, indexer in pairs({
        [INDEX.ALIAS] = field("aliases"),
        [INDEX.FILE] = field("file"),
        [INDEX.TAG] = field("tags"),
    }) do
        if not db:has_index(name) then
            db:new_index(name, indexer)
            table.insert(new_indexes, name)
        end
    end

    if #new_indexes > 0 then
        db:reindex({ indexes = new_indexes })
    end
end

local INSTANCE = M:new()
return INSTANCE
