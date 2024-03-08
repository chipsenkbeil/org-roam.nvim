-------------------------------------------------------------------------------
-- WIDGET.LUA
--
-- Base interface for an org-roam widget.
-------------------------------------------------------------------------------

---@class org-roam.core.ui.Widget
---@field private __render fun(buffer:org-roam.core.ui.Buffer)
local M = {}
M.__index = M

---Creates a new org-roam ui widget.
---@param render fun(buffer:org-roam.core.ui.Buffer)
---@return org-roam.core.ui.Widget
function M:new(render)
    local instance = {}
    setmetatable(instance, M)

    instance.__render = render

    return instance
end

---@param buffer org-roam.core.ui.Buffer
---@return boolean ok, string|nil err
function M:render(buffer)
    local ok, err = pcall(self.__render, buffer)
    return ok, err and vim.inspect(err)
end

return M
