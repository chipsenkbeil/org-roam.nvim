describe("utils.uri", function()
    local Uri = require("org-roam.core.utils.uri")

    it("should support being parsed from a string", function()
        -- Just a scheme with nothing else
        assert.same({
            scheme = "id",
            path = "",
        }, Uri:parse("id:"))

        -- Just a scheme and path
        assert.same({
            scheme = "id",
            path = "abcd-efgh",
        }, Uri:parse("id:abcd-efgh"))

        -- Just a scheme and query
        assert.same({
            scheme = "id",
            path = "",
            query = { ["abc"] = "def", ["ghi"] = "jkl" },
        }, Uri:parse("id:?abc=def&ghi=jkl"))

        -- Just a scheme and fragment
        assert.same({
            scheme = "id",
            path = "",
            fragment = "some-fragment",
        }, Uri:parse("id:#some-fragment"))

        -- Just a scheme and host
        assert.same({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
            },
        }, Uri:parse("id://example.com"))

        -- Just a scheme and host and username
        assert.same({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                userinfo = {
                    username = "username",
                },
            },
        }, Uri:parse("id://username@example.com"))
    end)
end)
