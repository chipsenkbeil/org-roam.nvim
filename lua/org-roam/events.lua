-------------------------------------------------------------------------------
-- EVENTS.LUA
--
-- Contains a global emitter used to send and receive events.
-------------------------------------------------------------------------------

local Emitter = require("org-roam.core.utils.emitter")

---@class org-roam.events.Emitter: org-roam.core.utils.Emitter
local EMITTER = Emitter:new()

---@enum org-roam.events.EventKind
EMITTER.KIND = {
    CURSOR_NODE_CHANGED = "cursor:node-changed",
}

---Register a callback when a cursor move results in the node under the
---cursor changing. This will also be triggered when the cursor moves
---to a position where there is no node.
---@param cb fun(node:org-roam.core.file.Node|nil)
function EMITTER.on_cursor_node_changed(cb)
    EMITTER:on(EMITTER.KIND.CURSOR_NODE_CHANGED, cb)
end

return EMITTER
