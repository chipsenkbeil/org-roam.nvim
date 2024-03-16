-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")

---@param config org-roam.Config
local function merge_config(config)
    assert(config.directory, "missing org-roam directory")

    -- Normalize the roam directory before storing it
    ---@diagnostic disable-next-line:inject-field
    config.directory = vim.fs.normalize(config.directory)

    -- Merge our configuration options into our global config
    CONFIG(config)
end

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

local function define_keybindings()
    assign(
        CONFIG.bindings.quickfix_backlinks,
        "Open quickfix of backlinks for org-roam node under cursor",
        function()
            require("org-roam.ui.quickfix")({
                backlinks = true,
                show_preview = true,
            })
        end
    )

    assign(
        CONFIG.bindings.print_node,
        "Print org-roam node under cursor",
        require("org-roam.ui.print-node")
    )

    assign(
        CONFIG.bindings.toggle_roam_buffer,
        "Opens org-roam buffer for node under cursor",
        require("org-roam.ui.node-view")
    )

    assign(
        CONFIG.bindings.toggle_roam_buffer_fixed,
        "Opens org-roam buffer for a specific node, not changing",
        function() require("org-roam.ui.node-view")({ fixed = true }) end
    )

    assign(
        CONFIG.bindings.complete_at_point,
        "Completes link to a node based on expression under cursor",
        require("org-roam.completion").complete_node_under_cursor
    )
end

---Initializes the plugin, returning the database associated with nodes.
---@param opts org-roam.Config
return function(opts)
    merge_config(opts)
    define_keybindings()
end
