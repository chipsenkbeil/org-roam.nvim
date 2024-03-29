-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Contains global database logic used by the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")

local async = require("org-roam.core.utils.async")
local Database = require("org-roam.core.database")
local Emitter = require("org-roam.core.utils.emitter")
local File = require("org-roam.core.database.file")
local join_path = require("org-roam.core.utils.path").join
local Scanner = require("org-roam.core.scanner")

local notify = require("org-roam.core.ui.notify")

---@enum org-roam.database.Events
local EVENTS = {
    LOADED = "loaded",
}

---@enum org-roam.database.Index
local INDEX = {
    ALIAS = "alias",
    FILE = "file",
    TAG = "tag",
}

---Default location to find the database stored on disk.
local DATABASE_PATH = join_path(vim.fn.stdpath("data"), "org-roam.nvim", "db")

---@class org-roam.Database: org-roam.core.Database
---@field private __db org-roam.core.Database
---@field private __emitter org-roam.core.utils.Emitter
---@field private __loaded boolean|"loading"
local M = {}

---Creates a new, unloaded instance of the database.
---@return org-roam.Database
function M:new()
    local instance = {}
    setmetatable(instance, M)
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

---@private
---Applies a schema (series of indexes) to loaded database.
function M:__apply_database_schema()
    ---@param name string
    local function field(name)
        ---@param node org-roam.core.database.Node
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

---@private
---@param cb fun(err:string|nil)
function M:__load(cb)
    self.__emitter:once(EVENTS.LOADED, cb)

    if self:is_loaded() then
        self.__emitter:emit(EVENTS.LOADED)
        return
    elseif self.__loaded == "loading" then
        return
    end

    self.__loaded = "loading"

    vim.schedule(function()
        -- Load our database, creating it if it does not exist
        if not File:new(DATABASE_PATH):exists() then
            notify.debug("Creating database in " .. DATABASE_PATH)

            ---@type string
            local plugin_data_dir = vim.fs.dirname(DATABASE_PATH)
            vim.fn.mkdir(plugin_data_dir, "p")

            notify.debug("Creating new database")
            self:__apply_database_schema()

            notify.info("Scanning for org files")
            self:update({ CONFIG.directory }, function(err)
                self.__loaded = false

                if err then
                    notify.error(err)
                    self.__emitter:emit(EVENTS.LOADED, err)
                    return
                end

                notify.debug("Database loaded")
                self.__loaded = true
                self.__emitter:emit(EVENTS.LOADED)
            end)
        else
            notify.debug("Loading database from " .. DATABASE_PATH)
            Database:load_from_disk(DATABASE_PATH, function(err, db)
                self.__loaded = false

                if err then
                    notify.error(err)
                    self.__emitter:emit(EVENTS.LOADED, err)
                    return
                end

                ---@cast db -nil
                self.__db = db
                self:__apply_database_schema()

                notify.debug("Database loaded")
                self.__loaded = true
                self.__emitter:emit(EVENTS.LOADED)
            end)
        end
    end)
end

---Updates the database for the provided paths, recursing through directories.
---@param paths string[]
---@param cb fun(err:string|nil)
function M:update(paths, cb)
    ---@param db org-roam.core.Database
    local function update_nodes_from_scan(db)
        ---@param scan org-roam.core.scanner.Scan
        return function(scan)
            notify.debug("Scanned " .. scan.path)

            -- Remove any node that exists for the path as we re-add them
            for _, id in ipairs(db:find_by_index(INDEX.FILE, scan.path)) do
                db:remove(id)
            end

            -- Add the nodes for this path back into the database
            for _, node in ipairs(scan.nodes) do
                local id = db:insert(node, { id = node.id, overwrite = true })
                db:link(id, unpack(vim.tbl_keys(node.linked)))
            end
        end
    end

    ---@param db org-roam.core.Database
    local function write_db(db)
        return function()
            db:write_to_disk(self:path(), function(err)
                if err then
                    notify.error(err)
                    cb(err)
                    return
                end

                cb(nil)
            end)
        end
    end

    self:__load(function(err)
        if err then
            cb(err)
            return
        end

        Scanner:new(paths)
            :on_scan(update_nodes_from_scan(self.__db))
            :on_error(notify.error)
            :on_done(write_db(self.__db))
            :start()
    end)
end

---Updates the database for the provided paths.
---@param paths string[]
---@return string|nil err
function M:update_sync(paths)
    return async.wrap(self.update)(self, paths)
end

---Retrieves a node from the database by its id.
---@param id org-roam.core.database.Id
---@param cb fun(node:org-roam.core.database.Node|nil)
function M:get(id, cb)
    self:__load(function(err)
        if err then return cb(nil) end
        cb(self.__db:get(id))
    end)
end

---Retrieves a node from the database by its id.
---@param id org-roam.core.database.Id
---@return org-roam.core.database.Node|nil
function M:get_sync(id)
    return async.wrap(self.get)(self, id)
end

---Retrieves nodes with the specified alias.
---@param alias string
---@param cb fun(nodes:org-roam.core.database.Node[])
function M:find_nodes_by_alias(alias, cb)
    self:__load(function(err)
        if err then return cb({}) end
        local ids = self.__db:find_by_index(INDEX.ALIAS, alias)
        cb(self.__db:get_many(ids))
    end)
end

---Retrieves nodes with the specified alias.
---@param alias string
---@return org-roam.core.database.Node[]
function M:find_nodes_by_alias_sync(alias)
    return async.wrap(self.find_nodes_by_alias_sync)(self, alias)
end

---Retrieves nodes from the specified file.
---@param file string
---@param cb fun(nodes:org-roam.core.database.Node[])
function M:find_nodes_by_file(file, cb)
    self:__load(function(err)
        if err then return cb({}) end
        local ids = self.__db:find_by_index(INDEX.FILE, file)
        cb(self.__db:get_many(ids))
    end)
end

---Retrieves nodes from the specified file.
---@param file string
---@return org-roam.core.database.Node[]
function M:find_nodes_by_file_sync(file)
    return async.wrap(self.find_nodes_by_file_sync)(self, file)
end

---Retrieves nodes with the specified tag.
---@param tag string
---@param cb fun(nodes:org-roam.core.database.Node[])
function M:find_nodes_by_tag(tag, cb)
    self:__load(function(err)
        if err then return cb({}) end
        local ids = self.__db:find_by_index(INDEX.TAG, tag)
        cb(self.__db:get_many(ids))
    end)
end

---Retrieves nodes with the specified tag.
---@param tag string
---@return org-roam.core.database.Node[]
function M:find_nodes_by_tag_sync(tag)
    return async.wrap(self.find_nodes_by_tag_sync)(self, tag)
end

local INSTANCE = M:new()
return INSTANCE
