describe("org-roam.setup.keybindings", function()
    local utils = require("spec.utils")

    before_each(function()
        utils.init_before_test()
    end)

    after_each(function()
        utils.cleanup_after_test()
    end)

    it("add_alias keybinding should support adding an alias to the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())

        -- Mock selection, which is triggered by the keybinding
        utils.mock_vim_inputs({
            input = "some alias",
        })

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.add_alias, {
            wait = utils.wait_time(),
        })

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one \"some alias\"",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("remove_alias keybinding should support removing an alias from the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())

        -- Mock selection, which is triggered by the keybinding
        utils.mock_select_pick(function(_, _, helpers)
            return helpers.pick_with_label("one")
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.remove_alias, {
            wait = utils.wait_time(),
        })

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("add_origin keybinding should support setting the origin for the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "one.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())

        -- Mock selection, which is triggered by the keybinding
        utils.mock_select_pick(function(_, _, helpers)
            return helpers.pick_with_label("two")
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.add_origin, {
            wait = utils.wait_time(),
        })

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":ROAM_ORIGIN: 2",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("remove_origin keybinding should support removing the origin for the node", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "two.org")

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Open up the some test file
        vim.cmd.edit(test_path)

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 2",
            ":ROAM_ALIASES: two",
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+FILETAGS: :two:",
            "",
            "[[id:3]]",
        }, utils.read_buffer())

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.remove_origin, {
            wait = utils.wait_time(),
        })

        assert.are.same({
            ":PROPERTIES:",
            ":ID: 2",
            ":ROAM_ALIASES: two",
            ":END:",
            "#+FILETAGS: :two:",
            "",
            "[[id:3]]",
        }, utils.read_buffer())
    end)

    it("goto_prev_node keybinding should go to the previous node if current node has an origin", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "test-file.org")
        local id = "test-id"

        -- Create our test file with an origin
        utils.write_to(test_path, {
            ":PROPERTIES:",
            ":ID: " .. id,
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: Test",
        })

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Load the file into the buffer
        vim.cmd.edit(test_path)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.goto_prev_node, {
            wait = utils.wait_time(),
        })

        -- Review that we moved to the origin
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 1",
            ":ROAM_ALIASES: one",
            ":END:",
            "#+FILETAGS: :one:",
            "",
            "[[id:2]]",
        }, utils.read_buffer())
    end)

    it("goto_next_node keybinding should to the next node using origin", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Load a file used as an origin into the buffer
        vim.cmd.edit(utils.join_path(directory, "one.org"))

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.goto_next_node, {
            wait = utils.wait_time(),
        })

        -- Review that we moved to the next node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 2",
            ":ROAM_ALIASES: two",
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+FILETAGS: :two:",
            "",
            "[[id:3]]",
        }, utils.read_buffer())
    end)

    it("goto_next_node keybinding should to the next node using selection of origins", function()
        local directory = utils.make_temp_org_files_directory()
        local test_path = utils.join_path(directory, "test-file.org")

        utils.write_to(test_path, utils.indent([=[
        :PROPERTIES:
        :ID: test-id
        :ROAM_ORIGIN: 1
        :END:
        ]=]))

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Load a file used as an origin into the buffer
        vim.cmd.edit(utils.join_path(directory, "one.org"))

        -- Given two choices, pick node 2
        utils.mock_select_pick(function(_, _, helpers)
            return helpers.pick_with_label("two")
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.goto_next_node, {
            wait = utils.wait_time(),
        })

        -- Review that we moved to the next node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 2",
            ":ROAM_ALIASES: two",
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+FILETAGS: :two:",
            "",
            "[[id:3]]",
        }, utils.read_buffer())
    end)

    it("quickfix_backlinks keybinding should be able to display backlinks for the node under cursor", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Load up a test file
        vim.cmd.edit(utils.join_path(directory, "two.org"))

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.quickfix_backlinks, {
            wait = utils.wait_time(),
        })

        -- Verify the quickfix contents
        assert.are.same({
            { module = "one", text = "[[id:2]]", lnum = 7, col = 1 },
        }, utils.qflist_items())
    end)

    it("toggle_roam_buffer keybinding should open roam buffer for node under cursor", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Load up a test file
        vim.cmd.edit(utils.join_path(directory, "two.org"))

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.toggle_roam_buffer, {
            wait = utils.wait_time(),
        })

        -- Verify we have switched to the appropriate buffer
        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Node: two",
            "Origin: one",
            "",
            "Backlinks (1)",
            "▶ one @ 7,0",
        }, utils.read_buffer())
    end)

    it("toggle_roam_buffer_fixed keybinding should open roam buffer for selected node", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Mock selection to pick node 2
        utils.mock_select_pick(function(_, _, helpers)
            return helpers.pick_with_label("two")
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.toggle_roam_buffer_fixed, {
            wait = utils.wait_time(),
        })

        print("SELECTED BUFFER: " .. vim.api.nvim_get_current_buf())
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            print("--- BUFFER " .. buf .. " ---")
            print(vim.inspect(utils.read_buffer(buf)))
        end

        -- Verify we have switched to the appropriate buffer
        assert.are.same({
            "Press <Enter> to open a link in another window",
            "Press <Tab> to expand/collapse a link",
            "Press <S-Tab> to expand/collapse all links",
            "Press <C-r> to refresh buffer",
            "",
            "Fixed Node: two",
            "Origin: one",
            "",
            "Backlinks (1)",
            "▶ one @ 7,0",
        }, utils.read_buffer())
    end)

    it("complete_at_point keybinding should complete a link to a node based on expression under cursor", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Set our buffer text to something and point cursor to text this is
        -- close to the title of the node "three"
        vim.api.nvim_buf_set_lines(0, 0, -1, true, {
            "some text",
            "with thr link",
            "is good",
        })
        vim.api.nvim_win_set_cursor(0, { 2, 5 }) -- point to start of "thr"

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.complete_at_point, {
            wait = utils.wait_time(),
        })

        -- Verify we have switched to the appropriate buffer
        assert.are.same({
            "some text",
            "with [[id:3][three]] link",
            "is good",
        }, utils.read_buffer())
    end)

    it("capture keybinding should open capture buffer from normal mode", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(utils.join_path(directory, "one.org"))

        -- Select the default template
        utils.mock_vim_inputs({
            confirm = 0,                   -- confirm no for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
            input   = "Some title",        -- input "Some title" on title prompt
        })

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.capture, {
            wait = utils.wait_time(),
        })

        -- Capture the lines of the capture buffer
        local lines = utils.read_buffer()

        -- Save the capture buffer and exit it
        -- NOTE: We do this before any tests as any failure before capture
        --       buffer is closed can cause issues.
        vim.cmd("wq")
        utils.wait()

        -- Verify we have switched to the appropriate buffer, stubbing out
        -- the randomly-generated id
        lines[2] = string.sub(lines[2], 1, 4) .. " <ID>"
        assert.are.same({
            ":PROPERTIES:",
            ":ID: <ID>",
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: Some title",
            "",
            "",
        }, lines)
    end)

    it("capture keybinding should open capture buffer with title matching visual selection", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Open a file buffer so we avoid capture closing neovim
        vim.cmd.edit(utils.join_path(directory, "one.org"))

        -- Select the default template
        utils.mock_vim_inputs({
            confirm = 0,                   -- confirm no for refile
            getchar = vim.fn.char2nr("d"), -- select "d" template
        })

        -- Do a visual selection first before triggering keybinding
        vim.api.nvim_buf_set_lines(0, -1, -1, true, { "Visually Selected Title", "" })
        local line = vim.api.nvim_buf_line_count(0) - 1
        roam.utils.set_visual_selection({
            start_row = line,
            start_col = 1,
            end_row = line,
            end_col = 999,
        })

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.capture, {
            wait = utils.wait_time(),
        })

        -- Capture the lines of the capture buffer
        local lines = utils.read_buffer()

        -- Save the capture buffer and exit it
        -- NOTE: We do this before any tests as any failure before capture
        --       buffer is closed can cause issues.
        vim.cmd("wq")
        utils.wait()

        -- Verify we have switched to the appropriate buffer, stubbing out
        -- the randomly-generated id
        lines[2] = string.sub(lines[2], 1, 4) .. " <ID>"
        assert.are.same({
            ":PROPERTIES:",
            ":ID: <ID>",
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+TITLE: Visually Selected Title",
            "",
            "",
        }, lines)
    end)

    it("find_node keybinding should open buffer for selected node", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Mock the selected node to be node 2
        utils.mock_select_pick(function(_, _, helpers)
            return helpers.pick_with_label("two")
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.find_node, {
            wait = utils.wait_time(),
        })

        -- Verify we loaded the buffer for the selected node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 2",
            ":ROAM_ALIASES: two",
            ":ROAM_ORIGIN: 1",
            ":END:",
            "#+FILETAGS: :two:",
            "",
            "[[id:3]]",
        }, utils.read_buffer())
    end)

    it("find_node keybinding should open buffer using visual selection as filter", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Do a visual selection first before triggering keybinding
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { "three" })
        roam.utils.set_visual_selection({
            start_row = 1,
            start_col = 1,
            end_row = 1,
            end_col = 999,
        })

        -- Mock the selected node to be node 2
        utils.mock_select_pick(function(choices, this)
            -- NOTE: The error won't get caught, but it will still
            --       cause the test to fail as the selection dialog
            --       won't change.
            assert(this:input() == "three", "input did not match visual selection")
            return choices[1]
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.find_node, {
            wait = utils.wait_time(),
        })

        -- Verify we loaded the buffer for the selected node
        assert.are.same({
            ":PROPERTIES:",
            ":ID: 3",
            ":ROAM_ALIASES: three",
            ":ROAM_ORIGIN: 2",
            ":END:",
            "#+FILETAGS: :three:",
            "",
            "[[id:1]]",
        }, utils.read_buffer())
    end)

    it("insert_node keybinding should insert a link at cursor for selected node", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Mock the selected node to be node 2
        utils.mock_select_pick(function(_, _, helpers)
            return helpers.pick_with_label("two")
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.insert_node, {
            wait = utils.wait_time(),
        })

        -- Verify we inserted the link
        assert.are.same({
            "[[id:2][two]]",
        }, utils.read_buffer())
    end)

    it("insert_node keybinding should support replacing visual selection", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Do a visual selection first before triggering keybinding
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
            "some series of text",
            "on multiple lines",
        })

        roam.utils.set_visual_selection({
            start_row = 1,
            start_col = 6,
            end_row = 2,
            end_col = 11,
        })

        -- Mock the selected node to be node 2 (ignore filter)
        utils.mock_select_pick(function(_, _, helpers)
            return { item = { id = "2" }, label = "two", idx = 2 }
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.insert_node, {
            wait = utils.wait_time(),
        })

        -- Verify we inserted the link, replacing the visual selection
        assert.are.same({
            "some [[id:2][two]] lines",
        }, utils.read_buffer())
    end)

    it("insert_node_immediate keybinding should insert link to node without capture dialog", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Mock the selected node to be unique
        utils.mock_select_pick(function()
            return "new node"
        end)

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.insert_node_immediate, {
            wait = utils.wait_time(),
        })

        -- Verify we inserted the link to the new node
        local lines = utils.read_buffer()
        local _, _, id = string.find(lines[1], "%[%[id:([^]]+)]%[new node]]")
        assert.are.same({ "[[id:" .. id .. "][new node]]" }, lines)
    end)

    it("insert_node_immediate keybinding should support replacing visual selection", function()
        local directory = utils.make_temp_org_files_directory()

        -- Configure plugin to update database on write
        local roam = utils.init_plugin({
            setup = {
                directory = directory,
                database = {
                    path = utils.join_path(directory, "db"),
                },
            }
        })

        -- Ensure loading is done
        roam.database:load():wait()

        -- Do a visual selection first before triggering keybinding
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
            "some series of text",
            "on multiple lines",
        })

        roam.utils.set_visual_selection({
            start_row = 1,
            start_col = 6,
            end_row = 2,
            end_col = 11,
        })

        -- Trigger the keybinding and wait a bit
        utils.trigger_mapping("n", roam.config.bindings.insert_node_immediate, {
            wait = utils.wait_time(),
        })

        -- Verify we inserted the link to the new node
        local lines = utils.read_buffer()
        local _, _, id = string.find(lines[1], "%[%[id:([^]]+)]%[[^]]+]]")
        assert(id, "could not find id of newly-inserted node")
        assert.are.same({ "some [[id:" .. id .. "][series of text on multiple]] lines" }, lines)
    end)
end)
