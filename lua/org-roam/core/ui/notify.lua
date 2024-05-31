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
        vim.notify(msg, level, vim.tbl_extend("force", opts or {}, { title = "org-roam" }))
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

---@param msg string|table
---@param additional_msg? table
---@param store_in_history? boolean
function M.echo_warning(msg, additional_msg, store_in_history)
    return M.__echo(msg, "WarningMsg", additional_msg, store_in_history)
end

---@param msg string|table
---@param additional_msg? table
---@param store_in_history? boolean
function M.echo_error(msg, additional_msg, store_in_history)
    return M.__echo(msg, "ErrorMsg", additional_msg, store_in_history)
end

---@param msg string|table
---@param additional_msg? table
---@param store_in_history? boolean
function M.echo_info(msg, additional_msg, store_in_history)
    return M.__echo(msg, nil, additional_msg, store_in_history)
end

---Concat one table at the end of another table.
---@param first table
---@param second table
---@param unique? boolean
---@return table
local function concat(first, second, unique)
    for _, v in ipairs(second) do
        if not unique or not vim.tbl_contains(first, v) then
            table.insert(first, v)
        end
    end
    return first
end

---@private
function M.__echo(msg, hl, additional_msg, store_in_history)
    vim.cmd([[redraw!]])
    if type(msg) == "table" then
        msg = table.concat(msg, "\n")
    end
    local msg_item = { string.format("[org-roam] %s", msg) }
    if hl then
        table.insert(msg_item, hl)
    end
    local msg_list = { msg_item }
    if additional_msg then
        msg_list = concat(msg_list, additional_msg)
    end
    local store = true
    if type(store_in_history) == "boolean" then
        store = store_in_history
    end
    return vim.api.nvim_echo(msg_list, store, {})
end

return M
