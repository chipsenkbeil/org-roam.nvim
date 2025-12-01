describe("org-roam.setup", function()
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should fail if no directory supplied", function()
        local wait_until_ready = utils.prep_ready()

        assert.is.error(function()
            local roam = utils.init_plugin({ setup = false })
            roam.setup({})

            -- Wait for plugin to finish initializing
            wait_until_ready()
        end)
    end)

    it("should adjust the database to the supplied configuration", function()
        local wait_until_ready = utils.prep_ready()
        local db_path = vim.fn.tempname() .. "-test-db"
        local directory = utils.make_temp_org_files_directory()

        local roam = utils.init_plugin({ setup = false })
        roam.setup({
            database = { path = db_path },
            directory = directory,
        })

        -- Wait for plugin to finish initializing
        wait_until_ready()

        assert.are.equal(db_path, roam.database:path())
        assert.are.equal(directory, roam.database:files_path())
    end)

    -- define custom assertion function to extend luassert
    local has_file_like = function(state, arguments)
        local file_paths = arguments[1]
        local patterns = arguments[2]
        for _, pattern in ipairs(patterns) do
            pattern = string.gsub(pattern, "-", "%%-") .. "$"
            local match_found = false
            for _, file_path in ipairs(file_paths) do
                if file_path:match(pattern) then
                    match_found = true
                    break
                end
            end
            if not match_found then
                print(pattern .. "not found")
                return false
            end
        end
        return true
    end

    -- extend luassert as stated in the busted documentation - see also example code of assert:register
    -- "say" provides a lightweight key-value store used by both luassert and busted.
    local say = require("say")
    say:set_namespace("en")
    say:set("assertion.has_file_like.positive", "Expected %s to match all file patterns of %s.")
    say:set("assertion.has_file_like.negative", "Expected %s to not match all file patterns %s.")
    assert:register(
        "assertion",
        "has_file_like",
        has_file_like,
        "assertion.has_file_like.positive",
        "assertion.has_file_like.negative"
    )

    it("should load files", function()
        local wait_until_ready = utils.prep_ready()
        local db_path = vim.fn.tempname() .. "-test-db"
        local fixture_path = vim.fn.getcwd() .. "/spec/fixture/"
        local directory = fixture_path .. "roam/"

        local roam = utils.init_plugin({ setup = false })
        roam.setup({
            database = { path = db_path },
            directory = directory,
            org_files = {
                fixture_path .. "/external/dir_1/*.org",
                fixture_path .. "/external/dir_2/two.org",
                fixture_path .. "/external/dir_3/",
            },
        })

        -- Wait for plugin to finish initializing
        wait_until_ready()

        local file_names = {
            "Some_topic.org",
            "2024-06-09.org",
            "one.org",
            "two.org",
            "three.org",
            "four.org",
            "five.org",
        }

        local file_paths = {}
        roam.database
            :files({ force = true })
            :next(function(opts)
                for file_path, file in pairs(opts.all_files) do
                    table.insert(file_paths, file_path)
                    assert.is_not_nil(file)
                end
            end)
            :wait()

        ---@diagnostic disable-next-line: undefined-field
        assert.has.file.like(file_paths, file_names)
    end)
end)
