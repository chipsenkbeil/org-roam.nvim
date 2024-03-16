describe("org-roam.core.parser.utils", function()
    local utils = require("org-roam.core.parser.utils")

    describe("parse_property_value", function()
        it("should parse unquoted values delimited by whitespace", function()
            local value = "one two three"
            assert.same({ "one", "two", "three" }, utils.parse_property_value(value))
        end)

        it("should group quoted values together", function()
            local value = "a \"b c\" d"
            assert.same({ "a", "b c", "d" }, utils.parse_property_value(value))
        end)

        it("should support the entire value being quoted", function()
            local value = "\"a b c\""
            assert.same({ "a b c" }, utils.parse_property_value(value))
        end)
    end)

    describe("parse_tags", function()
        it("should parse tags into a list", function()
            assert.same({}, utils.parse_tags("::"))
            assert.same({ "abc" }, utils.parse_tags(":abc:"))
            assert.same({ "abc", "def" }, utils.parse_tags(":abc:def:"))
        end)
    end)
end)
