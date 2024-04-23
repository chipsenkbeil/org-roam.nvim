describe("org-roam.events", function()
    local roam --[[ @type OrgRoam ]]
    local utils = require("spec.utils")

    ---@type string, string, string
    local test_path_one, test_path_two, test_path_three

    ---Moves cursor and forces a trigger of "CursorMoved".
    ---@param line integer
    local function move_cursor_to_line(line)
        vim.api.nvim_win_set_cursor(0, { line, 0 })
        vim.api.nvim_exec_autocmds("CursorMoved", {
            group = "org-roam.nvim",
        })
    end

    before_each(function()
        roam = utils.init_plugin({
            setup = {
                directory = utils.make_temp_org_files_directory(),
            }
        })
        test_path_one = utils.join_path(roam.config.directory, "one.org")
        test_path_two = utils.join_path(roam.config.directory, "two.org")
        test_path_three = utils.join_path(roam.config.directory, "three.org")

        -- Patch `vim.cmd` so we can run tests here
        utils.patch_vim_cmd()

        -- Clear any buffers/windows that carried over from other tests
        utils.clear_windows()
        utils.clear_buffers()
    end)

    after_each(function()
        -- Clear any buffers/windows that carried over from this test
        utils.clear_windows()
        utils.clear_buffers()

        -- Unpatch `vim.cmd` so we can have tests pass
        utils.unpatch_vim_cmd()

        -- Restore select in case we mocked it
        utils.unmock_select()
    end)

    it("jumping between buffers should report node changes", function()
        ---@type string[]
        local nodes = {}

        -- Register such that each change gets stored in the table above
        roam.events.on_cursor_node_changed(function(node)
            table.insert(nodes, node and node.id or "")
        end)

        -- Load up a couple of files and create new windows to verify node changes
        -- NOTE: Only buffers with *.org will trigger, so empty new windows won't!
        vim.cmd.edit(test_path_one)
        vim.cmd.edit("test-file.txt") -- non-org file WON'T trigger!
        vim.cmd.new()
        vim.cmd.edit(test_path_two)
        vim.cmd.edit("test-file.org") -- non-existent org file WILL trigger!
        vim.cmd.edit(test_path_three)
        vim.cmd.new()
        vim.cmd.edit(test_path_one)

        -- Wait a moment for async events to process
        utils.wait()

        assert.are.same({ "1", "2", "", "3", "1" }, nodes)
    end)

    it("moving around buffer with multiple nodes should report changes", function()
        -- Save the file without our test directory
        local test_path = utils.join_path(roam.config.directory, "new.org")
        utils.write_to(test_path, utils.indent([=[
        :PROPERTIES:
        :ID: 1234
        :END:
        #+TITLE: File Node

        Some outer node text.

        * Inner Node
          :PROPERTIES:
          :ID: 5678
          :END:

          Some inner node text.
        ]=]))

        -- Reload the nodes into our database
        roam.db:load():wait()

        ---@type string[]
        local nodes = {}

        -- Register such that each change gets stored in the table above
        roam.events.on_cursor_node_changed(function(node)
            table.insert(nodes, node and node.id or "")
        end)

        -- Load the test file we just created
        vim.cmd.edit(test_path)

        -- Move around to the inner node (put cursor on headline)
        move_cursor_to_line(8)

        -- Move up to the outer node again
        move_cursor_to_line(7)

        -- Wait a moment for async events to process
        utils.wait()

        assert.are.same({ "1234", "5678", "1234" }, nodes)
    end)
end)
