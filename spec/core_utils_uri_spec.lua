describe("utils.uri", function()
    local Uri = require("org-roam.core.utils.uri")

    it("should support being parsed from a string", function()
        local uri

        -- Just a scheme with nothing else
        uri = Uri:parse("id:")
        assert.same({
            scheme = "id",
            path = "",
        }, uri)

        -- Just a scheme and path
        uri = Uri:parse("id:abcd-efgh")
        assert.same({
            scheme = "id",
            path = "abcd-efgh",
        }, uri)

        -- Just a scheme and query
        uri = Uri:parse("id:?abc=def&ghi=jkl")
        assert.same({
            scheme = "id",
            path = "",
            query = "abc=def&ghi=jkl",
        }, uri)
        assert.same({ ["abc"] = "def", ["ghi"] = "jkl" }, uri:query_params())

        -- Just a scheme and fragment
        uri = Uri:parse("id:#some-fragment")
        assert.same({
            scheme = "id",
            path = "",
            fragment = "some-fragment",
        }, uri)

        -- Just a scheme and host
        uri = Uri:parse("id://example.com")
        assert.same({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
            },
        }, uri)

        -- Just a scheme, host, and port
        uri = Uri:parse("id://example.com:12345")
        assert.same({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                port = 12345,
            },
        }, uri)

        -- Just a scheme and host and username
        uri = Uri:parse("id://username@example.com")
        assert.same({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                userinfo = {
                    username = "username",
                },
            },
        }, uri)

        -- Just a scheme and host, username, and password
        uri = Uri:parse("id://username:12345@example.com")
        assert.same({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                userinfo = {
                    username = "username",
                    password = "12345",
                },
            },
        }, uri)

        -- Just a scheme, host, username, password, and port
        uri = Uri:parse("id://username:12345@example.com:6789")
        assert.same({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                port = 6789,
                userinfo = {
                    username = "username",
                    password = "12345",
                },
            },
        }, uri)

        -- Full uri with everything filled out
        uri = Uri:parse("https://username:12345@example.com:6789/some/path?key1=value1&key2=value2#test-fragment")
        assert.same({
            scheme = "https",
            path = "/some/path",
            authority = {
                host = "example.com",
                port = 6789,
                userinfo = {
                    username = "username",
                    password = "12345",
                },
            },
            query = "key1=value1&key2=value2",
            fragment = "test-fragment",
        }, uri)
        assert.same({
            ["key1"] = "value1",
            ["key2"] = "value2",
        }, uri:query_params())

        ----------------------------------------------------------------------
        -- Test example URIs from wikipedia
        ----------------------------------------------------------------------

        uri = Uri:parse("https://john.doe@www.example.com:123/forum/questions/?tag=networking&order=newest#top")
        assert.same({
            scheme = "https",
            path = "/forum/questions/",
            authority = {
                host = "www.example.com",
                port = 123,
                userinfo = {
                    username = "john.doe",
                },
            },
            query = "tag=networking&order=newest",
            fragment = "top",
        }, uri)
        assert.same({
            ["tag"] = "networking",
            ["order"] = "newest",
        }, uri:query_params())

        uri = Uri:parse("ldap://[2001:db8::7]/c=GB?objectClass?one")
        assert.same({
            scheme = "ldap",
            path = "/c=GB",
            authority = {
                host = "[2001:db8::7]",
            },
            query = "objectClass?one",
        }, uri)

        uri = Uri:parse("mailto:John.Doe@example.com")
        assert.same({
            scheme = "mailto",
            path = "John.Doe@example.com",
        }, uri)

        uri = Uri:parse("news:comp.infosystems.www.servers.unix")
        assert.same({
            scheme = "news",
            path = "comp.infosystems.www.servers.unix",
        }, uri)

        uri = Uri:parse("tel:+1-816-555-1212")
        assert.same({
            scheme = "tel",
            path = "+1-816-555-1212",
        }, uri)

        uri = Uri:parse("telnet://192.0.2.16:80/")
        assert.same({
            scheme = "telnet",
            path = "/",
            authority = {
                host = "192.0.2.16",
                port = 80,
            },
        }, uri)

        uri = Uri:parse("urn:oasis:names:specification:docbook:dtd:xml:4.1.2")
        assert.same({
            scheme = "urn",
            path = "oasis:names:specification:docbook:dtd:xml:4.1.2",
        }, uri)
    end)

    it("should support being convert to a string", function()
        local uri

        -- Just a scheme with nothing else
        uri = Uri:new({
            scheme = "id",
            path = "",
        })
        assert.equals("id:", uri:as_string())

        -- Just a scheme and path
        uri = Uri:new({
            scheme = "id",
            path = "abcd-efgh",
        })
        assert.equals("id:abcd-efgh", uri:as_string())

        -- Just a scheme and query
        uri = Uri:new({
            scheme = "id",
            path = "",
            query = "abc=def&ghi=jkl",
        })
        assert.equals("id:?abc=def&ghi=jkl", uri:as_string())

        -- Just a scheme and fragment
        uri = Uri:new({
            scheme = "id",
            path = "",
            fragment = "some-fragment",
        })
        assert.equals("id:#some-fragment", uri:as_string())

        -- Just a scheme and host
        uri = Uri:new({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
            },
        })
        assert.equals("id://example.com", uri:as_string())

        -- Just a scheme, host, and port
        uri = Uri:new({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                port = 12345,
            },
        })
        assert.equals("id://example.com:12345", uri:as_string())

        -- Just a scheme and host and username
        uri = Uri:new({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                userinfo = {
                    username = "username",
                },
            },
        })
        assert.equals("id://username@example.com", uri:as_string())

        -- Just a scheme and host, username, and password
        uri = Uri:new({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                userinfo = {
                    username = "username",
                    password = "12345",
                },
            },
        })
        assert.equals("id://username:12345@example.com", uri:as_string())

        -- Just a scheme, host, username, password, and port
        uri = Uri:new({
            scheme = "id",
            path = "",
            authority = {
                host = "example.com",
                port = 6789,
                userinfo = {
                    username = "username",
                    password = "12345",
                },
            },
        })
        assert.equals("id://username:12345@example.com:6789", uri:as_string())

        -- Full uri with everything filled out
        uri = Uri:new({
            scheme = "https",
            path = "/some/path",
            authority = {
                host = "example.com",
                port = 6789,
                userinfo = {
                    username = "username",
                    password = "12345",
                },
            },
            query = "key1=value1&key2=value2",
            fragment = "test-fragment",
        })
        assert.equals("https://username:12345@example.com:6789/some/path?key1=value1&key2=value2#test-fragment",
            uri:as_string())

        ----------------------------------------------------------------------
        -- Test example URIs from wikipedia
        ----------------------------------------------------------------------

        uri = Uri:new({
            scheme = "https",
            path = "/forum/questions/",
            authority = {
                host = "www.example.com",
                port = 123,
                userinfo = {
                    username = "john.doe",
                },
            },
            query = "tag=networking&order=newest",
            fragment = "top",
        })
        assert.equals("https://john.doe@www.example.com:123/forum/questions/?tag=networking&order=newest#top",
            uri:as_string())

        uri = Uri:new({
            scheme = "ldap",
            path = "/c=GB",
            authority = {
                host = "[2001:db8::7]",
            },
            query = "objectClass?one",
        })
        assert.equals("ldap://[2001:db8::7]/c=GB?objectClass?one", uri:as_string())

        uri = Uri:new({
            scheme = "mailto",
            path = "John.Doe@example.com",
        })
        assert.equals("mailto:John.Doe@example.com", uri:as_string())

        uri = Uri:new({
            scheme = "news",
            path = "comp.infosystems.www.servers.unix",
        })
        assert.equals("news:comp.infosystems.www.servers.unix", uri:as_string())

        uri = Uri:new({
            scheme = "tel",
            path = "+1-816-555-1212",
        })
        assert.equals("tel:+1-816-555-1212", uri:as_string())

        uri = Uri:new({
            scheme = "telnet",
            path = "/",
            authority = {
                host = "192.0.2.16",
                port = 80,
            },
        })
        assert.equals("telnet://192.0.2.16:80/", uri:as_string())

        uri = Uri:new({
            scheme = "urn",
            path = "oasis:names:specification:docbook:dtd:xml:4.1.2",
        })
        assert.equals("urn:oasis:names:specification:docbook:dtd:xml:4.1.2", uri:as_string())
    end)
end)