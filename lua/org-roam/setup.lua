local config   = require("org-roam.core.config")
local Database = require("org-roam.core.database")
local File     = require("org-roam.core.database.file")
local Scanner  = require("org-roam.core.scanner")
local ui       = require("org-roam.core.ui")
local utils    = require("org-roam.core.utils")

local notify   = ui.notify
local unpack   = utils.table.unpack

---Initializes the plugin, returning the database associated with nodes.
---@param opts org-roam.core.config.Config.NewOpts
---@param cb fun(db:org-roam.core.database.Database)
local function setup(opts, cb)
    -- Normalize the roam directory before storing it
    opts.org_roam_directory = vim.fs.normalize(opts.org_roam_directory)

    -- Merge our configuration options into our global config
    ---@diagnostic disable-next-line:param-type-mismatch
    config:merge(opts)

    -- Load our database, creating it if it does not exist
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
                    local id = db:insert(node, { id = node.id })
                    db:link(id, unpack(node.linked))
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
                    cb(assert(db, "impossible: database unavailable after loaded"))
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

            cb(assert(db, "impossible: database unavailable after loaded"))
        end)
    end
end

---Initializes the plugin, returning the database associated with nodes.
---@param opts org-roam.core.config.Config.NewOpts
---@param cb fun(db:org-roam.core.database.Database)
return function(opts, cb)
    -- NOTE: We must schedule this as some of the operations performed
    --       will cause neovim to crash on startup when setup is called
    --       if we do NOT schedule this to run on the main loop later.
    vim.schedule(function() setup(opts, cb) end)
end
