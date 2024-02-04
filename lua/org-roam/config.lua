-------------------------------------------------------------------------------
-- CONFIG.LUA
--
-- Location of configuration variables and functions.
-------------------------------------------------------------------------------

---@param value any
---@param default boolean
---@return boolean
local function bool_or(value, default)
    if type(value) == "boolean" then
        return value
    else
        return default
    end
end

---@param value any
---@param default string
---@return string
local function string_or(value, default)
    if type(value) == "string" then
        return value
    else
        return default
    end
end

---@class org-roam.config.Config
---
---@field org_roam_completion_everywhere org-roam.config.org_roam_completion_everywhere
---@field org_roam_dailies_capture_templates org-roam.config.org_roam_dailies_capture_templates
---@field org_roam_dailies_directory org-roam.config.org_roam_dailies_directory
---@field org_roam_db_extra_links_elements org-roam.config.org_roam_db_extra_links_elements
---@field org_roam_db_extra_links_exclude_keys org-roam.config.org_roam_db_extra_links_exclude_keys
---@field org_roam_db_update_on_save org-roam.config.org_roam_db_update_on_save
---@field org_roam_directory org-roam.config.org_roam_directory
---@field org_roam_graph_edge_extra_config org-roam.config.org_roam_graph_edge_extra_config
---@field org_roam_graph_executable org-roam.config.org_roam_graph_executable
---@field org_roam_graph_extra_config org-roam.config.org_roam_graph_extra_config
---@field org_roam_graph_filetype org-roam.config.org_roam_graph_filetype
---@field org_roam_graph_node_extra_config org-roam.config.org_roam_graph_node_extra_config
---@field org_roam_graph_viewer org-roam.config.org_roam_graph_viewer
---@field org_roam_node_display_template org-roam.config.org_roam_node_display_template
local M = {}
M.__index = M

---@class org-roam.config.Config.NewOpts
---
---@field org_roam_completion_everywhere? org-roam.config.org_roam_completion_everywhere
---@field org_roam_dailies_capture_templates? org-roam.config.org_roam_dailies_capture_templates
---@field org_roam_dailies_directory? org-roam.config.org_roam_dailies_directory
---@field org_roam_db_extra_links_elements? org-roam.config.org_roam_db_extra_links_elements
---@field org_roam_db_extra_links_exclude_keys? org-roam.config.org_roam_db_extra_links_exclude_keys
---@field org_roam_db_update_on_save? org-roam.config.org_roam_db_update_on_save
---@field org_roam_directory org-roam.config.org_roam_directory
---@field org_roam_graph_edge_extra_config? org-roam.config.org_roam_graph_edge_extra_config
---@field org_roam_graph_executable? org-roam.config.org_roam_graph_executable
---@field org_roam_graph_extra_config? org-roam.config.org_roam_graph_extra_config
---@field org_roam_graph_filetype? org-roam.config.org_roam_graph_filetype
---@field org_roam_graph_node_extra_config? org-roam.config.org_roam_graph_node_extra_config
---@field org_roam_graph_viewer? org-roam.config.org_roam_graph_viewer
---@field org_roam_node_display_template? org-roam.config.org_roam_node_display_template

---Creates a new instance of the configuration.
---
---The only required field is `org_roam_directory`, which specifies the
---directory where org-roam files will be stored and parsed.
---
---# List of settings and their default values
---
---* `org_roam_completion_everywhere`: *false*
---* `org_roam_dailies_capture_templates`: TODO
---* `org_roam_dailies_directory`: *daily*
---* `org_roam_db_extra_links_elements`: TODO
---* `org_roam_db_extra_links_exclude_keys`: TODO
---* `org_roam_db_update_on_save`: *true*
---* `org_roam_graph_edge_extra_config`: TODO
---* `org_roam_graph_executable`: TODO
---* `org_roam_graph_extra_config`: TODO
---* `org_roam_graph_filetype`: TODO
---* `org_roam_graph_node_extra_config`: TODO
---* `org_roam_graph_viewer`: TODO
---* `org_roam_node_display_template`: TODO
---
---@param opts org-roam.config.Config.NewOpts
---@return org-roam.config.Config
function M:new(opts)
    assert(type(opts) == "table", "options to config are required")

    local instance = {}
    setmetatable(instance, M)

    -- Set required configuration fields
    instance.org_roam_directory = opts.org_roam_directory

    -- Set optional configuration fields
    instance.org_roam_completion_everywhere = bool_or(opts.org_roam_completion_everywhere, false)
    instance.org_roam_dailies_capture_templates = opts.org_roam_dailies_capture_templates
    instance.org_roam_dailies_directory = string_or(opts.org_roam_dailies_directory, "dailies")
    instance.org_roam_db_extra_links_elements = opts.org_roam_db_extra_links_elements
    instance.org_roam_db_extra_links_exclude_keys = opts.org_roam_db_extra_links_exclude_keys
    instance.org_roam_db_update_on_save = bool_or(opts.org_roam_db_update_on_save, true)
    instance.org_roam_graph_edge_extra_config = opts.org_roam_graph_edge_extra_config
    instance.org_roam_graph_executable = opts.org_roam_graph_executable
    instance.org_roam_graph_extra_config = opts.org_roam_graph_extra_config
    instance.org_roam_graph_filetype = opts.org_roam_graph_filetype
    instance.org_roam_graph_node_extra_config = opts.org_roam_graph_node_extra_config
    instance.org_roam_graph_viewer = opts.org_roam_graph_viewer
    instance.org_roam_node_display_template = opts.org_roam_node_display_template

    return instance
end

---@type org-roam.config.Config
local GLOBAL_CONFIG = M:new({ org_roam_directory = "" })

---Retrieves the global configuration.
---@return org-roam.config.Config
function M:global()
    return GLOBAL_CONFIG
end

return M
