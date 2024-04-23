-------------------------------------------------------------------------------
-- ALIAS.LUA
--
-- Contains functionality tied to the roam alias api.
-------------------------------------------------------------------------------

local notify = require("org-roam.core.ui.notify")
local Select = require("org-roam.core.ui.select")
local Promise = require("orgmode.utils.promise")
local utils = require("org-roam.utils")

local ALIASES_PROP_NAME = "ROAM_ALIASES"

---@param roam OrgRoam
---@param opts? {alias?:string, win?:integer}
---@return OrgPromise<boolean>
local function roam_add_alias(roam, opts)
    opts = opts or {}

    return Promise.new(function(resolve, reject)
        utils.node_under_cursor(function(node)
            -- Mark unsuccessful and exit
            if not node then return resolve(false) end

            roam.database:load_file({ path = node.file }):next(function(results)
                -- Get the OrgFile instance
                local file = results.file

                -- Look for a file or headline that matches our node
                local entry = utils.find_id_match(file, node.id)

                if entry then
                    -- Get list of aliases that already exist
                    local aliases = entry:get_property(ALIASES_PROP_NAME) or ""

                    local alias = vim.trim(opts.alias or vim.fn.input({
                        prompt = "Alias: ",
                    }))

                    -- Skip if not given a non-empty alias
                    if alias == "" then
                        notify.echo_info("canceled adding alias")

                        -- Mark unsuccessful
                        resolve(false)

                        return file
                    end

                    -- Escape double quotes and backslashes within alias as
                    -- we're going to wrap it
                    alias = utils.wrap_prop_value(alias)

                    -- Append our new alias to the end
                    aliases = vim.trim(string.format("%s \"%s\"", aliases, alias))

                    -- Update the entry
                    entry:set_property(ALIASES_PROP_NAME, aliases)

                    -- Mark successful
                    resolve(true)
                else
                    -- Mark unsuccessful
                    resolve(false)
                end

                return file
            end):catch(reject)
        end, { win = opts.win })
    end)
end

---@param roam OrgRoam
---@param opts? {alias?:string, all?:boolean, win?:integer}
---@return OrgPromise<boolean>
local function roam_remove_alias(roam, opts)
    opts = opts or {}
    return Promise.new(function(resolve, reject)
        utils.node_under_cursor(function(node)
            -- Mark unsuccessful and exit
            if not node then return resolve(false) end

            roam.database:load_file({ path = node.file }):next(function(results)
                -- Get the OrgFile instance
                local file = results.file

                -- Look for a file or headline that matches our node
                local entry = utils.find_id_match(file, node.id)

                if entry and opts.all then
                    entry:set_property(ALIASES_PROP_NAME, nil)

                    -- Mark successful
                    resolve(true)
                elseif entry then
                    local aliases = entry:get_property(ALIASES_PROP_NAME) or ""

                    -- If we have nothing to remove, exit successfully
                    if vim.trim(aliases) == "" then
                        resolve(true)
                        return file
                    end

                    local function on_cancel()
                        notify.echo_info("canceled removing alias")

                        -- Mark unsuccessful
                        resolve(false)
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
                            entry:set_property(ALIASES_PROP_NAME, nil)
                        else
                            entry:set_property(ALIASES_PROP_NAME, aliases)
                        end

                        -- Mark successful
                        resolve(true)
                    end

                    -- Build our prompt, updating it to a left-hand side
                    -- style if we have neovim 0.10+ which supports inlining
                    local prompt = "(alias {sel}/{cnt})"
                    if vim.fn.has("nvim-0.10") == 1 then
                        prompt = "{sel}/{cnt} alias> "
                    end

                    -- Open a selection dialog for the alias to remove
                    Select:new({
                        auto_select = true,
                        init_input = opts.alias,
                        items = utils.parse_prop_value(aliases),
                        prompt = prompt,
                    })
                        :on_cancel(on_cancel)
                        :on_choice(on_choice)
                        :open()
                else
                    -- Mark unsuccessful
                    resolve(false)
                end

                return file
            end):catch(reject)
        end, { win = opts.win })
    end)
end

---@param roam OrgRoam
---@return org-roam.api.AliasApi
return function(roam)
    ---@class org-roam.api.AliasApi
    local M = {}

    ---Adds an alias to the node under cursor.
    ---
    ---If no `alias` is specified, a prompt is provided.
    ---
    ---Returns a promise indicating whether or not the alias was added.
    ---
    ---@param opts? {alias?:string, win?:integer}
    ---@return OrgPromise<boolean>
    function M.add_alias(opts)
        return roam_add_alias(roam, opts)
    end

    ---Removes an alias from the node under cursor.
    ---
    ---If no `alias` is specified, selection dialog of aliases is provided.
    ---If `all` is true, will remove all aliases instead of one.
    ---
    ---Returns a promise indicating whether or not the alias(es) was/were removed.
    ---
    ---@param opts? {alias?:string, all?:boolean, win?:integer}
    ---@return OrgPromise<boolean>
    function M.remove_alias(opts)
        return roam_remove_alias(roam, opts)
    end

    return M
end
