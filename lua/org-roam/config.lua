-------------------------------------------------------------------------------
-- CONFIG.LUA
--
-- Contains global config logic used by the plugin.
-------------------------------------------------------------------------------

local path = require("org-roam.core.utils.path")

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

    ---If true, updates database whenever a write occurs.
    ---@type boolean
    update_on_save = true,

    ---Bindings associated with org-roam functionality.
    ---@class org-roam.config.Bindings
    bindings = {
        ---Opens org-roam capture window.
        capture = "<C-c>nc",

        ---Completes the node under cursor.
        complete_at_point = "<M-/>",

        ---Finds node and moves to it.
        find_node = "<C-c>nf",

        ---Inserts node at cursor position.
        insert_node = "<C-c>ni",

        ---Prints the node under cursor.
        print_node = "<C-c>np",

        ---Opens the quickfix menu for backlinks to the current node under cursor.
        quickfix_backlinks = "<C-c>nq",

        ---Toggles the org-roam node-view buffer for the node under cursor.
        toggle_roam_buffer = "<C-c>nl",

        ---Toggles a fixed org-roam node-view buffer for a selected node.
        toggle_roam_buffer_fixed = "<C-c>nb",
    },

    ---@class org-roam.config.Templates
    ---@field [string] table
    templates = {
        d = {
            description = "default",
            template = "* %?",
            target = "%r" .. path.separator() .. "%<%Y%m%d%H%M%S>-%[slug].org",
        },
    },

    ---@class org-roam.config.UserInterface
    ui = {
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
