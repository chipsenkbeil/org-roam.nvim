-------------------------------------------------------------------------------
-- AUTOCMDS.LUA
--
-- Setup logic for roam autocmds.
-------------------------------------------------------------------------------

local AUGROUP = vim.api.nvim_create_augroup("org-roam.nvim", {})

local log = require("org-roam.core.log")

---@param roam OrgRoam
return function(roam)
    -- Watch as cursor moves around so we can support node changes
    local last_node = nil
    vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved" }, {
        group = AUGROUP,
        pattern = "*.org",
        callback = function()
            roam.utils.node_under_cursor(function(node)
                -- If the node has changed (event getting cleared),
                -- we want to emit the event
                if last_node ~= node then
                    if node then
                        log.fmt_debug("New node under cursor: %s", node.id)
                    end

                    roam.events.emit(roam.events.KIND.CURSOR_NODE_CHANGED, node)
                end

                last_node = node
            end)
        end,
    })

    -- If configured to update on save, listen for buffer writing
    -- and trigger reload if an org-roam buffer
    if roam.config.database.update_on_save then
        vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
            group = AUGROUP,
            pattern = "*.org",
            callback = function()
                -- TODO: If the directory format changes to blob in the
                --       future, this will break. Is there a better way
                --       to check if a file is an org-roam file?
                local path = vim.fn.expand("<afile>:p")
                local is_roam_file = vim.startswith(path, roam.config.directory)

                if is_roam_file then
                    log.fmt_debug("Updating on save: %s", path)
                    roam.database:load_file({ path = path }):catch(log.error)
                end
            end,
        })
    end

    -- If configured to persist to disk, look for when neovim is exiting
    -- and save an updated version of the database
    if roam.config.database.persist then
        vim.api.nvim_create_autocmd("VimLeavePre", {
            group = AUGROUP,
            pattern = "*",
            callback = function()
                -- Block, don't be async, as neovim could exit during async
                -- and cause issues with corrupt databases
                log.fmt_debug("Persisting database to disk: %s", roam.database:path())
                roam.database:save():catch(log.error):wait()
            end,
        })
    end
end
