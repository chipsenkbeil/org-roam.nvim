-------------------------------------------------------------------------------
-- CONFIG.LUA
--
-- Contains global config logic used by the plugin.
-------------------------------------------------------------------------------

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
        ---Completes the node under cursor.
        complete_at_point = "<C-c><C-c>",

        ---Prints the node under cursor.
        print_node = "<C-c>np",

        ---Opens the quickfix menu for backlinks to the current node under cursor.
        quickfix_backlinks = "<C-c>nq",

        ---Toggles the org-roam node-view buffer for the node under cursor.
        toggle_roam_buffer = "<C-c>nl",

        ---Toggles a fixed org-roam node-view buffer for a selected node.
        toggle_roam_buffer_fixed = "<C-c>nn",
    },
}, { __call = replace })

return config
