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
        ---Adjusts the prefix for every keybinding. Can be used in keybindings with <prefix>.
        prefix = "<Leader>n",
        ---Adds an alias to the node under cursor.
        add_alias = "<prefix>aa",

        ---Adds an origin to the node under cursor.
        add_origin = "<prefix>oa",

        ---Opens org-roam capture window.
        capture = "<prefix>c",

        ---Completes the node under cursor.
        complete_at_point = "<prefix>.",

        ---Finds node and moves to it.
        find_node = "<prefix>f",

        ---Goes to the next node sequentially based on origin of the node under cursor.
        ---
        ---If more than one node has the node under cursor as its origin, a selection
        ---dialog is displayed to choose the node.
        goto_next_node = "<prefix>n",

        ---Goes to the previous node sequentially based on origin of the node under cursor.
        goto_prev_node = "<prefix>p",

        ---Inserts node at cursor position.
        insert_node = "<prefix>i",

        ---Inserts node at cursor position without opening capture buffer.
        insert_node_immediate = "<prefix>m",

        ---Opens the quickfix menu for backlinks to the current node under cursor.
        quickfix_backlinks = "<prefix>q",

        ---Removes an alias from the node under cursor.
        remove_alias = "<prefix>ar",

        ---Removes the origin from the node under cursor.
        remove_origin = "<prefix>or",

        ---Toggles the org-roam node-view buffer for the node under cursor.
        toggle_roam_buffer = "<prefix>l",

        ---Toggles a fixed org-roam node-view buffer for a selected node.
        toggle_roam_buffer_fixed = "<prefix>b",
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

    ---Settings tied to org-roam extensions.
    ---@class org-roam.config.Extensions
    extensions = {
        ---Settings tied to the dailies extension.
        ---@class org-roam.config.extensions.Dailies
        dailies = {
            ---Path to the directory within the org-roam directory where
            ---daily entries will be stored.
            ---@type string
            directory = "daily",

            ---Bindings associated with org-roam dailies functionality.
            ---@class org-roam.config.extensions.dailies.Bindings
            bindings = {
                ---Capture a specific date's note.
                capture_date = "<prefix>dD",

                ---Capture today's note.
                capture_today = "<prefix>dN",

                ---Capture tomorrow's note.
                capture_tomorrow = "<prefix>dT",

                ---Capture yesterday's note.
                capture_yesterday = "<prefix>dY",

                ---Navigate to dailies note directory.
                find_directory = "<prefix>d.",

                ---Navigate to specific date's note.
                goto_date = "<prefix>dd",

                ---Navigate to the next note in date sequence.
                goto_next_date = "<prefix>df",

                ---Navigate to the previous note in date sequence.
                goto_prev_date = "<prefix>db",

                ---Navigate to today's note.
                goto_today = "<prefix>dn",

                ---Navigate to tomorrow's note.
                goto_tomorrow = "<prefix>dt",

                ---Navigate to yesterday's note.
                goto_yesterday = "<prefix>dy",
            },

            ---Settings tied to org-roam dailies capture templates.
            ---@class org-roam.config.extensions.dailies.Templates
            ---@field [string] OrgCaptureTemplateOpts
            templates = {
                d = {
                    description = "default",
                    template = "%?",
                    target = "%<%Y-%m-%d>.org",
                },
            },

            ---Settings tied to org-roam dailies user interface.
            ---@class org-roam.config.extensions.dailies.UserInterface
            ui = {
                ---Settings tied to org-roam dailies calendar user interface.
                ---@class org-roam.config.extensions.dailies.ui.Calendar
                calendar = {
                    ---Highlight group to apply to a date that already has a note.
                    ---@type string
                    hl_date_exists = "WarningMsg",
                },
            },
        },
    },

    ---Additional org files to load. If an entry does not end on ".org" it assumes a directory and searches for org
    ---files recusrively.
    ---Supports globbing like org_agenda_files setting in orgmode
    ---@type string[]
    org_files = {
        -- ~/additonal_org_files,
        -- ~/a/single/org_file.org,
        -- ~/more/org/files/but/not/recusive/search/*.org
    },

    ---Settings tied to org-roam immediate mode.
    ---@class org-roam.config.Immediate
    immediate = {
        ---Target where the immediate-mode node should be written.
        ---@type string
        target = "%<%Y%m%d%H%M%S>-%[slug].org",

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
            target = "%<%Y%m%d%H%M%S>-%[slug].org",
        },
    },

    ---Settings tied to the user interface.
    ---@class org-roam.config.UserInterface
    ui = {
        ---Select-node dialog configuration settings.
        ---@class org-roam.config.ui.SelectNode
        select = {
            ---@alias org-roam.config.ui.SelectNodeItems (string|{label:string, value:any})[]
            ---
            ---Converts an org-roam node into one or more items to display in
            ---the select dialog. The function returns either a list of strings
            ---that will both populate the selection dialog AND be injected into
            ---buffers (e.g. for link descriptions), or returns a list of tables
            ---that contain both a `label` (string) and `value` (anything) where
            ---the label is displayed in the selection and the value is injected
            ---into buffers.
            ---
            ---By default, this will convert each node into its title and each
            ---individual alias.
            ---@type fun(node:org-roam.core.file.Node):org-roam.config.ui.SelectNodeItems
            node_to_items = function(node)
                ---@type string[]
                local items = {}
                table.insert(items, node.title)
                for _, alias in ipairs(node.aliases) do
                    -- Avoid duplicating the title if the alias is the same
                    if alias ~= node.title then
                        table.insert(items, alias)
                    end
                end
                return items
            end,
        },
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
