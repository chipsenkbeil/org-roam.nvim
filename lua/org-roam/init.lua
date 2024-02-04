-------------------------------------------------------------------------------
-- INIT.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

---@class org-roam.OrgRoam
---@field database org-roam.core.database.Database
local M = {}

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    -- Merge our configuration options into our global config
    ---@diagnostic disable-next-line:param-type-mismatch
    require("org-roam.core.config"):merge(opts)

    local notify = require("org-roam.core.ui").notify

    -- Load our database, creating it if it does not exist
    local Database = require("org-roam.core.database")
    local File = require("org-roam.core.database.file")
    local db_path = vim.fn.stdpath("data") .. "/org-roam.nvim/" .. "db.mpack"
    if not File:new(db_path):exists() then
        -- Need to create path to database
        local plugin_data_dir = vim.fs.dirname(db_path)
        vim.fn.mkdir(plugin_data_dir, "p")

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
            M.database = assert(db, "impossible: database unavailable after loaded")
        end)
    else
        notify("Loading database from " .. db_path, vim.log.levels.INFO)
        Database:load_from_disk(db_path, function(err, db)
            if err then
                notify(err, vim.log.levels.ERROR)
                return
            end

            M.database = assert(db, "impossible: database unavailable after loaded")
        end)
    end
end

return M
