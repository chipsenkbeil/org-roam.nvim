describe("org-roam.parser.Slice", function()
    local Slice = require("org-roam.parser.slice")
    local Ref = require("org-roam.parser.ref")

    describe("from_string", function()
        it("should calculate range for string", function()
            local s

            -- row: 0 (1-1)
            -- col: 0 (1-1)
            -- offset: -1
            s = Slice:from_string("")
            assert.equals(0, s:start_row())
            assert.equals(0, s:start_column())
            assert.equals(-1, s:start_byte_offset())
            assert.equals(0, s:end_row())
            assert.equals(0, s:end_column())
            assert.equals(-1, s:end_byte_offset())

            -- abc
            -- 012
            --
            -- row: 0 (1-1)
            -- col: 2 (3-1)
            -- offset: 2 (3-1)
            s = Slice:from_string("abc")
            assert.equals(0, s:start_row())
            assert.equals(0, s:start_column())
            assert.equals(0, s:start_byte_offset())
            assert.equals(0, s:end_row())
            assert.equals(2, s:end_column())
            assert.equals(2, s:end_byte_offset())

            -- abc\n
            -- 012 3
            --
            -- row: 1 (2-1)
            -- col: 0 (1-1)
            -- offset: 3 (4-1)
            s = Slice:from_string("abc\n")
            assert.equals(0, s:start_row())
            assert.equals(0, s:start_column())
            assert.equals(0, s:start_byte_offset())
            assert.equals(1, s:end_row())
            assert.equals(0, s:end_column())
            assert.equals(3, s:end_byte_offset())

            -- abc\ndef
            -- 012 3456
            --
            -- row: 1 (2-1)
            -- col: 2 (3-1)
            -- offset: 6 (7-1)
            s = Slice:from_string("abc\ndef")
            assert.equals(0, s:start_row())
            assert.equals(0, s:start_column())
            assert.equals(0, s:start_byte_offset())
            assert.equals(1, s:end_row())
            assert.equals(2, s:end_column())
            assert.equals(6, s:end_byte_offset())
        end)
    end)
end)
