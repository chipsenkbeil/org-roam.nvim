describe("org-roam.core.utils.queue", function()
    local Queue = require("org-roam.core.utils.queue")

    it("should be empty by default", function()
        local queue = Queue:new()
        assert.is_true(queue:is_empty())
        assert.are.equal(0, queue:len())
    end)

    it("should support being created by calling the class as a function", function()
        local queue = Queue()
        assert.is_true(queue:is_empty())
        assert.are.equal(0, queue:len())
    end)

    it("should support being populated from a list", function()
        local queue = Queue:new({ 1, 2, 3 })
        assert.is_false(queue:is_empty())
        assert.are.equal(3, queue:len())
        assert.are.equal(1, queue:peek_front())
        assert.are.equal(3, queue:peek_back())
        assert.are.same({ 1, 2, 3 }, queue:contents())
    end)

    it("should correctly report total items", function()
        local queue = Queue:new()
        assert.are.equal(0, queue:len())

        queue:push_front(0)
        assert.are.equal(1, queue:len())

        queue:push_back(0)
        assert.are.equal(2, queue:len())

        queue:pop_front()
        assert.are.equal(1, queue:len())

        queue:pop_back()
        assert.are.equal(0, queue:len())
    end)

    it("should correctly report whether empty or not", function()
        local queue = Queue:new()
        assert.is_true(queue:is_empty())

        queue:push_front(0)
        assert.is_false(queue:is_empty())

        queue:pop_front()
        assert.is_true(queue:is_empty())
    end)

    it("should be able to push new values to the front", function()
        local queue = Queue:new()

        queue:push_front(1)
        assert.are.equal(1, queue:peek_front())

        queue:push_front(2)
        assert.are.equal(2, queue:peek_front())
    end)

    it("should be able to pop values from the front", function()
        local queue = Queue:new({ 1, 2, 3 })
        assert.are.equal(1, queue:pop_front())
        assert.are.equal(2, queue:pop_front())
        assert.are.equal(3, queue:pop_front())
    end)

    it("should be able to push new values to the back", function()
        local queue = Queue:new()

        queue:push_back(1)
        assert.are.equal(1, queue:peek_back())

        queue:push_back(2)
        assert.are.equal(2, queue:peek_back())
    end)

    it("should be able to pop values from the back", function()
        local queue = Queue:new({ 1, 2, 3 })
        assert.are.equal(3, queue:pop_back())
        assert.are.equal(2, queue:pop_back())
        assert.are.equal(1, queue:pop_back())
    end)

    it("should throw an error if popping values from an empty queue", function()
        local queue = Queue:new()
        assert.is_false(pcall(queue.pop_front, queue))
        assert.is_false(pcall(queue.pop_back, queue))
    end)

    it("should be able to peek at the value from the front", function()
        local queue = Queue:new()
        queue:push_front(123)
        assert.are.equal(123, queue:peek_front())

        queue = Queue:new({ 1, 2, 3 })
        assert.are.equal(1, queue:peek_front())
    end)

    it("should be able to peek at the value from the back", function()
        local queue = Queue:new()
        queue:push_back(123)
        assert.are.equal(123, queue:peek_back())

        queue = Queue:new({ 1, 2, 3 })
        assert.are.equal(3, queue:peek_back())
    end)

    it("should throw an error if peeking values from an empty queue", function()
        local queue = Queue:new()
        assert.is_false(pcall(queue.peek_front, queue))
        assert.is_false(pcall(queue.peek_back, queue))
    end)
end)
