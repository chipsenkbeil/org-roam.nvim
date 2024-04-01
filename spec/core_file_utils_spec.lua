describe("org-roam.core.file.utils", function()
    local utils = require("org-roam.core.file.utils")

    describe("parse_property_value", function()
        it("should parse unquoted values delimited by whitespace", function()
            local value = "one two three"
            assert.are.same({ "one", "two", "three" }, utils.parse_property_value(value))
        end)

        it("should group quoted values together", function()
            local value = "a \"b c\" d"
            assert.are.same({ "a", "b c", "d" }, utils.parse_property_value(value))
        end)

        it("should support the entire value being quoted", function()
            local value = "\"a b c\""
            assert.are.same({ "a b c" }, utils.parse_property_value(value))
        end)

        it("should support escaped quotes within value", function()
            local value = "a \"b \\\"c\\\" d\" e\\\"f"
            assert.are.same({ "a", "b \"c\" d", "e\"f" }, utils.parse_property_value(value))
        end)
    end)
end)
