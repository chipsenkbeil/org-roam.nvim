-------------------------------------------------------------------------------
-- INIT.LUA
--
-- Main entrypoint into the org-roam neovim plugin.
-------------------------------------------------------------------------------

---@class org-roam.OrgRoam
---@field database org-roam.core.database.Database
local M = {}

---@param opts org-roam.core.config.Config.NewOpts
local function setup(opts)
    local config = require("org-roam.core.config")
    local Scanner = require("org-roam.core.scanner")
    local utils = require("org-roam.core.utils")

    -- Normalize the roam directory before storing it
    opts.org_roam_directory = vim.fs.normalize(opts.org_roam_directory)

    -- Merge our configuration options into our global config
    ---@diagnostic disable-next-line:param-type-mismatch
    config:merge(opts)

    local notify = require("org-roam.core.ui").notify

    -- Load our database, creating it if it does not exist
    local Database = require("org-roam.core.database")
    local File = require("org-roam.core.database.file")
    local db_path = vim.fn.stdpath("data") .. "/org-roam.nvim/" .. "db.mpack"
    if not File:new(db_path):exists() then
        -- Need to create path to database
        local plugin_data_dir = vim.fs.dirname(db_path)
        vim.fn.mkdir(plugin_data_dir, "p")

        notify("Creating database", vim.log.levels.DEBUG)
        local db = Database:new()

        notify("Scanning for org files", vim.log.levels.INFO)
        Scanner:new({ config.org_roam_directory })
            :on_scan(function(scan)
                notify("Scanned " .. scan.path, vim.log.levels.DEBUG)
                for _, node in ipairs(scan.nodes) do
                    db:insert(node, { id = node.id })
                end
            end)
            :on_error(function(err) notify(err, vim.log.levels.ERROR) end)
            :on_done(function()
                db:write_to_disk(db_path, function(err)
                    if err then
                        notify(err, vim.log.levels.ERROR)
                        return
                    end

                    notify("Database saved to " .. db_path, vim.log.levels.INFO)
                    M.database = assert(db, "impossible: database unavailable after loaded")
                end)
            end)
            :start()
    else
        notify("Loading database from " .. db_path, vim.log.levels.DEBUG)
        Database:load_from_disk(db_path, function(err, db)
            if err then
                notify(err, vim.log.levels.ERROR)
                return
            end

            M.database = assert(db, "impossible: database unavailable after loaded")
        end)
    end
end

---Called to initialize the org-roam plugin.
---@param opts org-roam.core.config.Config.NewOpts
function M.setup(opts)
    -- NOTE: We need to schedule this and not invoke directly. It's already
    --       async, and not doing it this way can lead to neovim crashing.
    vim.schedule(function() setup(opts) end)
end

return M
