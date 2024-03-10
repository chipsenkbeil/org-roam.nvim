-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Contains global database logic used by the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")

local async = require("org-roam.core.utils.async")
local Database = require("org-roam.core.database")
local File = require("org-roam.core.database.file")
local Scanner = require("org-roam.core.scanner")

local notify = require("org-roam.core.ui.notify")

---Default location to find the database stored on disk.
local DATABASE_PATH = vim.fn.stdpath("data") .. "/org-roam.nvim/" .. "db.mpack"

---@type org-roam.core.Database|nil
local DATABASE = nil

---Creates new database, scanning directory.
---@param cb fun(db:org-roam.core.Database)
local function create_database(cb)
    -- Need to create path to database
    local plugin_data_dir = vim.fs.dirname(DATABASE_PATH)
    vim.fn.mkdir(plugin_data_dir, "p")

    notify.debug("Creating new database")
    local db = Database:new()

    notify.info("Scanning for org files")
    Scanner:new({ CONFIG.org_roam_directory })
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
        DATABASE = db
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

---Returns the path to the database on disk.
---@return string
function M.path()
    return DATABASE_PATH
end

return M
