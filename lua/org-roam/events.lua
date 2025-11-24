-------------------------------------------------------------------------------
-- EVENTS.LUA
--
-- Contains a global emitter used to send and receive events.
-------------------------------------------------------------------------------

---@param roam OrgRoam
---@return org-roam.Events
return function(roam)
    ---@class org-roam.Events
    local M = {}

    local EMITTER = require("org-roam.core.utils.emitter"):new()

    ---@enum org-roam.events.EventKind
    M.KIND = {
        CURSOR_NODE_CHANGED = "cursor:node-changed",
    }

    ---Emits the specified event to trigger all associated handlers
    ---and passes all additional arguments to the handler.
    ---@param event any # event to emit
    ---@param ... any # additional arguments to get passed to handlers
    ---@return org-roam.Events
    function M.emit(event, ...)
        EMITTER:emit(event, ...)
        return M
    end

    ---Registers a callback to be invoked when the specified event is emitted.
    ---More than one handler can be associated with the same event.
    ---@param event any # event to receive
    ---@param handler fun(...) # callback to trigger on event
    ---@return org-roam.Events
    function M.on(event, handler)
        EMITTER:on(event, handler)
        return M
    end

    ---Registers a callback to be invoked when the specified event is emitted.
    ---Upon being triggered, the handler will be removed.
    ---
    ---More than one handler can be associated with the same event.
    ---@param event any # event to receive
    ---@param handler fun(...) # callback to trigger on event
    ---@return org-roam.Events
    function M.once(event, handler)
        EMITTER:once(event, handler)
        return M
    end

    ---Unregisters the callback for the specified event.
    ---@param event any # event whose handler to remove
    ---@param handler fun(...) # handler to remove
    ---@return org-roam.Events
    function M.off(event, handler)
        EMITTER:off(event, handler)
        return M
    end

    ---Register a callback when a cursor move results in the node under the
    ---cursor changing. This will also be triggered when the cursor moves
    ---to a position where there is no node.
    ---@param cb fun(node:org-roam.core.file.Node|nil)
    function M.on_cursor_node_changed(cb)
        M.on(M.KIND.CURSOR_NODE_CHANGED, cb)
    end

    return M
end
