-------------------------------------------------------------------------------
-- COMMANDS.LUA
--
-- Setup logic for roam commands.
-------------------------------------------------------------------------------

---@param roam OrgRoam
return function(roam)
    vim.api.nvim_create_user_command("RoamSave", function(opts)
        local force = opts.bang or false
        local args = opts.args or ""
        local sync = string.lower(vim.trim(args)) == "sync"
        require("org-roam.core.log").fmt_debug("Saving database (sync = %s)", sync)

        -- Start profiling so we can report the time taken
        local profiler = require("org-roam.core.utils.profiler"):new()
        profiler:start()

        local promise = roam.database
            :save({ force = force })
            :next(function(...)
                local tt = profiler:stop():time_taken_as_string()
                require("org-roam.core.ui.notify").info("Saved database [took " .. tt .. "]")
                return ...
            end)
            :catch(require("org-roam.core.ui.notify").error)

        if sync then
            promise:wait()
        end
    end, {
        bang = true,
        desc = "Saves the roam database to disk",
        nargs = "?",
    })

    vim.api.nvim_create_user_command("RoamUpdate", function(opts)
        local force = opts.bang or false
        local args = opts.args or ""
        local sync = string.lower(vim.trim(args)) == "sync"

        -- Start profiling so we can report the time taken
        local profiler = require("org-roam.core.utils.profiler"):new()
        profiler:start()

        require("org-roam.core.log").fmt_debug("Updating database (force = %s, sync = %s)", force, sync)
        local promise = roam.database
            :load({ force = force or "scan" })
            :next(function(...)
                local tt = profiler:stop():time_taken_as_string()
                require("org-roam.core.ui.notify").info("Updated database [took " .. tt .. "]")
                return ...
            end)
            :catch(require("org-roam.core.ui.notify").error)

        if sync then
            promise:wait()
        end
    end, {
        bang = true,
        desc = "Updates the roam database",
        nargs = "?",
    })

    vim.api.nvim_create_user_command("RoamReset", function(opts)
        local args = opts.args or ""
        local sync = string.lower(vim.trim(args)) == "sync"

        require("org-roam.core.log").fmt_debug("Resetting database (sync = %s)", sync)
        local promise = roam.database:delete_disk_cache():next(function(success)
            roam.database = roam.database:new({
                db_path = roam.database:path(),
                directory = roam.database:files_path(),
            })

            -- Start profiling so we can report the time taken
            local profiler = require("org-roam.core.utils.profiler"):new()
            profiler:start()
            return roam.database
                :load()
                :next(function(...)
                    local tt = profiler:stop():time_taken_as_string()
                    require("org-roam.core.ui.notify").info("Loaded database [took " .. tt .. "]")
                    return ...
                end)
                :catch(require("org-roam.core.ui.notify").error)
        end)

        if sync then
            promise:wait()
        end
    end, {
        desc = "Resets the roam database (wipe and rebuild)",
        nargs = "?",
    })

    vim.api.nvim_create_user_command("RoamAddAlias", function(opts)
        ---@type string|nil
        local alias = vim.trim(opts.args)
        if alias and alias == "" then
            alias = nil
        end

        roam.api.add_alias({ alias = alias })
    end, {
        desc = "Adds an alias to the current node under cursor",
        nargs = "*",
    })

    vim.api.nvim_create_user_command("RoamRemoveAlias", function(opts)
        local all = opts.bang or false

        ---@type string|nil
        local alias = vim.trim(opts.args)
        if alias and alias == "" then
            alias = nil
        end

        roam.api.remove_alias({ alias = alias, all = all })
    end, {
        bang = true,
        desc = "Removes an alias from the current node under cursor",
        nargs = "*",
    })

    vim.api.nvim_create_user_command("RoamAddOrigin", function(opts)
        ---@type string|nil
        local origin = vim.trim(opts.args)
        if origin and origin == "" then
            origin = nil
        end

        roam.api.add_origin({ origin = origin })
    end, {
        desc = "Adds an origin to the current node under cursor",
        nargs = "*",
    })

    vim.api.nvim_create_user_command("RoamRemoveOrigin", function()
        roam.api.remove_origin()
    end, {
        desc = "Removes an origin from the current node under cursor",
    })
end
