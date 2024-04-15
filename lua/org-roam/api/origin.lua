-------------------------------------------------------------------------------
-- ORIGIN.LUA
--
-- Contains functionality tied to the roam origin api.
-------------------------------------------------------------------------------

local db = require("org-roam.database")
local select_node = require("org-roam.ui.select-node")
local Promise = require("orgmode.utils.promise")
local utils = require("org-roam.utils")

local ORIGIN_PROP_NAME = "ROAM_ORIGIN"

local M = {}

---Adds an origin to the node under cursor.
---Will replace the existing origin.
---
---If no `origin` is specified, a prompt is provided.
---
---@param opts? {origin?:string}
---@return OrgPromise<boolean>
function M.add_origin(opts)
    opts = opts or {}
    return Promise.new(function(resolve)
        utils.node_under_cursor(function(node)
            if not node then return resolve(false) end

            db:load_file({ path = node.file }):next(function(results)
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
                    select_node({ exclude = { node.id } }, function(selection)
                        if selection.id then
                            entry:set_property(ORIGIN_PROP_NAME, selection.id)
                            resolve(true)
                        else
                            resolve(false)
                        end
                    end, function()
                        resolve(false)
                    end)
                else
                    resolve(false)
                end

                return file
            end):catch(function() resolve(false) end)
        end)
    end)
end

---Goes to the previous node in sequence for the node under cursor.
---Leverages a lookup of the node using the origin of the node under cursor.
---@param opts? {win?:integer}
---@return OrgPromise<boolean>
function M.goto_prev_node(opts)
    opts = opts or {}
    local winnr = opts.win or vim.api.nvim_get_current_win()

    return Promise.new(function(resolve)
        ---@param node org-roam.core.file.Node|nil
        local function goto_node(node)
            if not node then return resolve(false) end
            utils.goto_node({ node = node, win = winnr })
            resolve(true)
        end

        utils.node_under_cursor(function(node)
            if not node or not node.origin then return resolve(false) end
            db:get(node.origin)
                :next(goto_node)
                :catch(function() resolve(false) end)
        end, { win = winnr })
    end)
end

---Goes to the next node in sequence for the node under cursor.
---Leverages a lookup of nodes whose origin match the node under cursor.
---@param opts? {win?:integer}
---@return OrgPromise<boolean>
function M.goto_next_node(opts)
    opts = opts or {}
    local winnr = opts.win or vim.api.nvim_get_current_win()

    return Promise.new(function(resolve)
        ---@param node org-roam.core.file.Node|nil
        local function goto_node(node)
            if not node then return resolve(false) end
            utils.goto_node({ node = node, win = winnr })
            resolve(true)
        end

        utils.node_under_cursor(function(node)
            if not node then return resolve(false) end
            db:find_nodes_by_origin(node.id):next(function(nodes)
                if #nodes == 0 then
                    resolve(false)
                    return nodes
                end
                if #nodes == 1 then
                    goto_node(nodes[1])
                    return nodes
                end

                local ids = vim.tbl_map(function(n)
                    return n.id
                end, nodes)

                select_node({ include = ids }, function(selection)
                    if selection.id then
                        db:get(selection.id)
                            :next(goto_node)
                            :catch(function() resolve(false) end)
                    else
                        resolve(false)
                    end
                end, function()
                    resolve(false)
                end)

                return nodes
            end)
        end, { win = winnr })
    end)
end

---Removes the origin from the node under cursor.
---@return OrgPromise<boolean>
function M.remove_origin()
    return Promise.new(function(resolve)
        utils.node_under_cursor(function(node)
            if not node then return resolve(false) end

            db:load_file({ path = node.file }):next(function(results)
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
            end):catch(function() resolve(false) end)
        end)
    end)
end

return M
