-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")
local EVENTS = require("org-roam.events")

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
    local group = vim.api.nvim_create_augroup("org-roam.nvim", {})

    -- Watch as cursor moves around so we can support node changes
    local last_node = nil
    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        pattern = "*.org",
        callback = function()
            local utils = require("org-roam.utils")
            utils.node_under_cursor(function(node)
                -- If the node has changed (event getting cleared),
                -- we want to emit the event
                if last_node ~= node then
                    EVENTS:emit(EVENTS.KIND.CURSOR_NODE_CHANGED, node)
                end

                last_node = node
            end)
        end,
    })

    -- If configured to update on save, listen for buffer writing
    -- and trigger reload if an org-roam buffer
    if config.update_on_save then
        vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
            group = group,
            pattern = "*.org",
            callback = function()
                -- TODO: If the directory format changes to blob in the
                --       future, this will break. Is there a better way
                --       to check if a file is an org-roam file?
                local path = vim.fn.expand("<afile>:p")
                local is_roam_file = vim.startswith(path, config.directory)

                if is_roam_file then
                    require("org-roam.database"):load(function(err)
                        if err then
                            require("org-roam.core.ui.notify").error(err)
                            return
                        end
                    end, { force = true })
                end
            end,
        })
    end
end

local function define_commands()
    vim.api.nvim_create_user_command("OrgRoamUpdate", function(_)
        require("org-roam.database"):load(function(err)
            if err then
                require("org-roam.core.ui.notify").error(err)
            end
        end)
    end, { desc = "Wipes the database" })
end

local function define_keybindings()
    -- User can remove all bindings by setting this to nil
    local bindings = CONFIG.bindings or {}

    ---@param lhs string|nil
    ---@param desc string
    ---@param cb fun()
    local function assign(lhs, desc, cb)
        if type(lhs) == "string" and lhs ~= "" and type(cb) == "function" then
            vim.api.nvim_set_keymap("n", lhs, "", {
                desc = desc,
                noremap = true,
                callback = cb,
            })
        end
    end

    assign(
        bindings.quickfix_backlinks,
        "Open quickfix of backlinks for org-roam node under cursor",
        function()
            require("org-roam.ui.quickfix")({
                backlinks = true,
                show_preview = true,
            })
        end
    )

    assign(
        bindings.print_node,
        "Print org-roam node under cursor",
        require("org-roam.ui.print-node")
    )

    assign(
        bindings.toggle_roam_buffer,
        "Opens org-roam buffer for node under cursor",
        require("org-roam.ui.node-view")
    )

    assign(
        bindings.toggle_roam_buffer_fixed,
        "Opens org-roam buffer for a specific node, not changing",
        function() require("org-roam.ui.node-view")({ fixed = true }) end
    )

    assign(
        bindings.complete_at_point,
        "Completes link to a node based on expression under cursor",
        require("org-roam.completion").complete_node_under_cursor
    )

    assign(
        bindings.capture,
        "Opens org-roam capture window",
        require("org-roam.node").capture
    )

    assign(
        bindings.find_node,
        "Finds org-roam node and moves to it, creating new one if missing",
        require("org-roam.node").find
    )

    assign(
        bindings.insert_node,
        "Inserts at cursor position the selected node, creating new one if missing",
        require("org-roam.node").insert
    )
end

---Initializes the plugin.
---@param config org-roam.Config
return function(config)
    config = merge_config(config)
    define_autocmds(config)
    define_commands()
    define_keybindings()
end
