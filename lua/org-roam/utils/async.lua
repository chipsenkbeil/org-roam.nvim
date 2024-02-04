-------------------------------------------------------------------------------
-- ASYNC.LUA
--
-- Utilities to do async operations.
-------------------------------------------------------------------------------

---@class org-roam.utils.Async
local M = {}

---Wraps an asynchronous function that leverages a callback
---as its last argument, converting it into a function that
---will wait for the callback to succeed by leveraging
---`vim.wait`, which enables nvim to process other events.
---
---Note: cannot be called within fast callbacks.
---
---Accepts options to configure how to wait for writing to finish.
---
---* `time`: the milliseconds to wait for writing to finish.
--   Defaults to waiting forever by using `math.huge`.
---* `interval`: the millseconds between attempts to check that writing
---  has finished. Defaults to 200 milliseconds.
---
---Returns a function that, when called, will invoke the
---asynchronous function and wait for the results, returning
---the results from the callback, or throwing an error if
---a timeout or interruption occurs.
---@param f fun(...)
---@param opts? {time?:integer,interval?:integer}
---@return fun(...):...
function M.wrap(f, opts)
    opts = opts or {}

    local TIME = opts.time or math.huge
    local INTERVAL = opts.interval or 200

    return function(...)
        -- NOTE: As of neovim 0.10, we can no longer call `vim.wait` within a fast
        --       callback; however, in earlier versions this would cause a crash,
        --       so we wouldn't want to call it in there regardless. So check if
        --       we are in a fast loop and throw an error to ensure that we never
        --       reach that situation.
        assert(not vim.in_fast_event(), "Cannot be called from fast callback")

        local results = { done = false }
        f(..., function(...)
            local tbl = require("org-roam.utils.table").pack(...)
            for i = 1, tbl.n do
                results[i] = tbl[i]
            end
            results.done = true
        end)

        local success, err = vim.wait(
            TIME,
            function() return results.done end,
            INTERVAL
        )
    end
end

return M
