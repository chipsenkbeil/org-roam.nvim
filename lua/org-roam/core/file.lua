-------------------------------------------------------------------------------
-- FILE.LUA
--
-- Represents an org-roam file, containing the associated nodes and other data.
-------------------------------------------------------------------------------

-- Cannot serialie `math.huge`. Potentially could use `vim.v.numbermax`, but
-- this is a safer and more reliable guarantee of maximum size.
local MAX_NUMBER = 2 ^ 31

local KEYS = {
    DIR_TITLE = "TITLE",
    PROP_ALIASES = "ROAM_ALIASES",
    PROP_ID = "ID",
    PROP_ORIGIN = "ROAM_ORIGIN",
}

---@class org-roam.core.File
---@field filename string
---@field links org-roam.core.file.Link[]
---@field nodes table<string, org-roam.core.file.Node>
local M = {}
M.__index = M

---Creates a new org-roam file.
---@param opts {filename:string, links?:org-roam.core.file.Link[], nodes?:org-roam.core.file.Node[]}
---@return org-roam.core.File
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.filename = opts.filename
    instance.links = opts.links or {}
    instance.nodes = {}
    for _, node in ipairs(opts.nodes or {}) do
        instance.nodes[node.id] = node
    end

    return instance
end

---Retrieves a node from the file by its id.
---@param id string
---@return org-roam.core.file.Node
function M:get_node(id)
    return self.nodes[id]
end

---Retrieves nodes from the collection by their ids.
---@param ... string|string[]
---@return org-roam.core.file.Node[]
function M:get_nodes(...)
    local ids = vim.iter({ ... }):flatten():totable()
    local nodes = {}

    for _, id in ipairs(ids) do
        local node = self:get_node(id)
        if node then
            table.insert(nodes, node)
        end
    end

    return nodes
end

---Returns nodes as a list.
---@return org-roam.core.file.Node[]
function M:get_node_list()
    return vim.tbl_values(self.nodes)
end

---@param nodes org-roam.core.file.Node
---@return org-roam.core.utils.IntervalTree|nil
local function make_node_tree(nodes)
    if #nodes == 0 then
        return
    end

    ---@param node org-roam.core.file.Node
    return require("org-roam.core.utils.tree"):from_list(vim.tbl_map(function(node)
        return {
            node.range.start.offset,
            node.range.end_.offset,
            node,
        }
    end, nodes))
end

---@type {files:table<string, org-roam.core.File>, hashes:table<string, string>}
local CACHE = setmetatable({ files = {}, hashes = {} }, { __mode = "k" })

---@param file OrgFile
---@return org-roam.core.File
function M:from_org_file(file)
    local nodes = {}

    ---@param s string|string[]|nil
    ---@return string|nil
    local function trim(s)
        if type(s) == "string" then
            return vim.trim(s)
        elseif type(s) == "table" then
            return vim.trim(table.concat(s))
        end
    end

    -- Check if we have a cached value for this file specifically
    local key = vim.fn.sha256(table.concat(file.lines, "\n"))
    if CACHE.files[key] and CACHE.hashes[file.filename] == key then
        return CACHE.files[key]
    end

    -- Build up our file-level node
    -- Get the id and strip whitespace, which incldues \r on windows
    local id = trim(file:get_property(KEYS.PROP_ID))
    if id then
        local tags = file:get_filetags()
        table.sort(tags)

        local origin = trim(file:get_property(KEYS.PROP_ORIGIN))
        table.insert(
            nodes,
            require("org-roam.core.file.node"):new({
                id = id,
                origin = origin,
                range = require("org-roam.core.file.range"):new(
                    { row = 0, column = 0, offset = 0 },
                    { row = MAX_NUMBER, column = MAX_NUMBER, offset = MAX_NUMBER }
                ),
                file = file.filename,
                mtime = file.metadata.mtime,
                title = trim(file:get_directive(KEYS.DIR_TITLE)),
                aliases = require("org-roam.core.file.utils").parse_property_value(
                    trim(file:get_property(KEYS.PROP_ALIASES)) or ""
                ),
                tags = tags,
                level = 0,
                linked = {},
            })
        )
    end

    -- Build up our section-level nodes
    for _, headline in ipairs(file:get_headlines()) do
        -- Get the id and strip whitespace, which incldues \r on windows
        local id = trim(headline:get_property(KEYS.PROP_ID))
        if id then
            -- NOTE: By default, this will get filetags and respect tag inheritance
            --       for nested headlines. If this is turned off in orgmode, then
            --       this only returns tags for the headline itself. We're going
            --       to use this and let that be a decision the user makes.
            local tags = headline:get_tags()
            table.sort(tags)

            local origin = trim(headline:get_property(KEYS.PROP_ORIGIN))
            table.insert(
                nodes,
                require("org-roam.core.file.node"):new({
                    id = id,
                    origin = origin,
                    range = require("org-roam.core.file.range"):from_node(
                        assert(headline.headline:parent(), "headline missing parent")
                    ),
                    file = file.filename,
                    mtime = file.metadata.mtime,
                    title = headline:get_title(),
                    aliases = require("org-roam.core.file.utils").parse_property_value(
                        trim(headline:get_property(KEYS.PROP_ALIASES)) or ""
                    ),
                    tags = tags,
                    level = headline:get_level(),
                    linked = {},
                })
            )
        end
    end

    -- If we have no nodes, we're done and can return early to avoid processing links
    local node_tree = make_node_tree(nodes)
    if not node_tree then
        return M:new({ filename = file.filename })
    end

    -- Build links with full ranges and connect them to nodes
    local links = {}
    for _, link in ipairs(file:get_links()) do
        local id = trim(link.url:get_id())
        local range = link.range
        if id and range then
            -- Figure out the full range from the file and add the link to our list
            local roam_range = require("org-roam.core.file.range"):from_org_file_and_range(file, range)
            table.insert(
                links,
                require("org-roam.core.file.link"):new({
                    kind = "regular",
                    range = roam_range,
                    path = link.url:to_string(),
                    description = link.desc,
                })
            )

            -- Figure out the node that contains the link
            ---@type org-roam.core.file.Node|nil
            local node = node_tree:find_smallest_data({
                roam_range.start.offset,
                roam_range.end_.offset,
                match = "contains",
            })

            -- Update the node's data to contain the link position
            if node then
                if not node.linked[id] then
                    node.linked[id] = {}
                end

                ---@type org-roam.core.file.Position
                local pos = vim.deepcopy(roam_range.start)

                table.insert(node.linked[id], pos)
            end
        end
    end

    -- Scan property drawer values for id links (e.g. [[id:xxx][desc]] or [[id:xxx]])
    -- This enables backlinks from properties like ROAM_REFS or custom properties
    local SKIP_PROPS = { id = true, roam_aliases = true, roam_origin = true }

    ---Scans a property value string for id links, creating Link objects and
    ---updating the node's linked table.
    ---@param prop_value string
    ---@param prop_row integer zero-indexed row where the property value starts
    ---@param prop_col integer zero-indexed column where the property value starts
    ---@param prop_offset integer zero-indexed byte offset where the property value starts
    ---@param containing_node org-roam.core.file.Node
    local function scan_property_value_for_links(prop_value, prop_row, prop_col, prop_offset, containing_node)
        local search_start = 1
        while true do
            -- Match [[id:XXX][DESC]] or [[id:XXX]]
            local link_start, link_end, link_id, desc =
                string.find(prop_value, "%[%[id:([^%]]+)%]%[([^%]]+)%]%]", search_start)
            if not link_start then
                link_start, link_end, link_id = string.find(prop_value, "%[%[id:([^%]]+)%]%]", search_start)
            end
            if not link_start then
                break
            end

            local col_offset = link_start - 1
            local roam_range = require("org-roam.core.file.range"):new({
                row = prop_row,
                column = prop_col + col_offset,
                offset = prop_offset + col_offset,
            }, {
                row = prop_row,
                column = prop_col + link_end - 1,
                offset = prop_offset + link_end - 1,
            })

            table.insert(
                links,
                require("org-roam.core.file.link"):new({
                    kind = "property",
                    range = roam_range,
                    path = "id:" .. link_id,
                    description = desc,
                })
            )

            if not containing_node.linked[link_id] then
                containing_node.linked[link_id] = {}
            end

            ---@type org-roam.core.file.Position
            local pos = vim.deepcopy(roam_range.start)
            table.insert(containing_node.linked[link_id], pos)

            search_start = link_end + 1
        end
    end

    -- Scan file-level property drawer
    local file_node_id = trim(file:get_property(KEYS.PROP_ID))
    if file_node_id then
        -- Find the file-level node (level 0) from our nodes list
        ---@type org-roam.core.file.Node|nil
        local file_node
        for _, n in ipairs(nodes) do
            if n.id == file_node_id then
                file_node = n
                break
            end
        end

        if file_node then
            local file_props, file_prop_ranges, file_prop_drawer = file:get_properties()
            if file_prop_drawer then
                for prop_name, prop_value in pairs(file_props) do
                    if not SKIP_PROPS[prop_name] and string.find(prop_value, "%[%[id:", 1, false) then
                        local prop_range = file_prop_ranges[prop_name]
                        if prop_range then
                            -- prop_range.start_line is 1-indexed
                            local row = prop_range.start_line - 1
                            local line = file.lines[prop_range.start_line] or ""
                            -- Find where the value starts in the line (after ":NAME: ")
                            local _, val_start = string.find(line, "^%s*:[^:]-:%s*")
                            val_start = val_start or 0
                            local col = val_start
                            local offset = col
                            for i = 1, row do
                                offset = offset + string.len(file.lines[i] or "") + 1
                            end
                            scan_property_value_for_links(prop_value, row, col, offset, file_node)
                        end
                    end
                end
            end
        end
    end

    -- Build a lookup from node id to node for quick access
    local nodes_by_id = {}
    for _, n in ipairs(nodes) do
        nodes_by_id[n.id] = n
    end

    -- Scan headline-level property drawers
    for _, headline in ipairs(file:get_headlines()) do
        local hl_id = trim(headline:get_property(KEYS.PROP_ID))
        if hl_id then
            local hl_node = nodes_by_id[hl_id]

            if hl_node then
                local hl_props, hl_prop_node = headline:get_own_properties()
                if hl_prop_node then
                    for prop_name, prop_value in pairs(hl_props) do
                        if not SKIP_PROPS[prop_name] and string.find(prop_value, "%[%[id:", 1, false) then
                            -- Iterate treesitter children to find the exact property node
                            for _, child in ipairs(require("orgmode.utils.treesitter").get_named_children(hl_prop_node)) do
                                local name_node = child:field("name")[1]
                                local value_node = child:field("value")[1]
                                if name_node and value_node and file:get_node_text(name_node):lower() == prop_name then
                                    local row, col, offset = value_node:start()
                                    scan_property_value_for_links(prop_value, row, col, offset, hl_node)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local roam_file = M:new({
        filename = file.filename,
        links = links,
        nodes = nodes,
    })

    -- Clear old file instance from cache
    local old_key = CACHE.hashes[file.filename]
    if old_key and CACHE.files[old_key] then
        CACHE.files[old_key] = nil
    end

    -- Update cache with new file instance
    CACHE.hashes[file.filename] = key
    CACHE.files[key] = roam_file

    return roam_file
end

return M
