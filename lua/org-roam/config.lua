-------------------------------------------------------------------------------
-- CONFIG.LUA
--
-- Contains global config logic used by the plugin.
-------------------------------------------------------------------------------

local path = require("org-roam.core.utils.path")

---Base path for our plugin.
---@type string
local BASE_PATH = path.join(vim.fn.stdpath("data"), "org-roam.nvim")

---Overwrites configuration options with those specified.
---@param tbl org-roam.Config
---@param opts org-roam.Config
local function replace(tbl, opts)
    if type(opts) ~= "table" then
        return
    end

    -- Create a new config based on old config, ovewriting
    -- with supplied options
    local config = vim.tbl_deep_extend("force", tbl, opts)

    -- Replace all top-level keys of old config with new
    ---@diagnostic disable-next-line:no-unknown
    for key, value in pairs(config) do
        ---@diagnostic disable-next-line:no-unknown
        tbl[key] = value
    end
end

---@class org-roam.Config
---@overload fun(config:org-roam.Config)
local config = setmetatable({
    ---Path to the directory containing org files for use with org-roam.
    ---@type string
    directory = "",

    ---Bindings associated with org-roam functionality.
    ---@class org-roam.config.Bindings
    bindings = {
        ---Opens org-roam capture window.
        capture = "<Leader>nc",

        ---Completes the node under cursor.
        complete_at_point = "<Leader>n/",

        ---Finds node and moves to it.
        find_node = "<Leader>nf",

        ---Inserts node at cursor position.
        insert_node = "<Leader>ni",

        ---Opens the quickfix menu for backlinks to the current node under cursor.
        quickfix_backlinks = "<Leader>nq",

        ---Toggles the org-roam node-view buffer for the node under cursor.
        toggle_roam_buffer = "<Leader>nl",

        ---Toggles a fixed org-roam node-view buffer for a selected node.
        toggle_roam_buffer_fixed = "<Leader>nb",
    },

    ---Settings associated with org-roam's database.
    ---@class org-roam.config.Database
    database = {
        ---Path where the database will be stored & loaded when
        ---persisting to disk.
        ---@type string
        path = path.join(BASE_PATH, "db"),

        ---If true, the database will be written to disk to save on
        ---future loading times; otherwise, whenever neovim boots the
        ---entire database will need to be rebuilt.
        ---@type boolean
        persist = true,

        ---If true, updates database whenever a write occurs.
        ---@type boolean
        update_on_save = true,
    },

    ---@class org-roam.config.Templates
    ---@field [string] table
    templates = {
        d = {
            description = "default",
            template = "%?",
            target = "%r%[sep]%<%Y%m%d%H%M%S>-%[slug].org",
        },
    },

    ---@class org-roam.config.UserInterface
    ui = {
        ---@class org-roam.config.ui.Mouse
        mouse = {
            ---If true, clicking on links will open them.
            ---@type boolean
            click_open_links = true,

            ---If true, highlights links when mousing over them.
            ---This will enable `vim.opt.mouseoverevent` if disabled!
            ---@type boolean
            highlight_links = true,

            ---Highlight group to apply when highlighting links.
            ---@type string
            highlight_links_group = "WarningMsg",
        },

        ---@class org-roam.config.ui.NodeView
        node_view = {
            ---If true, previews will be highlighted as org syntax when expanded.
            ---
            ---NOTE: This can cause flickering on initial expansion, but preview
            ---      highlights are then cached for future renderings. If flickering
            ---      is undesired, disable highlight previews.
            ---@type boolean
            highlight_previews = true,

            ---If true, will include a section covering available keybindings.
            ---@type boolean
            show_keybindings = true,

            ---If true, shows a single link (backlink/citation/unlinked reference)
            ---per node instead of all links.
            ---@type boolean
            unique = false,
        },
    },
}, { __call = replace })

return config
