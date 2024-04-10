-------------------------------------------------------------------------------
-- ASYNC.LUA
--
-- Utilities to do async operations.
-------------------------------------------------------------------------------

local pack = require("org-roam.core.utils.table").pack
local unpack = require("org-roam.core.utils.table").unpack

---Maximum timeout (in seconds) for `vim.wait`.
---Needed as `math.huge` is too big for `vim.wait` to support.
---@type integer
local MAX_TIMEOUT = 2 ^ 31

---@class org-roam.core.utils.Async
local M = {}

---Wraps the asynchronous function, invokes it, and waits for results.
---
---NOTE: This is a convenience around `async.wrap` and then invoking
---the returned function. Due to design constraints, there is not a
---way to supply options to `async.wrap` call; so, if you need to
---configure the time, interval, or other options, use `async.wrap`
---instead.
---@generic T, U
---@param f fun(...:T, cb:fun(...:U))
---@param ...T
---@return U ...
function M.wait(f, ...)
    return M.wrap(f)(...)
end

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
---* `n`: the maximum number of arguments the function expects to receive,
---  which will be used to pad arguments supplied to the function
---  before the callback is appended. Use this to ensure that
---  optional arguments for the function are filled in with nil
---  instead of the callback being moved to an earlier position.
---
---Returns a function that, when called, will invoke the
---asynchronous function and wait for the results, returning
---the results from the callback, or throwing an error if
---a timeout or interruption occurs.
---@generic T, U
---@param f fun(...:T, cb:fun(...:U))
---@param opts? {time?:integer,interval?:integer,n?:integer}
---@return fun(...:T):(...:U)
function M.wrap(f, opts)
    opts = opts or {}

    local TIME = opts.time or MAX_TIMEOUT
    local INTERVAL = opts.interval or 200

    return function(...)
        -- NOTE: As of neovim 0.10, we can no longer call `vim.wait` within a fast
        --       callback; however, in earlier versions this would cause a crash,
        --       so we wouldn't want to call it in there regardless. So check if
        --       we are in a fast loop and throw an error to ensure that we never
        --       reach that situation.
        assert(not vim.in_fast_event(), "Cannot be called from fast callback")

        ---@type {done:boolean, n:integer, [integer]:unknown}
        local results = { done = false, n = 0 }

        -- Build up the arguments to feed into the asynchronous function,
        -- padding the total length if necessary
        local args = pack(...)
        if opts.n and args.n < opts.n then
            -- In this case, we were given a fixed argument length, so
            -- we override the current argument length (padding with nil)
            -- if it is smaller than the fixed argument length
            args.n = opts.n
        end
        args.n = args.n + 1
        args[args.n] = function(...)
            local tbl = pack(...)
            for i = 1, tbl.n do
                results[i] = tbl[i]
            end
            results.n = tbl.n
            results.done = true
        end

        f(unpack(args, 1, args.n))

        local success, err = vim.wait(
            TIME,
            function() return results.done end,
            INTERVAL
        )

        -- If we failed to wait, throw an error based on the code
        if not success then
            if err == -1 then
                error("timeout: exceeded " .. tostring(TIME) .. "ms")
            elseif err == -2 then
                error("interrupted")
            else
                error("unknown")
            end
        end

        -- Otherwise, we got results, so return them
        return unpack(results, 1, results.n)
    end
end

return M
