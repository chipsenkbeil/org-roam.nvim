describe("utils.async", function()
    local async = require("org-roam.core.utils.async")

    describe("wait", function()
        it("should wrap an async function, invoke it, and wait indefinitely for it to complete", function()
            ---Echoes back a and b in the callback.
            ---@param a string
            ---@param b integer
            ---@param cb fun(c:string, d:integer)
            local function echo_fn(a, b, cb)
                cb(a, b)
            end

            --NOTE: Haven't been able to figure out the generic typing to get the
            --      function's arguments and callback values to be echoed; so,
            --      we would need to define the return types like below for now.
            ---@type string, integer
            local a, b = async.wait(echo_fn, "hello", 123)

            assert.equals("hello", a)
            assert.equals(123, b)
        end)
    end)

    describe("wrap", function()
        it("should produce a function that fails if timeout exceeded", function()
            local function test_fn(_)
                -- Never invoke the callback, so timeout will be exceeded
            end

            -- Wait maximum of 300ms before failing
            ---@type fun()
            local test_fn_sync = async.wrap(test_fn, { time = 300 })

            local success, err = pcall(test_fn_sync)
            assert.is_false(success)
            assert.is_not_nil(string.match(err, "timeout"))
        end)

        it("should produce a function that returns the results from a callback", function()
            local count = 0

            ---@type fun():(string|nil, integer|nil)
            local test_fn_sync = async.wrap(function(cb)
                count = count + 1

                if count == 1 then
                    cb("start", count)
                elseif count == 2 then
                    cb(nil, count)
                else
                    cb("done", nil)
                end
            end, { time = 300 })

            local res1, res2 = test_fn_sync()
            assert.equals("start", res1)
            assert.equals(1, res2)

            res1, res2 = test_fn_sync()
            assert.is_nil(res1)
            assert.equals(2, res2)

            res1, res2 = test_fn_sync()
            assert.equals("done", res1)
            assert.is_nil(res2)
        end)

        it("should produce a function and pass in arguments to it", function()
            local count = 0

            -- NOTE: We are supplying `n` to ensure a message is
            --       always provided instead of risking the callback
            --       being injected early. This lets us support optional
            --       arguments being supplied to the async function.
            ---@type fun(msg?:string):(string|nil, integer|nil)
            local test_fn_sync = async.wrap(function(msg, cb)
                count = count + 1
                cb(msg, count)
            end, { time = 300 })

            local res1, res2 = test_fn_sync("hello")
            assert.equals("hello", res1)
            assert.equals(1, res2)

            res1, res2 = test_fn_sync("world")
            assert.equals("world", res1)
            assert.equals(2, res2)
        end)

        it("should support option n to enforce a minimum argument length", function()
            local count = 0

            -- NOTE: We are supplying `n` to ensure a message is
            --       always provided instead of risking the callback
            --       being injected early. This lets us support optional
            --       arguments being supplied to the async function.
            ---@type fun(msg?:string):(string|nil, integer|nil)
            local test_fn_sync = async.wrap(function(msg, cb)
                count = count + 1
                cb(msg, count)
            end, { time = 300, n = 1 })

            local res1, res2 = test_fn_sync("hello")
            assert.equals("hello", res1)
            assert.equals(1, res2)

            -- Notice here that we do not supply the optional argument.
            -- If we did not set `n` above, this would cause an error
            -- where the callback was placed in the `msg` parameter slot.
            res1, res2 = test_fn_sync()
            assert.is_nil(res1)
            assert.equals(2, res2)
        end)
    end)
end)
