-------------------------------------------------------------------------------
-- ORIGIN.LUA
--
-- Contains functionality tied to the roam origin api.
-------------------------------------------------------------------------------

local ORIGIN_PROP_NAME = "ROAM_ORIGIN"

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
                        entry:set_property(ORIGIN_PROP_NAME, opts.origin)
                        resolve(true)
                    elseif entry then
                        -- If no origin specified, we load up a selection dialog
                        -- to pick a node other than the current one
                        roam.ui
                            .select_node({ exclude = { node.id } })
                            :on_choice(function(choice)
                                entry:set_property(ORIGIN_PROP_NAME, choice.id)
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
            if not node or not node.origin then
                return resolve(nil)
            end
            roam.database:get(node.origin):next(goto_node):catch(function()
                resolve(nil)
            end)
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

            roam.database
                :load_file({ path = node.file })
                :next(function(results)
                    -- Get the OrgFile instance
                    local file = results.file

                    -- Look for a file or headline that matches our node
                    local entry = utils.find_id_match(file, node.id)

                    if entry then
                        entry:set_property(ORIGIN_PROP_NAME, nil)
                        resolve(true)
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
---@return org-roam.api.OriginApi
return function(roam)
    ---@class org-roam.api.OriginApi
    local M = {}

    ---Adds an origin to the node under cursor.
    ---Will replace the existing origin.
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
