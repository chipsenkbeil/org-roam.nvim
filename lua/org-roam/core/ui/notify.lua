-------------------------------------------------------------------------------
-- NOTIFY.LUA
--
-- Implementation of notifications.
-------------------------------------------------------------------------------

---@alias org-roam.core.ui.notify.Level
---| 0
---| 1
---| 2
---| 3
---| 4

---Wrapper around `vim.notify` that schedules the notification to avoid issues
---with it being triggered in a Lua loop callback, which is not allowed.
---@param this table
---@param msg string
---@param level? org-roam.core.ui.notify.Level
---@param opts? table
---@diagnostic disable-next-line:unused-local
local function notify(this, msg, level, opts)
    vim.schedule(function()
        vim.notify(
            msg,
            level,
            vim.tbl_extend("force", opts or {}, { title = "org-roam" })
        )
    end)
end

---@class org-roam.core.ui.Notify
---@overload fun(msg:string, level:org-roam.core.ui.notify.Level|nil, opts:table|nil)
local M = setmetatable({}, {
    __call = notify,
})

---Submits a trace-level notification.
---@param msg string
---@param opts? table
function M.trace(msg, opts)
    notify({}, msg, vim.log.levels.TRACE, opts)
end

---Submits a debug-level notification.
---@param msg string
---@param opts? table
function M.debug(msg, opts)
    notify({}, msg, vim.log.levels.DEBUG, opts)
end

---Submits an info-level notification.
---@param msg string
---@param opts? table
function M.info(msg, opts)
    notify({}, msg, vim.log.levels.INFO, opts)
end

---Submits a warn-level notification.
---@param msg string
---@param opts? table
function M.warn(msg, opts)
    notify({}, msg, vim.log.levels.WARN, opts)
end

---Submits an error-level notification.
---@param msg string
---@param opts? table
function M.error(msg, opts)
    notify({}, msg, vim.log.levels.ERROR, opts)
end

return M
