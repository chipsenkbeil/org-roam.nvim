-------------------------------------------------------------------------------
-- SCANNER.LUA
--
-- Logic to scan for org files, parse them, translate into nodes, and insert
-- into a database.
-------------------------------------------------------------------------------

local Node   = require("org-roam.core.database.node")
local parser = require("org-roam.core.parser")
local utils  = require("org-roam.core.utils")

local uv     = vim.loop

---@class org-roam.core.Scanner
local M      = {}
M.__index    = M

---Creates a new instance of the scanner.
---@param opts? {watch?:boolean}
---@return org-roam.core.Scanner
function M:new(opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)

    return instance
end

---Register callback to be invoked when a node is updated.
---@param f fun()
function M:on_update(f)
end

---Scans the provided `path` for org files, parses them, and derives roam nodes.
---
---The `cb` is invoked once per file, or when an error is encountered.
---
---Once scanning is finished, the `cb` is invoked one final time with no arguments.
---@param path string
---@param cb fun(err:string|nil, nodes:org-roam.core.database.Node[]|nil)
function M:scan()
    error("todo")
end

---@private
---@param path string
---@param cb fun(err:string|nil, results:{entry:org-roam.core.utils.io.WalkEntry, nodes:org-roam.core.database.Node[]}|nil)
function M:__scan_dir(path, cb)
    local it = utils.io.walk(path, { depth = math.huge })
        :filter(function(entry) return entry.type == "file" end)
        :filter(function(entry) return vim.endswith(entry.filename, ".org") end)

    local function do_parse()
        if it:has_next() then
            ---@type org-roam.core.utils.io.WalkEntry
            local entry = it:next()

            self:__scan_file(entry.path, function(err, nodes)
                if err then
                    cb(err)
                    return
                end

                vim.schedule(function()
                    ---@cast nodes -nil
                    cb(nil, { entry = entry, nodes = nodes })
                end)

                vim.schedule(do_parse)
            end)

            -- Exit so we wait for next scheduled parse
            return
        end
    end

    do_parse()
end

---@private
---@param path string
---@param cb fun(err:string|nil, nodes:org-roam.core.database.Node[]|nil)
function M:__scan_file(path, cb)
    parser.parse_file(path, function(err, file)
        if err then
            cb(err)
            return
        end

        assert(file, "impossible: successful parse_file did not yield file")

        ---@type org-roam.core.database.Node|nil
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
                    file = path,
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

                -- Build up tags for the heading, which is a combination of
                -- the file tags, any tags from ancestor headings, and
                -- then this heading
                local tags = vim.deepcopy(file.filetags)

                for _, tag in ipairs(heading:tag_list()) do
                    table.insert(tags, tag)
                end

                table.insert(section_nodes, {
                    section.range,
                    Node:new({
                        id = id,
                        file = path,
                        title = title,
                        aliases = aliases,
                        tags = tags,
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

        ---@type org-roam.core.database.Node
        local nodes = {}
        if file_node then
            table.insert(nodes, file_node)
        end

        for _, tbl in ipairs(section_nodes) do
            table.insert(nodes, tbl[2])
        end

        cb(nil, nodes)
    end)
end

return M
