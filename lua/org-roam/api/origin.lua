-------------------------------------------------------------------------------
-- ORIGIN.LUA
--
-- Contains functionality tied to the roam origin api.
-------------------------------------------------------------------------------

local ORIGIN_PROP_NAME = "ROAM_ORIGIN"

---Writes the list of origin ids as a space-separated property value.
---If the list is empty, removes the property entirely.
---@param entry OrgFile|OrgHeadline
---@param origins string[]
local function write_origins(entry, origins)
    if #origins == 0 then
        entry:set_property(ORIGIN_PROP_NAME, nil)
    else
        entry:set_property(ORIGIN_PROP_NAME, table.concat(origins, " "))
    end
end

---@param roam OrgRoam
---@param opts? {origin?:string}
---@return OrgPromise<boolean>
local function roam_add_origin(roam, opts)
    opts = opts or {}
    return require("orgmode.utils.promise").new(function(resolve)
        local utils = require("org-roam.utils")

        utils.node_under_cursor(function(node)
            if not node then
                return resolve(false)
            end

            roam.database
                :load_file({ path = node.file })
                :next(function(results)
                    -- Get the OrgFile instance
                    local file = results.file

                    -- Look for a file or headline that matches our node
                    local entry = utils.find_id_match(file, node.id)

                    if entry and opts.origin then
                        -- Append to existing origins, avoiding duplicates
                        local origins = vim.deepcopy(node.origin)
                        if not vim.tbl_contains(origins, opts.origin) then
                            table.insert(origins, opts.origin)
                        end
                        write_origins(entry, origins)
                        resolve(true)
                    elseif entry then
                        -- If no origin specified, we load up a selection dialog
                        -- to pick a node other than the current one
                        local exclude = vim.list_extend({ node.id }, node.origin)
                        roam.ui
                            .select_node({ exclude = exclude })
                            :on_choice(function(choice)
                                local origins = vim.deepcopy(node.origin)
                                if not vim.tbl_contains(origins, choice.id) then
                                    table.insert(origins, choice.id)
                                end
                                write_origins(entry, origins)
                                resolve(true)
                            end)
                            :on_cancel(function()
                                resolve(false)
                            end)
                            :open()
                    else
                        resolve(false)
                    end

                    return file
                end)
                :catch(function()
                    resolve(false)
                end)
        end)
    end)
end

---@param roam OrgRoam
---@param opts? {win?:integer}
---@return OrgPromise<string|nil>
local function roam_goto_prev_node(roam, opts)
    opts = opts or {}
    local winnr = opts.win or vim.api.nvim_get_current_win()

    return require("orgmode.utils.promise").new(function(resolve)
        local utils = require("org-roam.utils")

        ---@param node org-roam.core.file.Node|nil
        local function goto_node(node)
            if not node then
                return resolve(nil)
            end
            utils.goto_node({ node = node, win = winnr })
            resolve(node.id)
        end

        utils.node_under_cursor(function(node)
            if not node or #node.origin == 0 then
                return resolve(nil)
            end

            -- If only one origin, go directly
            if #node.origin == 1 then
                roam.database:get(node.origin[1]):next(goto_node):catch(function()
                    resolve(nil)
                end)
                return
            end

            -- Multiple origins: show selection dialog
            roam.ui
                .select_node({ include = node.origin })
                :on_choice(function(choice)
                    roam.database:get(choice.id):next(goto_node):catch(function()
                        resolve(nil)
                    end)
                end)
                :on_cancel(function()
                    resolve(nil)
                end)
                :open()
        end, { win = winnr })
    end)
end

---@param roam OrgRoam
---@param opts? {win?:integer}
---@return OrgPromise<string|nil>
local function roam_goto_next_node(roam, opts)
    opts = opts or {}
    local winnr = opts.win or vim.api.nvim_get_current_win()

    return require("orgmode.utils.promise").new(function(resolve)
        local utils = require("org-roam.utils")

        ---@param node org-roam.core.file.Node|nil
        local function goto_node(node)
            if not node then
                return resolve(nil)
            end
            utils.goto_node({ node = node, win = winnr })
            resolve(node.id)
        end

        utils.node_under_cursor(function(node)
            if not node then
                return resolve(nil)
            end
            roam.database:find_nodes_by_origin(node.id):next(function(nodes)
                if #nodes == 0 then
                    resolve(nil)
                    return nodes
                end
                if #nodes == 1 then
                    goto_node(nodes[1])
                    return nodes
                end

                local ids = vim.tbl_map(function(n)
                    return n.id
                end, nodes)

                roam.ui
                    .select_node({ include = ids })
                    :on_choice(function(choice)
                        roam.database:get(choice.id):next(goto_node):catch(function()
                            resolve(nil)
                        end)
                    end)
                    :on_cancel(function()
                        resolve(nil)
                    end)
                    :open()

                return nodes
            end)
        end, { win = winnr })
    end)
end

---@param roam OrgRoam
---@return OrgPromise<boolean>
local function roam_remove_origin(roam)
    return require("orgmode.utils.promise").new(function(resolve)
        local utils = require("org-roam.utils")

        utils.node_under_cursor(function(node)
            if not node then
                return resolve(false)
            end

            if #node.origin == 0 then
                return resolve(false)
            end

            ---@param origin_to_remove string
            local function do_remove(origin_to_remove)
                roam.database
                    :load_file({ path = node.file })
                    :next(function(results)
                        local file = results.file
                        local entry = utils.find_id_match(file, node.id)

                        if entry then
                            local origins = vim.tbl_filter(function(o)
                                return o ~= origin_to_remove
                            end, node.origin)
                            write_origins(entry, origins)
                            resolve(true)
                        else
                            resolve(false)
                        end

                        return file
                    end)
                    :catch(function()
                        resolve(false)
                    end)
            end

            -- If only one origin, remove it directly
            if #node.origin == 1 then
                do_remove(node.origin[1])
                return
            end

            -- Multiple origins: show selection dialog to pick which to remove
            roam.ui
                .select_node({ include = node.origin })
                :on_choice(function(choice)
                    do_remove(choice.id)
                end)
                :on_cancel(function()
                    resolve(false)
                end)
                :open()
        end)
    end)
end

---@param roam OrgRoam
---@return org-roam.api.OriginApi
return function(roam)
    ---@class org-roam.api.OriginApi
    local M = {}

    ---Adds an origin to the node under cursor.
    ---Appends to existing origins (supports multiple origins).
    ---
    ---If no `origin` is specified, a prompt is provided.
    ---
    ---@param opts? {origin?:string}
    ---@return OrgPromise<boolean>
    function M.add_origin(opts)
        return roam_add_origin(roam, opts)
    end

    ---Goes to the previous node in sequence for the node under cursor.
    ---Leverages a lookup of the node using the origin of the node under cursor.
    ---@param opts? {win?:integer}
    ---@return OrgPromise<boolean>
    function M.goto_prev_node(opts)
        return roam_goto_prev_node(roam, opts)
    end

    ---Goes to the next node in sequence for the node under cursor.
    ---Leverages a lookup of nodes whose origin match the node under cursor.
    ---@param opts? {win?:integer}
    ---@return OrgPromise<boolean>
    function M.goto_next_node(opts)
        return roam_goto_next_node(roam, opts)
    end

    ---Removes the origin from the node under cursor.
    ---@return OrgPromise<boolean>
    function M.remove_origin()
        return roam_remove_origin(roam)
    end

    return M
end
