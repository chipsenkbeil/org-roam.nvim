-------------------------------------------------------------------------------
-- INIT.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

---@class org-roam.OrgRoam
---@field db org-roam.core.database.Database
local M = {}

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    local Instance = require("org-roam.core.config.instance")
    local instance = Instance:new(opts)

    -- Merge our configuration options into our global config
    local config = require("org-roam.core.config")
    local exclude = { "new", "__index" }
    for key, value in pairs(instance) do
        if not vim.tbl_contains(exclude, key) then
            config[key] = value
        end
    end

    local notify = require("org-roam.core.ui").notify

    -- Load our database, creating it if it does not exist
    local Database = require("org-roam.core.database")
    local File = require("org-roam.core.database.file")
    local db_path = vim.fn.stdpath("data") .. "/org-roam.nvim/" .. "db.msgpack"
    if not File:new(db_path):exists() then
        notify("Creating database", vim.log.levels.INFO)
        local db = Database:new()

        notify("Scanning for org files", vim.log.levels.INFO)
        -- TODO: Walk through the org-roam directory, parse each file, and add it to the database

        db:write_to_disk(db_path, function(err)
            if err then
                notify(err, vim.log.levels.ERROR)
                return
            end

            notify("Database saved to " .. db_path, vim.log.levels.INFO)
        end)
    else
        notify("Loading database from " .. db_path, vim.log.levels.INFO)
        Database:load_from_disk(db_path, function(err, db)
            if err then
                notify(err, vim.log.levels.ERROR)
                return
            end

            print(vim.inspect(db))
        end)
    end
end

return M
