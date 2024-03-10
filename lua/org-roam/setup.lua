-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")
local buffer = require("org-roam.buffer")

local function define_autocmds()
    -- Define our autocommands for the plugin
    local GROUP = vim.api.nvim_create_augroup("OrgRoam", { clear = true })
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = GROUP,
        pattern = "*",
        callback = function(args)
            ---@type integer
            local bufnr = args.buf
            buffer.set_dirty_flag(bufnr, true)
        end,
    })
end

---@param opts org-roam.core.config.Config.NewOpts
local function merge_config(opts)
    -- Normalize the roam directory before storing it
    opts.org_roam_directory = vim.fs.normalize(opts.org_roam_directory)

    -- Merge our configuration options into our global config
    ---@diagnostic disable-next-line:param-type-mismatch
    CONFIG:merge(opts)
end

local function define_keybindings()
    vim.api.nvim_set_keymap("n", "<LocalLeader>rqb", "", {
        desc = "Open quickfix of backlinks for org-roam node under cursor",
        noremap = true,
        callback = function()
            require("org-roam").open_qflist_for_node_under_cursor()
        end,
    })

    vim.api.nvim_set_keymap("n", "<LocalLeader>rpn", "", {
        desc = "Print org-roam node under cursor",
        noremap = true,
        callback = function()
            require("org-roam").print_node_under_cursor()
        end,
    })

    vim.api.nvim_set_keymap("n", "<LocalLeader>rbn", "", {
        desc = "Opens org-roam buffer for node under cursor",
        noremap = true,
        callback = function()
            require("org-roam").toggle_roam_buffer()
        end,
    })
end

---Initializes the plugin, returning the database associated with nodes.
---@param opts org-roam.core.config.Config.NewOpts
return function(opts)
    define_autocmds()
    merge_config(opts)
    define_keybindings()
end
