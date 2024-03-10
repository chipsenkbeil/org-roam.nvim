-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")
local buffer = require("org-roam.buffer")

---@param opts org-roam.core.config.Config.NewOpts
local function merge_config(opts)
    -- Normalize the roam directory before storing it
    opts.org_roam_directory = vim.fs.normalize(opts.org_roam_directory)

    -- Merge our configuration options into our global config
    ---@diagnostic disable-next-line:param-type-mismatch
    CONFIG:merge(opts)
end

local function define_keybindings()
    vim.api.nvim_set_keymap("n", "<LocalLeader>rnqb", "", {
        desc = "Open quickfix of backlinks for org-roam node under cursor",
        noremap = true,
        callback = function()
            require("org-roam.ui.quickfix").open_for_node_under_cursor({ show_preview = true })
        end,
    })

    vim.api.nvim_set_keymap("n", "<LocalLeader>rnp", "", {
        desc = "Print org-roam node under cursor",
        noremap = true,
        callback = function()
            require("org-roam").print_node_under_cursor()
        end,
    })

    vim.api.nvim_set_keymap("n", "<LocalLeader>rnb", "", {
        desc = "Opens org-roam buffer for node under cursor",
        noremap = true,
        callback = function()
            require("org-roam.ui.window").toggle_node_view()
        end,
    })

    vim.api.nvim_set_keymap("n", "<LocalLeader>rnfb", "", {
        desc = "Opens org-roam buffer for a specific node, not changing",
        noremap = true,
        callback = function()
            require("org-roam.ui.window").toggle_fixed_node_view()
        end,
    })
end

---Initializes the plugin, returning the database associated with nodes.
---@param opts org-roam.core.config.Config.NewOpts
return function(opts)
    merge_config(opts)
    define_keybindings()
end
