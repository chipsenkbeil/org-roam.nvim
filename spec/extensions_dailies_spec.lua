describe("org-roam.extensions.dailies", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    local Date = require("orgmode.objects.date")

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
        local id = roam.extensions.dailies.capture_date()

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

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
        local id = roam.extensions.dailies.capture_date({
            date = utils.date_from_string("2024-04-27"),
        })

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

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

    it("should support capturing using today's date", function()
        -- Load files into the database
        roam.database:load():wait()

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        local date = os.date("%Y-%m-%d", Date.today().timestamp)

        -- Start the capture process
        local id = roam.extensions.dailies.capture_today()

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

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
            "#+TITLE: " .. date,
            "",
            "",
            "",
        }, contents)
    end)

    it("should support capturing using tomorrow's date", function()
        -- Load files into the database
        roam.database:load():wait()

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        local date = os.date("%Y-%m-%d", Date.tomorrow().timestamp)

        -- Start the capture process
        local id = roam.extensions.dailies.capture_tomorrow()

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

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
            "#+TITLE: " .. date,
            "",
            "",
            "",
        }, contents)
    end)

    it("should support capturing using yesterday's date", function()
        -- Load files into the database
        roam.database:load():wait()

        utils.mock_vim_inputs({
            confirm = 1,                   -- confirm yes for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        local date = os.date("%Y-%m-%d", Date.today():subtract({ day = 1 }).timestamp)

        -- Start the capture process
        local id = roam.extensions.dailies.capture_yesterday()

        -- Wait a bit for the capture buffer to appear
        utils.wait()

        -- Save the capture buffer and exit it
        vim.cmd("wq")

        -- Wait a bit for the capture to be processed
        utils.wait()

        -- Retrieve the id now that it should be available
        id = id:wait()

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
            "#+TITLE: " .. date,
            "",
            "",
            "",
        }, contents)
    end)

    it("should support navigating to a date whose note exists", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Create a file for the date
        utils.write_to(utils.join_path(
            roam.config.directory,
            roam.config.extensions.dailies.directory,
            "2024-04-27.org"
        ), {
            "some file",
            "contents",
        })

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_date({
            date = "2024-04-27",
        }):wait()

        assert.are.equal(utils.date_from_string("2024-04-27"), date)

        assert.are.same({
            "some file",
            "contents",
        }, utils.read_buffer())
    end)

    it("should support create an unsaved buffer when navigating to a date whose note is missing", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_date({
            date = "2024-04-27",
        }):wait()

        assert.are.equal(utils.date_from_string("2024-04-27"), date)

        local lines = utils.read_buffer()
        lines[2] = string.sub(lines[2], 1, 4) .. " <ID>"
        assert.are.same({
            ":PROPERTIES:",
            ":ID: <ID>",
            ":END:",
            "#+TITLE: 2024-04-27",
            "",
        }, lines)
    end)

    it("should support navigating to today's date whose note exists", function()
        -- Load files into the database
        roam.database:load():wait()

        local date = os.date("%Y-%m-%d", Date.today().timestamp) --[[ @cast date string ]]

        -- Create a file for the date
        utils.write_to(utils.join_path(
            roam.config.directory,
            roam.config.extensions.dailies.directory,
            date .. ".org"
        ), {
            "some file",
            "contents",
        })

        -- Do the navigation without opening the calendar
        roam.extensions.dailies.goto_today():wait()

        assert.are.same({
            "some file",
            "contents",
        }, utils.read_buffer())
    end)

    it("should support create an unsaved buffer when navigating to today's date whose note is missing", function()
        -- Load files into the database
        roam.database:load():wait()

        local date = os.date("%Y-%m-%d", Date.today().timestamp) --[[ @cast date string ]]

        -- Do the navigation without opening the calendar
        roam.extensions.dailies.goto_today():wait()

        local lines = utils.read_buffer()
        lines[2] = string.sub(lines[2], 1, 4) .. " <ID>"
        assert.are.same({
            ":PROPERTIES:",
            ":ID: <ID>",
            ":END:",
            "#+TITLE: " .. date,
            "",
        }, lines)
    end)

    it("should support navigating to tomorrow's date whose note exists", function()
        -- Load files into the database
        roam.database:load():wait()

        local date = os.date("%Y-%m-%d", Date.tomorrow().timestamp) --[[ @cast date string ]]

        -- Create a file for the date
        utils.write_to(utils.join_path(
            roam.config.directory,
            roam.config.extensions.dailies.directory,
            date .. ".org"
        ), {
            "some file",
            "contents",
        })

        -- Do the navigation without opening the calendar
        roam.extensions.dailies.goto_tomorrow():wait()

        assert.are.same({
            "some file",
            "contents",
        }, utils.read_buffer())
    end)

    it("should support create an unsaved buffer when navigating to tomorrow's date whose note is missing", function()
        -- Load files into the database
        roam.database:load():wait()

        local date = os.date("%Y-%m-%d", Date.tomorrow().timestamp) --[[ @cast date string ]]

        -- Do the navigation without opening the calendar
        roam.extensions.dailies.goto_tomorrow():wait()

        local lines = utils.read_buffer()
        lines[2] = string.sub(lines[2], 1, 4) .. " <ID>"
        assert.are.same({
            ":PROPERTIES:",
            ":ID: <ID>",
            ":END:",
            "#+TITLE: " .. date,
            "",
        }, lines)
    end)

    it("should support navigating to yesterday's date whose note exists", function()
        -- Load files into the database
        roam.database:load():wait()

        local date = os.date("%Y-%m-%d", Date.today():subtract({ day = 1 }).timestamp) --[[ @cast date string ]]

        -- Create a file for the date
        utils.write_to(utils.join_path(
            roam.config.directory,
            roam.config.extensions.dailies.directory,
            date .. ".org"
        ), {
            "some file",
            "contents",
        })

        -- Do the navigation without opening the calendar
        roam.extensions.dailies.goto_yesterday():wait()

        assert.are.same({
            "some file",
            "contents",
        }, utils.read_buffer())
    end)

    it("should support create an unsaved buffer when navigating to yesterday's date whose note is missing", function()
        -- Load files into the database
        roam.database:load():wait()

        local date = os.date("%Y-%m-%d", Date.today():subtract({ day = 1 }).timestamp) --[[ @cast date string ]]

        -- Do the navigation without opening the calendar
        roam.extensions.dailies.goto_yesterday():wait()

        local lines = utils.read_buffer()
        lines[2] = string.sub(lines[2], 1, 4) .. " <ID>"
        assert.are.same({
            ":PROPERTIES:",
            ":ID: <ID>",
            ":END:",
            "#+TITLE: " .. date,
            "",
        }, lines)
    end)
end)
