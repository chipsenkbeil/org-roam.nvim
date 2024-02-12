-------------------------------------------------------------------------------
-- SCANNER.LUA
--
-- Logic to scan for org files, parse them, translate into nodes, and insert
-- into a database.
-------------------------------------------------------------------------------

local Node = require("org-roam.core.database.node")
local parser = require("org-roam.core.parser")
local utils = require("org-roam.core.utils")

---@class org-roam.core.scanner
local M = {}

---Scans the provided `path` for org files, parses them, and derives roam nodes.
---
---The `cb` is invoked once per derived node, or when an error is encountered.
---
---Once scanning is finished, the `cb` is invoked one final time with no arguments.
---@param path string
---@param cb fun(err:string|nil, node:org-roam.core.database.Node|nil)
function M.scan(path, cb)
    local it = utils.io.walk(path, { depth = math.huge })
        :filter(function(entry) return entry.type == "file" end)
        :filter(function(entry) return vim.endswith(entry.filename, ".org") end)

    local function do_parse()
        if it:has_next() then
            ---@type org-roam.core.utils.io.WalkEntry
            local entry = it:next()

            parser.parse_file(entry.path, function(err, file)
                if err then
                    cb(err)
                elseif file then
                    local file_node
                    ---@type {[1]: org-roam.core.parser.Range, [2]: org-roam.core.database.Node}[]
                    local section_nodes = {}

                    -- First, find the top-level property drawer
                    for _, drawer in ipairs(file.drawers) do
                        local id = drawer:find("id", { case_insensitive = true })

                        if id then
                            local aliases_text = drawer:find("ROAM_ALIASES", {
                                case_insensitive = true,
                            })

                            local aliases = aliases_text
                                and utils.parser.parse_property_value(aliases_text)
                                or {}

                            file_node = Node:new({
                                range = nil,
                                id = id,
                                file = entry.path,
                                title = file.title,
                                aliases = aliases,
                                tags = vim.deepcopy(file.filetags),
                                level = 0,
                                linked = {},
                            })

                            -- There should only be one top-level node
                            break
                        end
                    end

                    -- Second, for each section, check if it has a node
                    for _, section in ipairs(file.sections) do
                        local id = section.property_drawer:find("id", {
                            case_insensitive = true,
                        })

                        if id then
                            local heading = section.heading
                            local aliases_text = section.property_drawer:find("ROAM_ALIASES", {
                                case_insensitive = true,
                            })

                            local aliases = aliases_text
                                and utils.parser.parse_property_value(aliases_text)
                                or {}

                            local title = heading.item and vim.trim(heading.item:text()) or nil

                            table.insert(section_nodes, {
                                section.range,
                                Node:new({
                                    id = id,
                                    file = entry.path,
                                    title = title,
                                    aliases = aliases,
                                    tags = vim.deepcopy(file.filetags),
                                    level = heading.stars,
                                    linked = {},
                                })
                            })
                        end
                    end

                    -- Figure out which node contains the link
                    -- TODO: We are doing a naive scan here, so performance
                    --       is going to suck. We should revisit to make
                    --       this better down the line. Maybe sort by
                    --       range size.
                    for _, link in ipairs(file.links) do
                        local link_path = vim.trim(link.path)
                        local link_id = string.match(link_path, "^id:(.+)$")

                        -- For now, we only consider links that are
                        -- standard org id links, nothing else. This
                        -- differs from org-roam in Emacs, where they
                        -- cache all links and use the non-id links
                        -- externally.
                        if link_id then
                            -- Look through ALL of our section nodes to find
                            -- the closest based on size. If none contain,
                            -- then use the file node.
                            local size = math.huge
                            local target_node
                            for _, tbl in ipairs(section_nodes) do
                                local range = tbl[1]
                                local node = tbl[2]
                                if range:size() < size and range:contains(link.range) then
                                    size = range:size()
                                    target_node = node
                                end
                            end

                            if not target_node then
                                target_node = file_node
                            end

                            if target_node then
                                table.insert(target_node.linked, link_id)
                            end
                        end
                    end

                    if file_node then
                        vim.schedule(function() cb(nil, file_node) end)
                    end

                    for _, tbl in ipairs(section_nodes) do
                        local node = tbl[2]
                        vim.schedule(function() cb(nil, node) end)
                    end
                end

                -- Repeat by scheduling to parse the next file
                vim.schedule(do_parse)
            end)

            -- Exit so we wait for next scheduled parse
            return
        end

        -- We're done, so execute one last time
        cb(nil, nil)
    end

    do_parse()
end

return M
