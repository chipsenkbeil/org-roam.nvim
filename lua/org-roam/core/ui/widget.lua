-------------------------------------------------------------------------------
-- WIDGET.LUA
--
-- Base interface for an org-roam widget.
-------------------------------------------------------------------------------

---@alias org-roam.core.ui.WidgetFunction
---| fun():org-roam.core.ui.Line[]

---@alias org-roam.core.ui.Line
---| string #raw line without any highlights
---| org-roam.core.ui.LineSegment[] #list of line segments with or without highlights

---@alias org-roam.core.ui.LineSegment
---| string #raw text without highlight group
---| {[1]:string, [2]:string} #tuple of text and highlight group

---@class org-roam.core.ui.Widget
---@field private __namespace integer
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
---@return {ok:true, lines:org-roam.core.ui.Line[]}|{ok:false, error:string}
function M:render()
    ---@type boolean, string|org-roam.core.ui.Line[]
    local ok, ret = pcall(self.__render)

    if ok then
        ---@cast ret -string
        return {
            ok = ok,
            lines = ret or {},
        }
    else
        ---@cast ret -table
        local error = vim.inspect(ret)
        return { ok = ok, error = error }
    end
end

return M
