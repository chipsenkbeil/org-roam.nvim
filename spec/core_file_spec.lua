describe("org-roam.core.file", function()
    local File = require("org-roam.core.file")
    local utils = require("spec.utils")

    -- Drop-in replacement for `math.huge` that we use for file node end range.
    local MAX_NUMBER = 2 ^ 31

    before_each(function()
        -- NOTE: We need to run this in this core test because org_file calls
        --       are triggering the ftplugin/org.lua, which is trying to use
        --       vim.cmd.something(...) and is failing because of a plenary issue
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("parse blank orgfile", function()
        local orgfile = utils.org_file("")

        local file = File:from_org_file(orgfile)
        assert.are.equal(orgfile.filename, file.filename)
        assert.are.same({}, file.links)
        assert.are.same({}, file.nodes)
    end)

    it("parse orgfile with single file node", function()
        local root = utils.make_temp_org_files_directory()
        local orgfile = utils.load_org_file(vim.fs.joinpath(root, "single-file-node.org"))
        assert(orgfile, "failed to load orgfile")

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
        local root = utils.make_temp_org_files_directory()
        local orgfile = utils.load_org_file(vim.fs.joinpath(root, "single-headline-node.org"))
        assert(orgfile, "failed to load orgfile")

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
                        column = 24,
                        offset = 319,
                        row = 12,
                    },
                    start = {
                        column = 4,
                        offset = 299,
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
                        { column = 4, offset = 299, row = 12 },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = 28,
                        offset = 381,
                        row = 13,
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
        local root = utils.make_temp_org_files_directory()
        local orgfile = utils.load_org_file(vim.fs.joinpath(root, "multiple-nodes.org"))
        assert(orgfile, "failed to load orgfile")

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
                        column = 24,
                        offset = 372,
                        row = 17,
                    },
                    start = {
                        column = 4,
                        offset = 352,
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
                        column = 24,
                        offset = 565,
                        row = 23,
                    },
                    start = {
                        column = 4,
                        offset = 545,
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
                        column = 24,
                        offset = 827,
                        row = 33,
                    },
                    start = {
                        column = 4,
                        offset = 807,
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
                            column = 4,
                            offset = 545,
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
                            column = 4,
                            offset = 352,
                            row = 17,
                        },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = 0,
                        offset = 436,
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
                            column = 4,
                            offset = 807,
                            row = 33,
                        },
                    },
                },
                mtime = orgfile.metadata.mtime,
                range = {
                    end_ = {
                        column = 28,
                        offset = 889,
                        row = 34,
                    },
                    start = {
                        column = 0,
                        offset = 638,
                        row = 26,
                    },
                },
                tags = { "HEADLINE_TAG_2", "HEADLINE_TAG_3", "tag1", "tag2", "tag3" },
                title = "Nested headline",
            },
        }, file.nodes)
    end)
end)
