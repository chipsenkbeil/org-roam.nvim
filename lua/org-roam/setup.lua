-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local buffer   = require("org-roam.core.buffer")
local config   = require("org-roam.core.config")
local Database = require("org-roam.core.database")
local File     = require("org-roam.core.database.file")
local Scanner  = require("org-roam.core.scanner")
local ui       = require("org-roam.core.ui")
local utils    = require("org-roam.core.utils")

local notify   = ui.notify
local unpack   = utils.table.unpack

---Initializes the plugin's database.
---@param cb fun(db:org-roam.core.database.Database)
local function init_database(cb)
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
                    db:link(id, unpack(vim.tbl_keys(node.linked)))
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

local function define_autocmds()
    -- Define our autocommands for the plugin
    local GROUP = vim.api.nvim_create_augroup("OrgRoam", { clear = true })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = GROUP,
        pattern = "*",
        callback = function(args)
            ---@type integer
            local bufnr = args.buf
            buffer.set_dirty_flag(bufnr, true)
        end,
    })
end

---@param opts org-roam.core.config.Config.NewOpts
local function merge_config(opts)
    -- Normalize the roam directory before storing it
    opts.org_roam_directory = vim.fs.normalize(opts.org_roam_directory)

    -- Merge our configuration options into our global config
    ---@diagnostic disable-next-line:param-type-mismatch
    config:merge(opts)
end

local function define_keybindings()
    vim.api.nvim_set_keymap("n", "<LocalLeader>orb", "", {
        desc = "Open quickfix of backlinks for org-roam node under cursor",
        noremap = true,
        callback = function()
            require("org-roam").open_qflist_for_node_under_cursor()
        end,
    })
end

---Initializes the plugin, returning the database associated with nodes.
---@param opts org-roam.core.config.Config.NewOpts
---@param cb fun(db:org-roam.core.database.Database)
return function(opts, cb)
    define_autocmds()
    merge_config(opts)
    define_keybindings()

    -- NOTE: We must schedule this as some of the operations performed
    --       will cause neovim to crash on startup when setup is called
    --       if we do NOT schedule this to run on the main loop later.
    vim.schedule(function() init_database(cb) end)
end
