-------------------------------------------------------------------------------
-- AUTOCMDS.LUA
--
-- Setup logic for roam autocmds.
-------------------------------------------------------------------------------

---@param roam OrgRoam
return function(roam)
    local group = roam.__augroup

    -- Watch as cursor moves around so we can support node changes
    local last_node = nil
    vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved" }, {
        group = group,
        pattern = "*.org",
        callback = function()
            roam.utils.node_under_cursor(function(node)
                -- Only report when the node has changed
                if last_node ~= node then
                    if node then
                        require("org-roam.core.log").fmt_debug("New node under cursor: %s", node.id)
                        vim.api.nvim_exec_autocmds("User", {
                            pattern = "OrgRoamNodeEnter",
                            modeline = false,
                            data = node,
                        })
                    end

                    if last_node then
                        vim.api.nvim_exec_autocmds("User", {
                            pattern = "OrgRoamNodeLeave",
                            modeline = false,
                            data = last_node,
                        })
                    end
                end

                last_node = node
            end)
        end,
    })

    -- If configured to update on save, listen for buffer writing
    -- and trigger reload if an org-roam buffer
    if roam.config.database.update_on_save then
        vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
            group = group,
            pattern = "*.org",
            callback = function()
                -- TODO: If the directory format changes to blob in the
                --       future, this will break. Is there a better way
                --       to check if a file is an org-roam file?
                local path = vim.fn.expand("<afile>:p")
                local is_roam_file = vim.startswith(path, roam.config.directory)

                if is_roam_file then
                    require("org-roam.core.log").fmt_debug("Updating on save: %s", path)
                    roam.database:load_file({ path = path }):catch(require("org-roam.core.log").error)
                end
            end,
        })
    end

    -- If configured to persist to disk, look for when neovim is exiting
    -- and save an updated version of the database
    if roam.config.database.persist then
        vim.api.nvim_create_autocmd("VimLeavePre", {
            group = group,
            pattern = "*",
            callback = function()
                -- Block, don't be async, as neovim could exit during async
                -- and cause issues with corrupt databases
                require("org-roam.core.log").fmt_debug("Persisting database to disk: %s", roam.database:path())
                roam.database:save():catch(require("org-roam.core.log").error):wait()
            end,
        })
    end
end
