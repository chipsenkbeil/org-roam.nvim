-------------------------------------------------------------------------------
-- ALIAS.LUA
--
-- Contains functionality tied to the roam alias api.
-------------------------------------------------------------------------------

local db = require("org-roam.database")
local notify = require("org-roam.core.ui.notify")
local Select = require("org-roam.core.ui.select")
local utils = require("org-roam.utils")

local ALIASES_PROP_NAME = "ROAM_ALIASES"

local M = {}

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
            local entry = utils.find_id_match(file, node.id)

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
                alias = utils.wrap_prop_value(alias)

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
            local entry = utils.find_id_match(file, node.id)

            if entry and opts.all then
                -- TODO: How do we fully remove?
                entry:set_property(ALIASES_PROP_NAME, "")
            elseif entry then
                local aliases = entry:get_property(ALIASES_PROP_NAME) or ""

                local function on_cancel()
                    notify.echo_info("canceled removing alias")
                end

                ---@param alias string
                local function on_choice(alias)
                    local remaining = vim.tbl_filter(function(item)
                        return item ~= "" and item ~= alias
                    end, utils.parse_prop_value(aliases))

                    -- Break up our alias into pieces, filter out the specified alias,
                    -- and then reconstruct back (wrapping in quotes) into aliases string
                    aliases = vim.trim(table.concat(vim.tbl_map(function(item)
                        return "\"" .. utils.wrap_prop_value(item) .. "\""
                    end, remaining), " "))

                    -- Update the entry
                    if aliases == "" then
                        -- TODO: How do we fully remove?
                        entry:set_property(ALIASES_PROP_NAME, "")
                    else
                        entry:set_property(ALIASES_PROP_NAME, aliases)
                    end
                end

                -- Open a selection dialog for the alias to remove
                Select:new({
                    auto_select = true,
                    init_input = opts.alias,
                    items = utils.parse_prop_value(aliases),
                })
                    :on_cancel(on_cancel)
                    :on_choice(on_choice)
                    :open()
            end

            return file
        end)
    end)
end

return M
