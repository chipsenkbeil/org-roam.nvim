describe("org-roam.core.utils.iterator", function()
    local Iterator = require("org-roam.core.utils.iterator")

    it("should return next item by invoking user-provided function", function()
        local i = 0
        local it = Iterator:new(function()
            i = i + 1
            return i
        end)

        assert.equals(1, it:next())
        assert.equals(2, it:next())
        assert.equals(3, it:next())
    end)

    it("should support being created by calling the class as a function", function()
        local i = 0
        local it = Iterator(function()
            i = i + 1
            return i
        end)

        assert.equals(1, it:next())
        assert.equals(2, it:next())
        assert.equals(3, it:next())
    end)

    it("should support advancing by calling itself (instance only)", function()
        local i = 0
        local it = Iterator(function()
            i = i + 1
            if i < 4 then
                return i
            end
        end)

        local results = {}
        for n in it do
            table.insert(results, n)
        end

        assert.same({ 1, 2, 3 }, results)
    end)

    it("should advance the iterator until nothing is returned", function()
        local count = 0
        local it = Iterator:new(function()
            count = count + 1
            if count == 1 then
                return 123
            end
        end)

        -- Use the count to detect additional internal next() invocations
        assert.equals(0, count)
        assert.equals(123, it:next())
        assert.equals(1, count)
        assert.is_nil(it:next())
        assert.equals(2, count)
        assert.is_nil(it:next())
        assert.equals(2, count)
        assert.is_nil(it:next())
        assert.equals(2, count)
    end)

    it("should advance the iterator until nothing is returned (if allow_nil = true)", function()
        local count = 0
        local it = Iterator:new(function()
            count = count + 1
            if count == 1 then
                return nil
            end
        end, { allow_nil = true })

        -- Use the count to detect additional internal next() invocations
        assert.equals(0, count)
        assert.is_nil(it:next())
        assert.equals(1, count)
        assert.is_nil(it:next())
        assert.equals(2, count)
        assert.is_nil(it:next())
        assert.equals(2, count)
    end)

    it("should advance the iterator until nil is returned (if allow_nil = false)", function()
        local count = 0
        local it = Iterator:new(function()
            count = count + 1
            if count == 1 then
                return nil
            end
        end)

        -- Use the count to detect additional internal next() invocations
        assert.equals(0, count)
        assert.is_nil(it:next())
        assert.equals(1, count)
        assert.is_nil(it:next())
        assert.equals(1, count)
    end)

    it("should support detecting if there is a next item", function()
        local done = false
        local it = Iterator:new(function()
            if not done then
                done = true
                return 123
            end
        end)

        assert.is_true(it:has_next())
        assert.equals(123, it:next())
        assert.is_false(it:has_next())
    end)

    it("should support detecting if there is a next item that is nil (if allow_nil = true)", function()
        local done = false
        local it = Iterator:new(function()
            if not done then
                done = true
                return nil
            end
        end, { allow_nil = true })

        assert.is_true(it:has_next())
        assert.is_nil(it:next())
        assert.is_false(it:has_next())
        assert.is_nil(it:next())
    end)

    it("should support mapping values", function()
        local count = 0
        local it = Iterator:new(function()
            if count < 3 then
                count = count + 1
                return count
            end
        end)

        -- Trigger has_next so we have a cached value
        -- to verify that mapping after this point
        -- will still work
        it:has_next()

        it = it:map(function(n)
            return "num:" .. tostring(n)
        end)

        assert.same({ "num:1", "num:2", "num:3" }, it:collect())
    end)

    it("should support filtering values", function()
        local count = 0
        local it = Iterator:new(function()
            count = count + 1
            if count <= 10 then
                return count
            end
        end)

        -- Trigger has_next so we have a cached value
        -- to verify that filtering after this point
        -- will still work
        it:has_next()

        it = it:filter(function(n)
            return n % 2 == 0
        end)

        assert.same({ 2, 4, 6, 8, 10 }, it:collect())
    end)

    it("should support collecting into a list by repeatedly advancing the iterator", function()
        local count = 0
        local it = Iterator:new(function()
            if count < 3 then
                count = count + 1
                return count
            end
        end)

        assert.same({ 1, 2, 3 }, it:collect())
    end)

    it("should support collecting vararg returns from next", function()
        local count = 0
        local it = Iterator:new(function()
            if count < 3 then
                count = count + 1
                local results = {}
                for i = 1, count do
                    table.insert(results, i)
                end
                return unpack(results)
            end
        end)

        assert.same({
            1,
            { [1] = 1, [2] = 2, n = 2 },
            { [1] = 1, [2] = 2, [3] = 3, n = 3 },
        }, it:collect())
    end)
end)
