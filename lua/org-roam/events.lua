-------------------------------------------------------------------------------
-- EVENTS.LUA
--
-- Contains a global emitter used to send and receive events.
-------------------------------------------------------------------------------

local Emitter = require("org-roam.core.utils.emitter")

---@class org-roam.events.Emitter: org-roam.core.utils.Emitter
local EMITTER = Emitter:new()

---@enum org-roam.events.EventKind
EMITTER.kind = {
    CURSOR_NODE_CHANGED = "cursor:node-changed",
}

return EMITTER
