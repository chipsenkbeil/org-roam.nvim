-------------------------------------------------------------------------------
-- WIDGET.LUA
--
-- Base interface for an org-roam widget.
-------------------------------------------------------------------------------

---@class org-roam.core.ui.Widget
---@field private __render fun(opts:org-roam.core.ui.widget.RenderOpts)
---@field private __rendering boolean
local M = {}
M.__index = M

---Creates a new org-roam ui widget.
---@param f fun(opts:org-roam.core.ui.widget.RenderOpts)
---@return org-roam.core.ui.Widget
function M:new(f)
    local instance = {}
    setmetatable(instance, M)

    instance.__render = f
    instance.__rendering = false

    return instance
end

---@class org-roam.core.ui.widget.RenderOpts
---@field append fun(lines:string[])
---@field db org-roam.core.database.Database
---@field emitter org-roam.core.utils.Emitter
---@field node org-roam.core.database.Node

---@param opts org-roam.core.ui.widget.RenderOpts
---@return boolean ok, string|nil err
function M:render(opts)
    if self.__rendering then
        return true
    end

    self.__rendering = true

    local ok, err = pcall(self.__render, opts)

    self.__rendering = false

    return ok, err and vim.inspect(err)
end

return M
