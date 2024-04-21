-------------------------------------------------------------------------------
-- CONFIG.LUA
--
-- Contains global config logic used by the plugin.
-------------------------------------------------------------------------------

local path = require("org-roam.core.utils.path")

---Base path for our plugin.
---@type string
local BASE_PATH = path.join(vim.fn.stdpath("data"), "org-roam.nvim")

---@class org-roam.config.Data
local DEFAULT_CONFIG = {
    ---Path to the directory containing org files for use with org-roam.
    ---@type string
    directory = "",

    ---Bindings associated with org-roam functionality.
    ---@class org-roam.config.Bindings
    bindings = {
        ---Adds an alias to the node under cursor.
        add_alias = "<Leader>naa",

        ---Adds an origin to the node under cursor.
        add_origin = "<Leader>noa",

        ---Opens org-roam capture window.
        capture = "<Leader>nc",

        ---Completes the node under cursor.
        complete_at_point = "<Leader>n.",

        ---Finds node and moves to it.
        find_node = "<Leader>nf",

        ---Goes to the next node sequentially based on origin of the node under cursor.
        ---
        ---If more than one node has the node under cursor as its origin, a selection
        ---dialog is displayed to choose the node.
        goto_next_node = "<Leader>nn",

        ---Goes to the previous node sequentially based on origin of the node under cursor.
        goto_prev_node = "<Leader>np",

        ---Inserts node at cursor position.
        insert_node = "<Leader>ni",

        ---Inserts node at cursor position without opening capture buffer.
        insert_node_immediate = "<Leader>nm",

        ---Opens the quickfix menu for backlinks to the current node under cursor.
        quickfix_backlinks = "<Leader>nq",

        ---Removes an alias from the node under cursor.
        remove_alias = "<Leader>nar",

        ---Removes the origin from the node under cursor.
        remove_origin = "<Leader>nor",

        ---Toggles the org-roam node-view buffer for the node under cursor.
        toggle_roam_buffer = "<Leader>nl",

        ---Toggles a fixed org-roam node-view buffer for a selected node.
        toggle_roam_buffer_fixed = "<Leader>nb",
    },

    ---Settings associated with org-roam capture logic.
    ---@class org-roam.config.Capture
    capture = {
        ---If true, will include the origin in the capture buffer if the
        ---capture originated from an org-roam node.
        ---@type boolean
        include_origin = true,
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

    ---Settings tied to org-roam immediate mode.
    ---@class org-roam.config.Immediate
    immediate = {
        ---Target where the immediate-mode node should be written.
        ---@type string
        target = "%r%[sep]%<%Y%m%d%H%M%S>-%[slug].org",

        ---Template to use for the immediate-mode node's content.
        ---@type string
        template = "",
    },

    ---Settings tied to org-roam capture templates.
    ---@class org-roam.config.Templates
    ---@field [string] OrgCaptureTemplateOpts
    templates = {
        d = {
            description = "default",
            template = "%?",
            target = "%r%[sep]%<%Y%m%d%H%M%S>-%[slug].org",
        },
    },

    ---Settings tied to the user interface.
    ---@class org-roam.config.UserInterface
    ui = {
        ---Node view buffer configuration settings.
        ---@class org-roam.config.ui.NodeView
        node_buffer = {
            ---If true, switches focus to the node buffer when it opens.
            ---@type boolean
            focus_on_toggle = true,

            ---If true, previews will be highlighted as org syntax when expanded.
            ---
            ---NOTE: This can cause flickering on initial expansion, but preview
            ---      highlights are then cached for future renderings. If flickering
            ---      is undesired, disable highlight previews.
            ---@type boolean
            highlight_previews = true,

            ---Configuration to open the node view window.
            ---Can be a string, or a function that returns the window handle.
            ---@type string|fun():integer
            open = "botright vsplit | vertical resize 50",

            ---If true, will include a section covering available keybindings.
            ---@type boolean
            show_keybindings = true,

            ---If true, shows a single link (backlink/citation/unlinked reference)
            ---per node instead of all links.
            ---@type boolean
            unique = false,
        },
    },
}

---Global configuration settings leveraged through org-roam.
---@class org-roam.Config: org-roam.config.Data
local M = {}
M.__index = M

---Creates a new instance of the config.
---
---If `data` provided, extends config with it.
---@param data? org-roam.config.Data
---@return org-roam.Config
function M:new(data)
    local instance = vim.deepcopy(DEFAULT_CONFIG)
    setmetatable(instance, M)

    if data then
        instance:replace(data)
    end

    ---@cast instance org-roam.Config
    return instance
end

---Overwrites configuration options with those specified.
---@param data org-roam.config.Data
---@return org-roam.Config
function M:replace(data)
    if type(data) ~= "table" then
        return self
    end

    -- Create a new config based on old config, ovewriting
    -- with supplied options
    local config = vim.tbl_deep_extend("force", self, data)

    -- Replace all top-level keys of old config with new
    ---@diagnostic disable-next-line:no-unknown
    for key, value in pairs(config) do
        -- Special case for templates, as we don't want to merge
        -- old and new, but rather replace old with new, to avoid
        -- issue where it's impossible to remove the old template
        if key == "templates" and type(data[key]) == "table" then
            self[key] = vim.deepcopy(data[key])
        else
            ---@diagnostic disable-next-line:no-unknown
            self[key] = value
        end
    end

    return self
end

return M
