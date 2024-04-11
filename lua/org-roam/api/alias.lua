-------------------------------------------------------------------------------
-- ALIAS.LUA
--
-- Contains functionality tied to the roam alias api.
-------------------------------------------------------------------------------

local db = require("org-roam.database")
local notify = require("org-roam.core.ui.notify")
local Select = require("org-roam.core.ui.select")
local to_prop_list = require("org-roam.core.file.utils").parse_property_value
local utils = require("org-roam.utils")

local ID_PROP_NAME = "id"
local ALIASES_PROP_NAME = "roam_aliases"

local M = {}

---@param file OrgFile
---@param id string
---@return OrgFile|OrgHeadline|nil
local function find_id_match(file, id)
    if file:get_property(ID_PROP_NAME) == id then
        return file
    else
        -- Search through all headlines to see if we have a match
        for _, headline in ipairs(file:get_headlines()) do
            if headline:get_property(ID_PROP_NAME, false) == id then
                return headline
            end
        end

        -- Found nothing
        return
    end
end

---@param alias string
---@return string
local function wrap_alias(alias)
    local text = string.gsub(string.gsub(alias, "\\", "\\\\"), "\"", "\\\"")
    return text
end

---Adds an alias to the node under cursor.
---
---If no `alias` is specified, a prompt is provided.
---
---@param opts? {alias?:string}
function M.add_alias(opts)
    opts = opts or {}
    utils.node_under_cursor(function(node)
        if not node then return end

        db:load_file({ path = node.file }):next(function(results)
            -- Get the OrgFile instance
            local file = results.file

            -- Look for a file or headline that matches our node
            local entry = find_id_match(file, node.id)

            if entry then
                -- Get list of aliases that already exist
                local aliases = entry:get_property(ALIASES_PROP_NAME) or ""

                local alias = vim.trim(opts.alias or vim.fn.input({
                    prompt = "Node alias: ",
                }))

                -- Skip if not given a non-empty alias
                if alias == "" then
                    notify.echo_info("canceled adding alias")
                    return file
                end

                -- Escape double quotes and backslashes within alias as we're going to wrap it
                alias = wrap_alias(alias)

                -- Append our new alias to the end
                aliases = vim.trim(string.format("%s \"%s\"", aliases, alias))

                -- Update the entry
                entry:set_property(ALIASES_PROP_NAME, aliases)
            end

            return file
        end)
    end)
end

---Removes an alias from the node under cursor.
---
---If no `alias` is specified, selection dialog of aliases is provided.
---If `all` is true, will remove all aliases instead of one.
---
---@param opts? {alias?:string, all?:boolean}
function M.remove_alias(opts)
    opts = opts or {}
    utils.node_under_cursor(function(node)
        if not node then return end

        db:load_file({ path = node.file }):next(function(results)
            -- Get the OrgFile instance
            local file = results.file

            -- Look for a file or headline that matches our node
            local entry = find_id_match(file, node.id)

            if entry and opts.all then
                -- TODO: How do we fully remove?
                entry:set_property(ALIASES_PROP_NAME, "")
            elseif entry then
                local aliases = entry:get_property(ALIASES_PROP_NAME) or ""

                -- Open a selection dialog for the alias to remove
                Select:new({
                    auto_select = true,
                    init_input = opts.alias,
                    items = to_prop_list(aliases),
                }):on_cancel(function()
                    notify.echo_info("canceled removing alias")
                end):on_choice(function(alias)
                    -- Break up our alias into pieces, filter out the specified alias,
                    -- and then reconstruct back (wrapping in quotes) into aliases string
                    aliases = vim.trim(table.concat(vim.tbl_map(function(item)
                        return "\"" .. wrap_alias(item) .. "\""
                    end, vim.tbl_filter(function(item)
                        return item ~= "" and item ~= alias
                    end, to_prop_list(aliases))), " "))

                    -- Update the entry
                    if aliases == "" then
                        -- TODO: How do we fully remove?
                        entry:set_property(ALIASES_PROP_NAME, "")
                    else
                        entry:set_property(ALIASES_PROP_NAME, aliases)
                    end
                end)
            end

            return file
        end)
    end)
end

return M
