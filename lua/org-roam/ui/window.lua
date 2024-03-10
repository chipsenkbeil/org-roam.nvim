-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Primary user interface controls for org-roam specialized windows.
-------------------------------------------------------------------------------

local M = {}

---Launch an org-roam buffer that tracks the node currently at point.
---
---This means that the content of the buffer changes as the point is moved,
---if necessary.
function M.toggle_node_view()
end

---Launch an org-roam buffer for a specific node without visiting its file.
---
---Unlike `toggle_roam_buffer`, you can have multiple such buffers and their
---content won’t be automatically replaced with a new node at point.
---
---If an `id` is not specified, a prompt will appear to specify the id.
---@param id? org-roam.core.database.Id
function M.toggle_fixed_node_view(id)

end

return M
