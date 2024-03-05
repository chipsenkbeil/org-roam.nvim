-------------------------------------------------------------------------------
-- WIDGET.LUA
--
-- Base interface for an org-roam buffer widget.
-------------------------------------------------------------------------------

---@class org-roam.buffer.Widget
---@field apply fun(opts:org-roam.buffer.widget.ApplyOpts)

---@class org-roam.buffer.widget.ApplyOpts
---@field buffer integer
---@field database org-roam.core.database.Database
---@field node org-roam.core.database.Node
