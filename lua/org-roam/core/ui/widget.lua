-------------------------------------------------------------------------------
-- WIDGET.LUA
--
-- Base interface for an org-roam widget.
-------------------------------------------------------------------------------

---@alias org-roam.core.ui.WidgetFunction fun():string[]

---@class org-roam.core.ui.Widget
---@field private __render org-roam.core.ui.WidgetFunction
local M = {}
M.__index = M

---Creates a new org-roam ui widget.
---@param render org-roam.core.ui.WidgetFunction
---@return org-roam.core.ui.Widget
function M:new(render)
    local instance = {}
    setmetatable(instance, M)

    instance.__render = render

    return instance
end

---Renders the contents of the widget, returning an object representing the
---results.
---
---If successful, `ok` is true and `lines` contains the lines rendered.
---If unsuccessful, `ok` is false and `error` contains an error message.
---@return {ok:true, lines:string[]}|{ok:false, error:string}
function M:render()
    ---@type boolean, string|string[]
    local ok, ret = pcall(self.__render)

    if ok then
        ---@cast ret -string
        local lines = ret or {}
        return { ok = ok, lines = lines }
    else
        ---@cast ret -table
        local error = vim.inspect(ret)
        return { ok = ok, error = error }
    end
end

return M
