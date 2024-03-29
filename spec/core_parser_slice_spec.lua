describe("org-roam.core.parser.slice", function()
    local Slice = require("org-roam.core.parser.slice")
    local Range = require("org-roam.core.parser.range")
    local Ref = require("org-roam.core.parser.ref")

    describe("text", function()
        it("should return the text within the slice that matches the range", function()
            local s = Slice:new(
                Ref:new("abc"),
                Range:new({
                    row = 0,
                    column = 0,
                    offset = 0,
                }, {
                    row = 0,
                    column = 1,
                    offset = 1,
                })
            )
            assert.are.equal("ab", s:text())
        end)

        it("should refresh the cached value if refresh = true", function()
            local s = Slice:new(
                Ref:new("abc"),
                Range:new({
                    row = 0,
                    column = 0,
                    offset = 0,
                }, {
                    row = 0,
                    column = 2,
                    offset = 2,
                }),
                { cache = "hello" }
            )
            assert.are.equal("abc", s:text({ refresh = true }))
        end)

        it("should use the cached value if it exists", function()
            local s = Slice:new(
                Ref:new("abc"),
                Range:new({
                    row = 0,
                    column = 0,
                    offset = 0,
                }, {
                    row = 0,
                    column = 2,
                    offset = 2,
                }),
                { cache = "hello" }
            )
            assert.are.equal("hello", s:text())
        end)
    end)

    describe("from_string", function()
        it("should calculate range for string", function()
            local s

            -- row: 0 (1-1)
            -- col: 0 (1-1)
            -- offset: -1
            s = Slice:from_string("")
            assert.are.equal(0, s:start_row())
            assert.are.equal(0, s:start_column())
            assert.are.equal(-1, s:start_byte_offset())
            assert.are.equal(0, s:end_row())
            assert.are.equal(0, s:end_column())
            assert.are.equal(-1, s:end_byte_offset())

            -- abc
            -- 012
            --
            -- row: 0 (1-1)
            -- col: 2 (3-1)
            -- offset: 2 (3-1)
            s = Slice:from_string("abc")
            assert.are.equal(0, s:start_row())
            assert.are.equal(0, s:start_column())
            assert.are.equal(0, s:start_byte_offset())
            assert.are.equal(0, s:end_row())
            assert.are.equal(2, s:end_column())
            assert.are.equal(2, s:end_byte_offset())

            -- abc\n
            -- 012 3
            --
            -- row: 1 (2-1)
            -- col: 0 (1-1)
            -- offset: 3 (4-1)
            s = Slice:from_string("abc\n")
            assert.are.equal(0, s:start_row())
            assert.are.equal(0, s:start_column())
            assert.are.equal(0, s:start_byte_offset())
            assert.are.equal(1, s:end_row())
            assert.are.equal(0, s:end_column())
            assert.are.equal(3, s:end_byte_offset())

            -- abc\ndef
            -- 012 3456
            --
            -- row: 1 (2-1)
            -- col: 2 (3-1)
            -- offset: 6 (7-1)
            s = Slice:from_string("abc\ndef")
            assert.are.equal(0, s:start_row())
            assert.are.equal(0, s:start_column())
            assert.are.equal(0, s:start_byte_offset())
            assert.are.equal(1, s:end_row())
            assert.are.equal(2, s:end_column())
            assert.are.equal(6, s:end_byte_offset())
        end)
    end)
end)
