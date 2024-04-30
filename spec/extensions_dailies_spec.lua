describe("org-roam.extensions.dailies", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()
        roam = utils.init_plugin({ setup = true })
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("should support opening a calendar to capture by a specific date", function()
        -- Load files into the database
        roam.database:load():wait()

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        -- Mock calendar to select a specific date
        utils.mock_calendar("2024-04-27")

        -- Start the capture process
        local id
        roam.extensions.dailies.capture_date({}, function(_id) id = _id end)

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(roam.database:get_sync(id), "missing node " .. id)
        local contents = utils.read_from(node.file)

        -- Verify that basic template was captured
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: 2024-04-27",
            "",
            "",
            "",
        }, contents)
    end)

    it("should support being provided a specific date for capture, not opening calendar", function()
        -- Load files into the database
        roam.database:load():wait()

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        -- Start the capture process
        local id
        roam.extensions.dailies.capture_date({
            date = utils.date_from_string("2024-04-27"),
        }, function(_id) id = _id end)

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- We should have an id for a valid capture
        assert.is_not_nil(id)

        -- Grab the file tied to the node and load it
        local node = assert(roam.database:get_sync(id), "missing node " .. id)
        local contents = utils.read_from(node.file)

        -- Verify that basic template was captured
        assert.are.same({
            ":PROPERTIES:",
            ":ID: " .. id,
            ":END:",
            "#+TITLE: 2024-04-27",
            "",
            "",
            "",
        }, contents)
    end)
end)
