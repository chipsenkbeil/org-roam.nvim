-------------------------------------------------------------------------------
-- INSTANCE.LUA
--
-- Instance of a configuration.
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

---@param value any
---@param default table
---@return table
local function table_or(value, default)
    if type(value) == "table" then
        return value
    else
        return default
    end
end

---@generic T
---@param value any
---@param default T[]
---@return T[]
local function list_or(value, default)
    if type(value) == "table" and vim.tbl_islist(value) then
        return value
    else
        return default
    end
end

---@class org-roam.core.config.Config
---
---@field org_roam_completion_everywhere org-roam.core.config.org_roam_completion_everywhere
---@field org_roam_dailies_capture_templates org-roam.core.config.org_roam_dailies_capture_templates
---@field org_roam_dailies_directory org-roam.core.config.org_roam_dailies_directory
---@field org_roam_db_extra_links_elements org-roam.core.config.org_roam_db_extra_links_elements
---@field org_roam_db_extra_links_exclude_keys org-roam.core.config.org_roam_db_extra_links_exclude_keys
---@field org_roam_db_update_on_save org-roam.core.config.org_roam_db_update_on_save
---@field org_roam_directory org-roam.core.config.org_roam_directory
---@field org_roam_graph_edge_extra_config org-roam.core.config.org_roam_graph_edge_extra_config
---@field org_roam_graph_executable org-roam.core.config.org_roam_graph_executable
---@field org_roam_graph_extra_config org-roam.core.config.org_roam_graph_extra_config
---@field org_roam_graph_filetype org-roam.core.config.org_roam_graph_filetype
---@field org_roam_graph_node_extra_config org-roam.core.config.org_roam_graph_node_extra_config
---@field org_roam_graph_viewer org-roam.core.config.org_roam_graph_viewer
---@field org_roam_node_display_template org-roam.core.config.org_roam_node_display_template
local M = {}
M.__index = M

---@class org-roam.core.config.Config.NewOpts
---
---@field org_roam_completion_everywhere? org-roam.core.config.org_roam_completion_everywhere
---@field org_roam_dailies_capture_templates? org-roam.core.config.org_roam_dailies_capture_templates
---@field org_roam_dailies_directory? org-roam.core.config.org_roam_dailies_directory
---@field org_roam_db_extra_links_elements? org-roam.core.config.org_roam_db_extra_links_elements
---@field org_roam_db_extra_links_exclude_keys? org-roam.core.config.org_roam_db_extra_links_exclude_keys
---@field org_roam_db_update_on_save? org-roam.core.config.org_roam_db_update_on_save
---@field org_roam_directory org-roam.core.config.org_roam_directory
---@field org_roam_graph_edge_extra_config? org-roam.core.config.org_roam_graph_edge_extra_config
---@field org_roam_graph_executable? org-roam.core.config.org_roam_graph_executable
---@field org_roam_graph_extra_config? org-roam.core.config.org_roam_graph_extra_config
---@field org_roam_graph_filetype? org-roam.core.config.org_roam_graph_filetype
---@field org_roam_graph_node_extra_config? org-roam.core.config.org_roam_graph_node_extra_config
---@field org_roam_graph_viewer? org-roam.core.config.org_roam_graph_viewer
---@field org_roam_node_display_template? org-roam.core.config.org_roam_node_display_template

---Creates a new instance of the configuration.
---
---The only required field is `org_roam_directory`, which specifies the
---directory where org-roam files will be stored and parsed.
---
---# List of settings and their default values
---
---* `org_roam_completion_everywhere`:          *false*
---* `org_roam_dailies_capture_templates`:      `{d = {
---                                             description = "default",
---                                             template = "* %?",
---                                             target = "%<%Y-%m-%d>.org",
---                                             }}`
---* `org_roam_dailies_directory`:              *"daily"*
---* `org_roam_db_extra_links_elements`:        *{}*
---* `org_roam_db_extra_links_exclude_keys`:    *{}*
---* `org_roam_db_update_on_save`:              *true*
---* `org_roam_graph_edge_extra_config`:        *""*
---* `org_roam_graph_executable`:               *"dot"*
---* `org_roam_graph_extra_config`:             *""*
---* `org_roam_graph_filetype`:                 *"svg"*
---* `org_roam_graph_node_extra_config`:        *""*
---* `org_roam_graph_viewer`:                   *"firefox"*
---* `org_roam_node_display_template`:          *"${title}"*
---
---@param opts org-roam.core.config.Config.NewOpts
---@return org-roam.core.config.Config
function M:new(opts)
    assert(type(opts) == "table", "options to config are required")

    local instance = {}
    setmetatable(instance, M)

    ---@generic T
    ---@param name string
    ---@param f fun(value:any, default:T):T
    ---@param default T
    local function set_field(name, f, default)
        instance[name] = f(opts[name], default)
    end

    -- Set required configuration fields
    set_field("org_roam_directory", string_or, "")

    -- Set optional configuration fields
    set_field("org_roam_completion_everywhere", bool_or, false)
    set_field("org_roam_dailies_capture_templates", table_or, {
        -- TODO: org-roam uses :target (
        --       file+head "%<%Y-%m-%d>.org" "#+title: %<%Y-%m-%d>\n")
        --
        --       I don't presently see how to handle `file+head` or the title
        --       portion, which would get injected once when creating the file,
        --       can work.
        d = {
            description = "default",
            template = "* %?",
            target = "%<%Y-%m-%d>.org",
        }
    })
    set_field("org_roam_dailies_directory", string_or, "dailies")
    set_field("org_roam_db_extra_links_elements", list_or, {})
    set_field("org_roam_db_extra_links_exclude_keys", list_or, {})
    set_field("org_roam_db_update_on_save", bool_or, true)
    set_field("org_roam_graph_edge_extra_config", string_or, "")
    set_field("org_roam_graph_executable", string_or, "dot")
    set_field("org_roam_graph_extra_config", string_or, "")
    set_field("org_roam_graph_filetype", string_or, "svg")
    set_field("org_roam_graph_node_extra_config", string_or, "")
    set_field("org_roam_graph_viewer", string_or, "firefox")
    set_field("org_roam_node_display_template", string_or, "${title}")

    return instance
end

---@class org-roam.core.config.Config.MergeOpts
---
---@field org_roam_completion_everywhere? org-roam.core.config.org_roam_completion_everywhere
---@field org_roam_dailies_capture_templates? org-roam.core.config.org_roam_dailies_capture_templates
---@field org_roam_dailies_directory? org-roam.core.config.org_roam_dailies_directory
---@field org_roam_db_extra_links_elements? org-roam.core.config.org_roam_db_extra_links_elements
---@field org_roam_db_extra_links_exclude_keys? org-roam.core.config.org_roam_db_extra_links_exclude_keys
---@field org_roam_db_update_on_save? org-roam.core.config.org_roam_db_update_on_save
---@field org_roam_directory? org-roam.core.config.org_roam_directory
---@field org_roam_graph_edge_extra_config? org-roam.core.config.org_roam_graph_edge_extra_config
---@field org_roam_graph_executable? org-roam.core.config.org_roam_graph_executable
---@field org_roam_graph_extra_config? org-roam.core.config.org_roam_graph_extra_config
---@field org_roam_graph_filetype? org-roam.core.config.org_roam_graph_filetype
---@field org_roam_graph_node_extra_config? org-roam.core.config.org_roam_graph_node_extra_config
---@field org_roam_graph_viewer? org-roam.core.config.org_roam_graph_viewer
---@field org_roam_node_display_template? org-roam.core.config.org_roam_node_display_template

---Merges the provided options into this config, overwriting its current values.
---@param opts org-roam.core.config.Config.MergeOpts
function M:merge(opts)
    ---@generic T
    ---@param name string
    ---@param f fun(value:any, default:T):T
    local function set_field(name, f)
        self[name] = f(opts[name], self[name])
    end

    set_field("org_roam_completion_everywhere", bool_or)
    set_field("org_roam_dailies_capture_templates", table_or)
    set_field("org_roam_dailies_directory", string_or)
    set_field("org_roam_db_extra_links_elements", list_or)
    set_field("org_roam_db_extra_links_exclude_keys", list_or)
    set_field("org_roam_db_update_on_save", bool_or)
    set_field("org_roam_directory", string_or)
    set_field("org_roam_graph_edge_extra_config", string_or)
    set_field("org_roam_graph_executable", string_or)
    set_field("org_roam_graph_extra_config", string_or)
    set_field("org_roam_graph_filetype", string_or)
    set_field("org_roam_graph_node_extra_config", string_or)
    set_field("org_roam_graph_viewer", string_or)
    set_field("org_roam_node_display_template", string_or)
end

return M
