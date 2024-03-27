-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Contains global database logic used by the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")

local async = require("org-roam.core.utils.async")
local Database = require("org-roam.core.database")
local File = require("org-roam.core.database.file")
local join_path = require("org-roam.core.utils.path").join
local io = require("org-roam.core.utils.io")
local Scanner = require("org-roam.core.scanner")

local notify = require("org-roam.core.ui.notify")

---@enum org-roam.database.Index
local INDEX = {
    ALIAS = "alias",
    FILE = "file",
    TAG = "tag",
}

---Default location to find the database stored on disk.
local DATABASE_PATH = join_path(vim.fn.stdpath("data"), "org-roam.nvim", "db")

---@type org-roam.core.Database|nil
local DATABASE = nil

---Applies a schema (series of indexes) to a database, reindexing if needed.
---@param db org-roam.core.Database
---@return org-roam.core.Database
local function apply_database_schema(db)
    ---@param name string
    local function field(name)
        ---@param node org-roam.core.database.Node
        ---@return org-roam.core.database.IndexKeys
        return function(node)
            return node[name]
        end
    end

    local new_indexes = {}
    for name, indexer in pairs({
        [INDEX.ALIAS] = field("aliases"),
        [INDEX.FILE] = field("file"),
        [INDEX.TAG] = field("tags"),
    }) do
        if not db:has_index(name) then
            db = db:new_index(name, indexer)
            table.insert(new_indexes, name)
        end
    end

    if #new_indexes > 0 then
        db = db:reindex({ indexes = new_indexes })
    end

    return db
end

---Creates new database, scanning directory.
---@param cb fun(db:org-roam.core.Database)
local function create_database(cb)
    -- Need to create path to database
    ---@type string
    local plugin_data_dir = vim.fs.dirname(DATABASE_PATH)
    vim.fn.mkdir(plugin_data_dir, "p")

    notify.debug("Creating new database")
    local db = apply_database_schema(Database:new())

    notify.info("Scanning for org files")
    Scanner:new({ CONFIG.directory })
        :on_scan(function(scan)
            notify.debug("Scanned " .. scan.path)
            for _, node in ipairs(scan.nodes) do
                local id = db:insert(node, { id = node.id })
                db:link(id, unpack(vim.tbl_keys(node.linked)))
            end
        end)
        :on_error(function(err) notify.error(err) end)
        :on_done(function()
            db:write_to_disk(DATABASE_PATH, function(err)
                if err then
                    notify.error(err)
                    return
                end

                notify.info("Database saved to " .. DATABASE_PATH)
                DATABASE = db
                cb(db)
            end)
        end)
        :start()
end

---Loads database from disk.
---@param cb fun(db:org-roam.core.Database)
local function load_database(cb)
    notify.debug("Loading database from " .. DATABASE_PATH)
    Database:load_from_disk(DATABASE_PATH, function(err, db)
        if err then
            notify.error(err)
            return
        end

        ---@cast db -nil
        DATABASE = apply_database_schema(db)
        cb(db)
    end)
end

---Schedules the initialization the plugin's database.
---@param cb fun(db:org-roam.core.Database)
local function initialize_database(cb)
    vim.schedule(function()
        -- If we already have the database, return it
        if DATABASE ~= nil then
            cb(DATABASE)
            return
        end

        -- Load our database, creating it if it does not exist
        if not File:new(DATABASE_PATH):exists() then
            create_database(cb)
        else
            load_database(cb)
        end
    end)
end

---@class org-roam.Database: org-roam.core.Database
---@overload fun(cb:fun(db:org-roam.core.Database))
---@overload fun():org-roam.core.Database
local M = setmetatable({}, {
    ---@param tbl org-roam.Database
    ---@param cb? fun(db:org-roam.core.Database)
    ---@return org-roam.core.Database|nil
    __call = function(tbl, cb)
        return tbl.load(cb)
    end,

    ---@param _ org-roam.Database
    ---@param key string
    ---@return any
    __index = function(_, key)
        return DATABASE and DATABASE[key]
    end,
})

---Returns the path to the database on disk.
---@return string
function M.path()
    return DATABASE_PATH
end

---Returns true if the database has been loaded and is available.
---@return boolean
function M.is_loaded()
    return DATABASE ~= nil
end

---Retrieves the database, loading it from disk if possible, and caching it
---for all future access.
---
---If a callback is provided, the database is loaded asynchronously. Otherwise,
---the function waits for the database to be loaded, returning it.
---
---@param cb? fun(db:org-roam.core.Database)
---@return org-roam.core.Database|nil
function M.load(cb)
    if type(cb) == "function" then
        initialize_database(cb)
        return
    end

    ---@type org-roam.core.Database
    return async.wrap(initialize_database)()
end

---Updates the database for the provided paths.
---@param paths string[]
---@param cb fun(err:string|nil)
function M.update(paths, cb)
    M.load(function(db)
        Scanner:new(paths)
            :on_scan(function(scan)
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
            end)
            :on_error(notify.error)
            :on_done(function()
                db:write_to_disk(M.path(), function(err)
                    if err then
                        notify.error(err)
                        cb(err)
                        return
                    end

                    cb(nil)
                end)
            end)
            :start()
    end)
end

---@param paths string[]
---@return string|nil err
function M.update_sync(paths)
    return async.wrap(M.update)(paths)
end

return M
