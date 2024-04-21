-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local AUGROUP = vim.api.nvim_create_augroup("org-roam.nvim", {})

local log = require("org-roam.core.log")
local notify = require("org-roam.core.ui.notify")

---@alias org-roam.config.NvimMode
---| "n"
---| "v"
---| "x"
---| "s"
---| "o"
---| "i"
---| "l"
---| "c"
---| "t"

---@param roam OrgRoam
---@param config org-roam.Config
local function merge_config(roam, config)
    assert(config.directory, "missing org-roam directory")

    -- Normalize the roam directory before storing it
    ---@diagnostic disable-next-line:inject-field
    config.directory = vim.fs.normalize(config.directory)

    -- Merge our configuration options into our global config
    roam.config:replace(config)
end

---@param roam OrgRoam
local function define_autocmds(roam)
    -- Watch as cursor moves around so we can support node changes
    local last_node = nil
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = AUGROUP,
        pattern = "*.org",
        callback = function()
            roam.utils.node_under_cursor(function(node)
                -- If the node has changed (event getting cleared),
                -- we want to emit the event
                if last_node ~= node then
                    if node then
                        log.fmt_debug("New node under cursor: %s", node.id)
                    end

                    roam.evt.emit(roam.evt.KIND.CURSOR_NODE_CHANGED, node)
                end

                last_node = node
            end)
        end,
    })

    -- If configured to update on save, listen for buffer writing
    -- and trigger reload if an org-roam buffer
    if roam.config.database.update_on_save then
        vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
            group = AUGROUP,
            pattern = "*.org",
            callback = function()
                -- TODO: If the directory format changes to blob in the
                --       future, this will break. Is there a better way
                --       to check if a file is an org-roam file?
                local path = vim.fn.expand("<afile>:p")
                local is_roam_file = vim.startswith(path, roam.config.directory)

                if is_roam_file then
                    log.fmt_debug("Updating on save: %s", path)
                    roam.db:load_file({ path = path }):catch(notify.error)
                end
            end,
        })
    end

    -- If configured to persist to disk, look for when neovim is exiting
    -- and save an updated version of the database
    if roam.config.database.persist then
        vim.api.nvim_create_autocmd("VimLeavePre", {
            group = AUGROUP,
            pattern = "*",
            callback = function()
                roam.db:save():catch(notify.error)
            end,
        })
    end
end

---@param roam OrgRoam
local function define_commands(roam)
    local Profiler = require("org-roam.core.utils.profiler")

    vim.api.nvim_create_user_command("RoamSave", function(opts)
        log.fmt_debug("Saving database")

        -- Start profiling so we can report the time taken
        local profiler = Profiler:new()
        profiler:start()

        roam.db:save():next(function(...)
            local tt = profiler:stop():time_taken_as_string()
            notify.info("Saved database [took " .. tt .. "]")
            return ...
        end):catch(notify.error)
    end, { bang = true, desc = "Saves the roam database" })

    vim.api.nvim_create_user_command("RoamUpdate", function(opts)
        local force = opts.bang or false

        -- Start profiling so we can report the time taken
        local profiler = Profiler:new()
        profiler:start()

        log.fmt_debug("Updating database (force = %s)", force)
        roam.db:load({ force = force }):next(function(...)
            local tt = profiler:stop():time_taken_as_string()
            notify.info("Updated database [took " .. tt .. "]")
            return ...
        end):catch(notify.error)
    end, { bang = true, desc = "Updates the roam database" })

    vim.api.nvim_create_user_command("RoamDatabaseReset", function()
        log.debug("Resetting database")
        roam.db:delete_disk_cache():next(function(success)
            roam.db = roam.db:new({
                db_path = roam.db:path(),
                directory = roam.db:files_path(),
            })

            -- Start profiling so we can report the time taken
            local profiler = Profiler:new()
            profiler:start()
            roam.db:load():next(function(...)
                local tt = profiler:stop():time_taken_as_string()
                notify.info("Loaded database [took " .. tt .. "]")
                return ...
            end):catch(notify.error)

            return success
        end)
    end, { desc = "Completely wipes the roam database" })

    vim.api.nvim_create_user_command("RoamAddAlias", function(opts)
        ---@type string|nil
        local alias = vim.trim(opts.args)
        if alias and alias == "" then
            alias = nil
        end

        roam.api.add_alias({ alias = alias })
    end, {
        desc = "Adds an alias to the current node under cursor",
        nargs = "*",
    })

    vim.api.nvim_create_user_command("RoamRemoveAlias", function(opts)
        local all = opts.bang or false

        ---@type string|nil
        local alias = vim.trim(opts.args)
        if alias and alias == "" then
            alias = nil
        end

        roam.api.remove_alias({ alias = alias, all = all })
    end, {
        bang = true,
        desc = "Removes an alias from the current node under cursor",
        nargs = "*",
    })

    vim.api.nvim_create_user_command("RoamAddOrigin", function(opts)
        ---@type string|nil
        local origin = vim.trim(opts.args)
        if origin and origin == "" then
            origin = nil
        end

        roam.api.add_origin({ origin = origin })
    end, {
        desc = "Adds an origin to the current node under cursor",
        nargs = "*",
    })

    vim.api.nvim_create_user_command("RoamRemoveOrigin", function()
        roam.api.remove_origin()
    end, {
        bang = true,
        desc = "Removes an origin from the current node under cursor",
    })
end

---@param roam OrgRoam
local function define_keybindings(roam)
    -- User can remove all bindings by setting this to nil
    local bindings = roam.config.bindings or {}

    ---Retrievies selection if in visual mode.
    ---Returns "unsupported" if blockwise-visual mode.
    ---Returns false if not in visual/linewise-visual mode.
    ---@return {title:string, ranges:org-roam.utils.Range[]}|"unsupported"|false
    local function get_visual_selection()
        ---@type string
        local mode = vim.api.nvim_get_mode()["mode"]

        -- Handle visual mode and linewise visual mode
        -- (ignore blockwise-visual mode)
        if mode == "v" or mode == "V" then
            local lines, ranges = roam.utils.get_visual_selection({ single_line = true })
            local title = lines[1] or ""

            return { title = title, ranges = ranges }
        elseif mode == "\x16" then
            -- Force exit visual block mode
            local ESC_FEEDKEY = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
            vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)

            vim.schedule(function()
                notify.echo_error("node insertion not supported for blockwise-visual mode")
            end)

            return "unsupported"
        else
            return false
        end
    end

    ---@param lhs string|{lhs:string, modes:org-roam.config.NvimMode[]}|nil
    ---@param desc string
    ---@param cb fun()
    local function assign(lhs, desc, cb)
        if type(cb) ~= "function" then return end
        if not lhs then return end

        local modes = { "n" }
        if type(lhs) == "table" then
            modes = lhs.modes
            lhs = lhs.lhs
        end

        if vim.trim(lhs) == "" or #modes == 0 then return end

        for _, mode in ipairs(modes) do
            vim.api.nvim_set_keymap(mode, lhs, "", {
                desc = desc,
                noremap = true,
                callback = cb,
            })
        end
    end

    assign(
        bindings.add_alias,
        "Adds an alias to the roam node under cursor",
        roam.api.add_alias
    )

    assign(
        bindings.remove_alias,
        "Removes an alias from the roam node under cursor",
        roam.api.remove_alias
    )

    assign(
        bindings.add_origin,
        "Adds an origin to the roam node under cursor",
        roam.api.add_origin
    )

    assign(
        bindings.remove_origin,
        "Removes the origin from the roam node under cursor",
        roam.api.remove_origin
    )

    assign(
        bindings.goto_prev_node,
        "Goes to the previous node sequentially based on origin of the node under cursor",
        roam.api.goto_prev_node
    )

    assign(
        bindings.goto_next_node,
        "Goes to the next node sequentially based on origin of the node under cursor",
        roam.api.goto_next_node
    )

    assign(
        bindings.quickfix_backlinks,
        "Open quickfix of backlinks for org-roam node under cursor",
        function()
            roam.ui.open_quickfix_list({
                backlinks = true,
                show_preview = true,
            })
        end
    )

    assign(
        bindings.toggle_roam_buffer,
        "Toggles org-roam buffer for node under cursor",
        function()
            roam.ui.toggle_node_buffer({
                focus = roam.config.ui.node_buffer.focus_on_toggle,
            })
        end
    )

    assign(
        bindings.toggle_roam_buffer_fixed,
        "Toggles org-roam buffer for a specific node, not changing",
        function()
            roam.ui.toggle_node_buffer({
                fixed = true,
                focus = roam.config.ui.node_buffer.focus_on_toggle,
            })
        end
    )

    assign(
        bindings.complete_at_point,
        "Completes link to a node based on expression under cursor",
        roam.api.complete_node
    )

    assign(
        { lhs = bindings.capture, modes = { "n", "v" } },
        "Opens org-roam capture window",
        function()
            local results = get_visual_selection()
            local title
            if type(results) == "table" then
                title = results.title
            elseif results == "unsupported" then
                return
            end
            roam.api.capture_node({
                title = title,
            })
        end
    )

    assign(
        { lhs = bindings.find_node, modes = { "n", "v" } },
        "Finds org-roam node and moves to it, creating new one if missing",
        function()
            local results = get_visual_selection()
            local title
            if type(results) == "table" then
                title = results.title
            elseif results == "unsupported" then
                return
            end
            roam.api.find_node({
                title = title,
            })
        end
    )

    assign(
        { lhs = bindings.insert_node, modes = { "n", "v" } },
        "Inserts at cursor position the selected node, creating new one if missing",
        function()
            local results = get_visual_selection()
            local title, ranges
            if type(results) == "table" then
                title = results.title
                ranges = results.ranges
            elseif results == "unsupported" then
                return
            end
            roam.api.insert_node({
                title = title,
                ranges = ranges,
            })
        end
    )

    assign(
        { lhs = bindings.insert_node_immediate, modes = { "n", "v" } },
        "Inserts at cursor position the selected node, creating new one if missing without opening a capture buffer",
        function()
            local results = get_visual_selection()
            local title, ranges
            if type(results) == "table" then
                title = results.title
                ranges = results.ranges
            elseif results == "unsupported" then
                return
            end
            roam.api.insert_node({
                immediate = true,
                title = title,
                ranges = ranges,
            })
        end
    )
end

---@param roam OrgRoam
local function modify_orgmode_plugin(roam)
    -- Provide a wrapper around `open_at_point` from orgmode mappings so we can
    -- attempt to jump to an id referenced by our database first, and then fall
    -- back to orgmode's id handling second.
    --
    -- This is needed as the default `open_at_point` only respects orgmode's
    -- files list and not org-roam's files list; so, we need to manually intercept!
    ---@diagnostic disable-next-line:duplicate-set-field
    require("orgmode").org_mappings.open_at_point = function(self)
        local row, col = vim.fn.getline("."), vim.fn.col(".") or 0
        local link = require("orgmode.org.hyperlinks.link").at_pos(row, col)
        local id = link and link.url:get_id()
        local node = id and roam.db:get_sync(id)

        -- If we found a node, open the file at the start of the node
        if node then
            log.fmt_debug("Detected node %s under at (%d,%d)",
                node.id, row, col)
            local winnr = vim.api.nvim_get_current_win()
            vim.cmd.edit(node.file)

            -- NOTE: Schedule so we have time to process loading the buffer first!
            vim.schedule(function()
                -- Ensure that we do not jump past our buffer's last line!
                local bufnr = vim.api.nvim_win_get_buf(winnr)
                local line = math.min(
                    vim.api.nvim_buf_line_count(bufnr),
                    node.range.start.row + 1
                )

                vim.api.nvim_win_set_cursor(winnr, { line, 0 })
            end)

            return
        end

        -- Fall back to the default implementation
        return require("orgmode.org.mappings").open_at_point(self)
    end
end

---@param roam OrgRoam
local function initialize_database(roam)
    local Promise = require("orgmode.utils.promise")

    -- Swap out the database for one configured properly
    roam.db = roam.db:new({
        db_path = roam.config.database.path,
        directory = roam.config.directory,
    })

    -- Load the database asynchronously
    roam.db:load():next(function()
        -- If we are persisting to disk, do so now as the database may
        -- have changed post-load
        if roam.config.database.persist then
            return roam.db:save()
        else
            return Promise.resolve(nil)
        end
    end):catch(notify.error)
end

---@param roam OrgRoam
---@return org-roam.Setup
return function(roam)
    ---@class org-roam.Setup
    ---@operator call(org-roam.Config):nil
    local M = setmetatable({}, {
        __call = function(this, config)
            this.call(config)
        end
    })

    ---Calls the setup function to initialize the plugin.
    ---@param config org-roam.Config|nil
    function M.call(config)
        M.__merge_config(config or {})
        M.__define_autocmds()
        M.__define_commands()
        M.__define_keybindings()
        M.__modify_orgmode_plugin()
        M.__initialize_database()
    end

    ---@private
    function M.__merge_config(config)
        if not M.__merge_config_done then
            merge_config(roam, config)
            M.__merge_config_done = true
        end
    end

    ---@private
    function M.__define_autocmds()
        if not M.__define_autocmds_done then
            define_autocmds(roam)
            M.__define_autocmds_done = true
        end
    end

    ---@private
    function M.__define_commands()
        if not M.__define_commands_done then
            define_commands(roam)
            M.__define_commands_done = true
        end
    end

    ---@private
    function M.__define_keybindings()
        if not M.__define_keybindings_done then
            define_keybindings(roam)
            M.__define_keybindings_done = true
        end
    end

    ---@private
    function M.__modify_orgmode_plugin()
        if not M.__modify_orgmode_plugin_done then
            modify_orgmode_plugin(roam)
            M.__modify_orgmode_plugin_done = true
        end
    end

    ---@private
    function M.__initialize_database()
        if not M.__initialize_database_done then
            initialize_database(roam)
            M.__initialize_database_done = true
        end
    end

    return M
end
