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
    local config = require("org-roam.core.config")
    local parser = require("org-roam.core.parser")
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

        notify("Creating database", vim.log.levels.INFO)
        local db = Database:new()

        notify("Scanning for org files", vim.log.levels.INFO)
        local it = utils.io.walk(config.org_roam_directory, { depth = math.huge })
            :filter(function(entry) return entry.type == "file" end)
            :filter(function(entry) return vim.endswith(entry.filename, ".org") end)

        local function do_parse()
            if it:has_next() then
                ---@type org-roam.core.utils.io.WalkEntry
                local entry = it:next()

                notify("Parsing " .. entry.name, vim.log.levels.INFO)
                parser.parse_file(entry.path, function(err, file)
                    if err then
                        notify(err, vim.log.levels.ERROR)
                    elseif file then
                        -- TODO: We need to revise parsing AGAIN to connect
                        --       links somehow to the property drawers so
                        --       we know which node is doing the link...
                        for _, drawer in ipairs(file.drawers) do
                            local id

                            -- Find the ID property and load its value
                            for _, property in ipairs(drawer.properties) do
                                local name = string.lower(vim.trim(property.name:text()))
                                if name == "id" then
                                    id = vim.trim(property.value:text())
                                    break
                                end
                            end

                            -- TODO: Construct the node rather than faking, and
                            --       then search through links for id: schemes
                            --       to set as connections.
                            db:insert("node-" .. id, { id = id })
                        end
                    end

                    -- Repeat by scheduling to parse the next file
                    vim.schedule(do_parse)
                end)

                -- Exit so we wait for next scheduled parse
                return
            end

            db:write_to_disk(db_path, function(err)
                if err then
                    notify(err, vim.log.levels.ERROR)
                    return
                end

                notify("Database saved to " .. db_path, vim.log.levels.INFO)
                M.database = assert(db, "impossible: database unavailable after loaded")
            end)
        end

        do_parse()
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
