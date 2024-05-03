describe("org-roam.extensions.dailies", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    local Date = require("orgmode.objects.date")

    ---@param date string|OrgDate
    ---@param ... string|string[]
    ---@return string path
    local function write_date_file(date, ...)
        if type(date) == "table" then
            ---@diagnostic disable-next-line:cast-local-type
            date = os.date("%Y-%m-%d", date.timestamp)
        end

        local path = utils.join_path(
            roam.config.directory,
            roam.config.extensions.dailies.directory,
            date .. ".org"
        )

        utils.write_to(path, ...)

        return path
    end

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
        write_date_file("2024-04-27", {
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
        write_date_file(date, {
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
        write_date_file(date, {
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
        write_date_file(date, {
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

    it("should not navigate to the next date if not at buffer that is a date", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Put some content in our current buffer to verify navigation
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { "test" })

        write_date_file("2024-04-27", "a")
        write_date_file("2024-04-28", "b")
        write_date_file("2024-04-29", "c")

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_next_date():wait()
        assert.is_nil(date)

        assert.are.same({ "test" }, utils.read_buffer())
    end)

    it("should not navigate to the next date (n=+1) if at most recent", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-27", "a")
        write_date_file("2024-04-28", "b")
        local path = write_date_file("2024-04-29", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_next_date():wait()
        assert.is_nil(date)

        assert.are.same({ "c" }, utils.read_buffer())
    end)

    it("should not navigate to the next date (n=-1) if at earliest", function()
        -- Load files into the database
        roam.database:load():wait()

        local path = write_date_file("2024-04-27", "a")
        write_date_file("2024-04-28", "b")
        write_date_file("2024-04-29", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_next_date({ n = -1 }):wait()
        assert.is_nil(date)

        assert.are.same({ "a" }, utils.read_buffer())
    end)

    it("should navigate to the next date (n=+1) regardless of consecutive", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-01", "a")
        local path = write_date_file("2024-04-03", "b")
        write_date_file("2024-04-05", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_next_date():wait()
        assert.are.equal(utils.date_from_string("2024-04-05"), date)

        assert.are.same({ "c" }, utils.read_buffer())
    end)

    it("should navigate to the next date (n=-1) regardless of consecutive", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-01", "a")
        local path = write_date_file("2024-04-03", "b")
        write_date_file("2024-04-05", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_next_date({ n = -1 }):wait()
        assert.are.equal(utils.date_from_string("2024-04-01"), date)

        assert.are.same({ "a" }, utils.read_buffer())
    end)

    it("should not navigate to the next date if n results in out of range", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-27", "a")
        local path = write_date_file("2024-04-28", "b")
        write_date_file("2024-04-29", "c")

        vim.cmd.edit(path)

        assert.is_nil(roam.extensions.dailies.goto_next_date({ n = 2 }):wait())
        assert.are.same({ "b" }, utils.read_buffer())

        assert.is_nil(roam.extensions.dailies.goto_next_date({ n = -2 }):wait())
        assert.are.same({ "b" }, utils.read_buffer())
    end)

    it("should navigate to the next date if n results in range", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-10", "a")
        write_date_file("2024-04-15", "b")
        local path = write_date_file("2024-04-20", "c")
        write_date_file("2024-04-25", "d")
        write_date_file("2024-04-30", "e")

        vim.cmd.edit(path)

        local date = roam.extensions.dailies.goto_next_date({ n = 2 }):wait()
        assert.are.equal(utils.date_from_string("2024-04-30"), date)
        assert.are.same({ "e" }, utils.read_buffer())
    end)

    it("should not navigate to the previous date if not at buffer that is a date", function()
        -- Load files into the database
        roam.database:load():wait()

        -- Put some content in our current buffer to verify navigation
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { "test" })

        write_date_file("2024-04-27", "a")
        write_date_file("2024-04-28", "b")
        write_date_file("2024-04-29", "c")

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_prev_date():wait()
        assert.is_nil(date)

        assert.are.same({ "test" }, utils.read_buffer())
    end)

    it("should not navigate to the previous date (n=+1) if at earliest", function()
        -- Load files into the database
        roam.database:load():wait()

        local path = write_date_file("2024-04-27", "a")
        write_date_file("2024-04-28", "b")
        write_date_file("2024-04-29", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_prev_date():wait()
        assert.is_nil(date)

        assert.are.same({ "a" }, utils.read_buffer())
    end)

    it("should not navigate to the previous date (n=-1) if at most recent", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-27", "a")
        write_date_file("2024-04-28", "b")
        local path = write_date_file("2024-04-29", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_prev_date({ n = -1 }):wait()
        assert.is_nil(date)

        assert.are.same({ "c" }, utils.read_buffer())
    end)

    it("should navigate to the previous date (n=+1) regardless of consecutive", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-01", "a")
        local path = write_date_file("2024-04-03", "b")
        write_date_file("2024-04-05", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_prev_date():wait()
        assert.are.equal(utils.date_from_string("2024-04-01"), date)

        assert.are.same({ "a" }, utils.read_buffer())
    end)

    it("should navigate to the previous date (n=-1) regardless of consecutive", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-01", "a")
        local path = write_date_file("2024-04-03", "b")
        write_date_file("2024-04-05", "c")

        vim.cmd.edit(path)

        -- Do the navigation without opening the calendar
        local date = roam.extensions.dailies.goto_prev_date({ n = -1 }):wait()
        assert.are.equal(utils.date_from_string("2024-04-05"), date)

        assert.are.same({ "c" }, utils.read_buffer())
    end)

    it("should not navigate to the previous date if n results in out of range", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-27", "a")
        local path = write_date_file("2024-04-28", "b")
        write_date_file("2024-04-29", "c")

        vim.cmd.edit(path)

        assert.is_nil(roam.extensions.dailies.goto_prev_date({ n = 2 }):wait())
        assert.are.same({ "b" }, utils.read_buffer())

        assert.is_nil(roam.extensions.dailies.goto_prev_date({ n = -2 }):wait())
        assert.are.same({ "b" }, utils.read_buffer())
    end)

    it("should navigate to the previous date if n results in range", function()
        -- Load files into the database
        roam.database:load():wait()

        write_date_file("2024-04-10", "a")
        write_date_file("2024-04-15", "b")
        local path = write_date_file("2024-04-20", "c")
        write_date_file("2024-04-25", "d")
        write_date_file("2024-04-30", "e")

        vim.cmd.edit(path)

        local date = roam.extensions.dailies.goto_prev_date({ n = 2 }):wait()
        assert.are.equal(utils.date_from_string("2024-04-10"), date)
        assert.are.same({ "a" }, utils.read_buffer())
    end)
end)
