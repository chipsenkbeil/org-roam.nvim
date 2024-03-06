-------------------------------------------------------------------------------
-- NOTIFY.LUA
--
-- Implementation of notifications.
-------------------------------------------------------------------------------

---Wrapper around `vim.notify` that schedules the notification to avoid issues
---with it being triggered in a Lua loop callback, which is not allowed.
---@param msg string
---@param level? integer
---@param opts? table
return function(msg, level, opts)
    vim.schedule(function()
        vim.notify(
            msg,
            level,
            vim.tbl_extend("force", opts or {}, { title = "org-roam" })
        )
    end)
end
