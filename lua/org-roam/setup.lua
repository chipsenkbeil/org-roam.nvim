-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")
local EVENTS = require("org-roam.events")
local AUGROUP = vim.api.nvim_create_augroup("org-roam.nvim", {})

local log = require("org-roam.core.log")

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

---@param config org-roam.Config
---@return org-roam.Config
local function merge_config(config)
    assert(config.directory, "missing org-roam directory")

    -- Normalize the roam directory before storing it
    ---@diagnostic disable-next-line:inject-field
    config.directory = vim.fs.normalize(config.directory)

    -- Merge our configuration options into our global config
    CONFIG(config)

    ---@type org-roam.Config
    return CONFIG
end

---@param config org-roam.Config
local function define_autocmds(config)
    -- Watch as cursor moves around so we can support node changes
    local last_node = nil
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = AUGROUP,
        pattern = "*.org",
        callback = function()
            local utils = require("org-roam.utils")
            utils.node_under_cursor(function(node)
                -- If the node has changed (event getting cleared),
                -- we want to emit the event
                if last_node ~= node then
                    if node then
                        log.fmt_debug("New node under cursor: %s", node.id)
                    end

                    EVENTS:emit(EVENTS.KIND.CURSOR_NODE_CHANGED, node)
                end

                last_node = node
            end)
        end,
    })

    -- If configured to update on save, listen for buffer writing
    -- and trigger reload if an org-roam buffer
    if config.database.update_on_save then
        vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
            group = AUGROUP,
            pattern = "*.org",
            callback = function()
                -- TODO: If the directory format changes to blob in the
                --       future, this will break. Is there a better way
                --       to check if a file is an org-roam file?
                local path = vim.fn.expand("<afile>:p")
                local is_roam_file = vim.startswith(path, config.directory)

                if is_roam_file then
                    log.fmt_debug("Updating on save: %s", path)
                    require("org-roam.database")
                        :load_file({ path = path })
                        :catch(require("org-roam.core.ui.notify").error)
                end
            end,
        })
    end

    -- If configured to persist to disk, look for when neovim is exiting
    -- and save an updated version of the database
    if config.database.persist then
        vim.api.nvim_create_autocmd("VimLeavePre", {
            group = AUGROUP,
            pattern = "*",
            callback = function()
                require("org-roam.database")
                    :save()
                    :catch(require("org-roam.core.ui.notify").error)
            end,
        })
    end
end

---@param config org-roam.Config
local function define_commands(config)
    local notify = require("org-roam.core.ui.notify")
    local Profiler = require("org-roam.core.utils.profiler")

    vim.api.nvim_create_user_command("RoamSave", function(opts)
        log.fmt_debug("Saving database")

        -- Start profiling so we can report the time taken
        local profiler = Profiler:new()
        profiler:start()

        require("org-roam.database")
            :save()
            :next(function(...)
                local tt = profiler:stop():time_taken_as_string()
                notify.info("Saved database [took " .. tt .. "]")
                return ...
            end)
            :catch(notify.error)
    end, { bang = true, desc = "Saves the roam database" })

    vim.api.nvim_create_user_command("RoamUpdate", function(opts)
        local force = opts.bang or false

        -- Start profiling so we can report the time taken
        local profiler = Profiler:new()
        profiler:start()

        log.fmt_debug("Updating database (force = %s)", force)
        require("org-roam.database")
            :load({ force = force })
            :next(function(...)
                local tt = profiler:stop():time_taken_as_string()
                notify.info("Updated database [took " .. tt .. "]")
                return ...
            end)
            :catch(notify.error)
    end, { bang = true, desc = "Updates the roam database" })

    vim.api.nvim_create_user_command("RoamAddAlias", function(opts)
        ---@type string|nil
        local alias = vim.trim(opts.args)
        if alias and alias == "" then
            alias = nil
        end

        require("org-roam.api").add_alias({ alias = alias })
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

        require("org-roam.api").remove_alias({ alias = alias, all = all })
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

        require("org-roam.api").add_origin({ origin = origin })
    end, {
        desc = "Adds an origin to the current node under cursor",
        nargs = "*",
    })

    vim.api.nvim_create_user_command("RoamRemoveOrigin", function()
        require("org-roam.api").remove_origin()
    end, {
        bang = true,
        desc = "Removes an origin from the current node under cursor",
    })
end

---@param config org-roam.Config
local function define_keybindings(config)
    -- User can remove all bindings by setting this to nil
    local bindings = config.bindings or {}

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
            local utils = require("org-roam.utils")
            local lines, ranges = utils.get_visual_selection({ single_line = true })
            local title = lines[1] or ""

            return { title = title, ranges = ranges }
        elseif mode == "\x16" then
            -- Force exit visual block mode
            local ESC_FEEDKEY = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)
            vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)

            vim.schedule(function()
                require("org-roam.core.ui.notify").echo_error(
                    "node insertion not supported for blockwise-visual mode"
                )
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
        require("org-roam.api").add_alias
    )

    assign(
        bindings.remove_alias,
        "Removes an alias from the roam node under cursor",
        require("org-roam.api").remove_alias
    )

    assign(
        bindings.add_origin,
        "Adds an origin to the roam node under cursor",
        require("org-roam.api").add_origin
    )

    assign(
        bindings.remove_origin,
        "Removes the origin from the roam node under cursor",
        require("org-roam.api").remove_origin
    )

    assign(
        bindings.quickfix_backlinks,
        "Open quickfix of backlinks for org-roam node under cursor",
        function()
            require("org-roam.api").open_quickfix_list({
                backlinks = true,
                show_preview = true,
            })
        end
    )

    assign(
        bindings.toggle_roam_buffer,
        "Opens org-roam buffer for node under cursor",
        require("org-roam.api").open_node_buffer
    )

    assign(
        bindings.toggle_roam_buffer_fixed,
        "Opens org-roam buffer for a specific node, not changing",
        function()
            require("org-roam.api").open_node_buffer({ fixed = true })
        end
    )

    assign(
        bindings.complete_at_point,
        "Completes link to a node based on expression under cursor",
        require("org-roam.api").complete_node
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
            require("org-roam.api").capture_node({
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
            require("org-roam.api").find_node({
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
            require("org-roam.api").insert_node({
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
            require("org-roam.api").insert_node({
                immediate = true,
                title = title,
                ranges = ranges,
            })
        end
    )
end

---@param config org-roam.Config
local function modify_orgmode_plugin(config)
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
        local node = id and require("org-roam.database"):get_sync(id)

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

---@param config org-roam.Config
local function initialize_database(config)
    local db      = require("org-roam.database")
    local Promise = require("orgmode.utils.promise")

    -- Load the database asynchronously
    db:load():next(function()
        -- If we are persisting to disk, do so now as the database may
        -- have changed post-load
        if config.database.persist then
            return db:save()
        else
            return Promise.resolve(nil)
        end
    end):catch(function(err)
        require("org-roam.core.ui.notify").error(err)
    end)
end

---@param this OrgRoam
---@param config org-roam.Config
local function populate_plugin(this, config)
    this.api    = require("org-roam.api")
    this.config = config
    this.db     = require("org-roam.database")
    this.evt    = require("org-roam.events")
    this.ext    = require("org-roam.extensions")
end

---Initializes the plugin.
---@param this OrgRoam
---@param config org-roam.Config
return function(this, config)
    config = merge_config(config)
    define_autocmds(config)
    define_commands(config)
    define_keybindings(config)
    modify_orgmode_plugin(config)
    initialize_database(config)
    populate_plugin(this, config)
end
