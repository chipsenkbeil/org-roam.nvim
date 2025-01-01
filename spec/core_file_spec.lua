describe("org-roam.core.file", function()
    local File = require("org-roam.core.file")
    local utils = require("spec.utils")

    -- Drop-in replacement for `math.huge` that we use for file node end range.
    local MAX_NUMBER = 2 ^ 31

    it("parse blank orgfile", function()
        local orgfile = utils.org_file("")

        local file = File:from_org_file(orgfile)
        assert.are.equal(orgfile.filename, file.filename)
        assert.are.same({}, file.links)
        assert.are.same({}, file.nodes)
    end)

    it("parse orgfile with single file node", function()
        local orgfile = utils.org_file([=[
            :PROPERTIES:
            :ID: 1234
            :ROAM_ALIASES: "one alias" two three "\"four\""
            :END:

            This is an org file with [[https://example.com][web links]],
            and [[id:5678][id links]], only of which the id link will
            be captured within our node.

            #+FILETAGS: :tag1:tag2:tag3:
        ]=])

        local file = File:from_org_file(orgfile)
        assert.are.equal(orgfile.filename, file.filename)
        assert.are.same({
            {
                description = "id links",
                kind = "regular",
                path = "id:5678",
                range = {
                    end_ = {
                        column = 24,
                        offset = 163,
                        row = 6,
                    },
                    start = {
                        column = 4,
                        offset = 143,
                        row = 6,
                    },
                },
            },
        }, file.links)
        assert.are.same({
            ["1234"] = {
                aliases = { "one alias", "two", "three", '"four"' },
                file = orgfile.filename,
                id = "1234",
                level = 0,
                linked = {
                    ["5678"] = {
                        { column = 4, offset = 143, row = 6 },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = MAX_NUMBER,
                        offset = MAX_NUMBER,
                        row = MAX_NUMBER,
                    },
                    start = {
                        column = 0,
                        offset = 0,
                        row = 0,
                    },
                },
                tags = { "tag1", "tag2", "tag3" },
                title = vim.fn.fnamemodify(orgfile.filename, ":t:r"),
            },
        }, file.nodes)
    end)

    it("parse orgfile with single headline node", function()
        local orgfile = utils.org_file([=[
            #+FILETAGS: :tag1:tag2:tag3:

            Text outside of the headline won't be included in nodes.
            This includes [[id:1234][id links]].

            * Some headline :HEADLINE_TAG:
                :PROPERTIES:
                :ID: 1234
                :ROAM_ALIASES: "one alias" two three "\"four\""
                :END:

                This is an org file with [[https://example.com][web links]],
                and [[id:5678][id links]], only of which the id link will
                be captured within our node.
        ]=])

        local file = File:from_org_file(orgfile)
        assert.are.equal(orgfile.filename, file.filename)
        assert.are.same({
            {
                description = "id links",
                kind = "regular",
                path = "id:1234",
                range = {
                    end_ = {
                        column = 34,
                        offset = 121,
                        row = 3,
                    },
                    start = {
                        column = 14,
                        offset = 101,
                        row = 3,
                    },
                },
            },
            {
                description = "id links",
                kind = "regular",
                path = "id:5678",
                range = {
                    end_ = {
                        column = 28,
                        offset = 343,
                        row = 12,
                    },
                    start = {
                        column = 8,
                        offset = 323,
                        row = 12,
                    },
                },
            },
        }, file.links)
        assert.are.same({
            ["1234"] = {
                aliases = { "one alias", "two", "three", '"four"' },
                file = orgfile.filename,
                id = "1234",
                level = 1,
                linked = {
                    ["5678"] = {
                        { column = 8, offset = 323, row = 12 },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = 0,
                        offset = 410,
                        row = 14,
                    },
                    start = {
                        column = 0,
                        offset = 125,
                        row = 5,
                    },
                },
                tags = { "HEADLINE_TAG", "tag1", "tag2", "tag3" },
                title = "Some headline",
            },
        }, file.nodes)
    end)

    it("parse orgfile with multiple nodes", function()
        local orgfile = utils.org_file([=[
            :PROPERTIES:
            :ID: 1234
            :END:

            #+FILETAGS: :tag1:tag2:tag3:
            #+TITLE: test title

            Text outside of the headline won't be included in nodes.
            This includes [[id:1111][id links]].

            * Some headline :HEADLINE_TAG:
                :PROPERTIES:
                :ID: 5678
                :ROAM_ALIASES: "one alias" two three "\"four\""
                :END:

                This is a section node with [[https://example.com][web links]],
                and [[id:2222][id links]], only of which the id link will
                be captured within our node.

            * Another headline :HEADLINE_TAG_2:

                This is an regular section with [[https://example.com][web links]],
                and [[id:3333][id links]], only of which the id link will
                be captured as part of the file node.

            ** Nested headline :HEADLINE_TAG_3:
                :PROPERTIES:
                :ID: abcd-1234
                :ROAM_ALIASES: five six
                :END:

                This is another section node with [[https://example.com][web links]],
                and [[id:4444][id links]], only of which the id link will
                be captured within our node.
        ]=])

        local file = File:from_org_file(orgfile)
        assert.are.equal(orgfile.filename, file.filename)
        assert.are.same({
            {
                description = "id links",
                kind = "regular",
                path = "id:1111",
                range = {
                    end_ = {
                        column = 34,
                        offset = 171,
                        row = 8,
                    },
                    start = {
                        column = 14,
                        offset = 151,
                        row = 8,
                    },
                },
            },
            {
                description = "id links",
                kind = "regular",
                path = "id:2222",
                range = {
                    end_ = {
                        column = 28,
                        offset = 396,
                        row = 17,
                    },
                    start = {
                        column = 8,
                        offset = 376,
                        row = 17,
                    },
                },
            },
            {
                description = "id links",
                kind = "regular",
                path = "id:3333",
                range = {
                    end_ = {
                        column = 28,
                        offset = 601,
                        row = 23,
                    },
                    start = {
                        column = 8,
                        offset = 581,
                        row = 23,
                    },
                },
            },
            {
                description = "id links",
                kind = "regular",
                path = "id:4444",
                range = {
                    end_ = {
                        column = 28,
                        offset = 891,
                        row = 33,
                    },
                    start = {
                        column = 8,
                        offset = 871,
                        row = 33,
                    },
                },
            },
        }, file.links)

        assert.are.same({
            ["1234"] = {
                aliases = {},
                file = file.filename,
                id = "1234",
                level = 0,
                linked = {
                    ["1111"] = {
                        {
                            column = 14,
                            offset = 151,
                            row = 8,
                        },
                    },
                    ["3333"] = {
                        {
                            column = 8,
                            offset = 581,
                            row = 23,
                        },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = MAX_NUMBER,
                        offset = MAX_NUMBER,
                        row = MAX_NUMBER,
                    },
                    start = {
                        column = 0,
                        offset = 0,
                        row = 0,
                    },
                },
                tags = { "tag1", "tag2", "tag3" },
                title = "test title",
            },
            ["5678"] = {
                aliases = { "one alias", "two", "three", '"four"' },
                file = file.filename,
                id = "5678",
                level = 1,
                linked = {
                    ["2222"] = {
                        {
                            column = 8,
                            offset = 376,
                            row = 17,
                        },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = 0,
                        offset = 464,
                        row = 20,
                    },
                    start = {
                        column = 0,
                        offset = 175,
                        row = 10,
                    },
                },
                tags = { "HEADLINE_TAG", "tag1", "tag2", "tag3" },
                title = "Some headline",
            },
            ["abcd-1234"] = {
                aliases = { "five", "six" },
                file = file.filename,
                id = "abcd-1234",
                level = 2,
                linked = {
                    ["4444"] = {
                        {
                            column = 8,
                            offset = 871,
                            row = 33,
                        },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = 0,
                        offset = 958,
                        row = 35,
                    },
                    start = {
                        column = 0,
                        offset = 678,
                        row = 26,
                    },
                },
                tags = { "HEADLINE_TAG_2", "HEADLINE_TAG_3", "tag1", "tag2", "tag3" },
                title = "Nested headline",
            },
        }, file.nodes)
    end)
end)
