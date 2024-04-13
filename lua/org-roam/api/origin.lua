-------------------------------------------------------------------------------
-- ORIGIN.LUA
--
-- Contains functionality tied to the roam origin api.
-------------------------------------------------------------------------------

local db = require("org-roam.database")
local notify = require("org-roam.core.ui.notify")
local select_node = require("org-roam.ui.select-node")
local utils = require("org-roam.utils")

local ORIGIN_PROP_NAME = "ROAM_ORIGIN"

local M = {}

---Adds an origin to the node under cursor.
---Will replace the existing origin.
---
---If no `origin` is specified, a prompt is provided.
---
---@param opts? {origin?:string}
function M.add_origin(opts)
    opts = opts or {}
    utils.node_under_cursor(function(node)
        if not node then return end

        db:load_file({ path = node.file }):next(function(results)
            -- Get the OrgFile instance
            local file = results.file

            -- Look for a file or headline that matches our node
            local entry = utils.find_id_match(file, node.id)

            if entry and opts.origin then
                entry:set_property(ORIGIN_PROP_NAME, opts.origin)
            elseif entry then
                select_node(function(selection)
                    if selection.id then
                        entry:set_property(ORIGIN_PROP_NAME, selection.id)
                    end
                end)
            end

            return file
        end)
    end)
end

---Removes the origin from the node under cursor.
function M.remove_origin()
    utils.node_under_cursor(function(node)
        if not node then return end

        db:load_file({ path = node.file }):next(function(results)
            -- Get the OrgFile instance
            local file = results.file

            -- Look for a file or headline that matches our node
            local entry = utils.find_id_match(file, node.id)

            if entry then
                entry:set_property(ORIGIN_PROP_NAME, nil)
            end

            return file
        end)
    end)
end

return M
