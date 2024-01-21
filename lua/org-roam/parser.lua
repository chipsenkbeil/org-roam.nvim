-------------------------------------------------------------------------------
-- PARSER.LUA
--
-- Parsing logic to extract information from org files.
-------------------------------------------------------------------------------

local Heading             = require("org-roam.parser.heading")
local Link                = require("org-roam.parser.link")
local PropertyDrawer      = require("org-roam.parser.property-drawer")
local Property            = require("org-roam.parser.property")
local Range               = require("org-roam.parser.range")
local Slice               = require("org-roam.parser.slice")

---@enum org-roam.parser.QueryTypes
local QUERY_TYPES         = {
    TOP_LEVEL_PROPERTY_DRAWER = 1,
    SECTION_PROPERTY_DRAWER = 2,
    REGULAR_LINK = 3,
}

---@enum org-roam.parser.QueryCaptureTypes
local QUERY_CAPTURE_TYPES = {
    TOP_LEVEL_PROPERTY_DRAWER_NAME         = "top-level-drawer-name",
    TOP_LEVEL_PROPERTY_DRAWER_CONTENTS     = "top-level-drawer-contents",
    SECTION_PROPERTY_DRAWER_HEADLINE       = "property-drawer-headline",
    SECTION_PROPERTY_DRAWER_HEADLINE_STARS = "property-drawer-headline-stars",
    SECTION_PROPERTY_DRAWER_PROPERTY_KEY   = "property-name",
    SECTION_PROPERTY_DRAWER_PROPERTY_VALUE = "property-value",
    REGULAR_LINK                           = "regular-link",
}

---@class org-roam.parser.Results
---@field drawers org-roam.parser.PropertyDrawer[]
---@field links org-roam.parser.Link[]

---@class org-roam.Parser
---@field private __is_initialized boolean
local M                   = {
    __is_initialized = false,
}

function M.init()
    if M.__is_initialized then
        return
    end

    ---Ensures that the nodes are on the same line.
    ---Pulled from nvim-orgmode/orgmode.
    ---
    ---@param start_node TSNode
    ---@param end_node TSNode
    ---@return boolean
    local function on_same_line(start_node, end_node)
        if not start_node or not end_node then
            return false
        end

        local start_line = start_node:range()
        local end_line = end_node:range()

        return start_line == end_line
    end


    ---Ensures that the start and end of a regular link actually represent a regular link.
    ---Pulled from nvim-orgmode/orgmode.
    local function is_valid_regular_link_range(match, _, source, predicates)
        local start_node = match[predicates[2]]
        local end_node = match[predicates[3]]

        local is_valid = on_same_line(start_node, end_node)

        if not is_valid then
            return false
        end

        -- Range start is inclusive, end is exclusive, and both are zero-based
        local _, _, offset_start = start_node:start()
        local _, _, offset_end = end_node:end_()

        -- TODO: I don't know why we are running into these situations:
        --
        -- 1. There is more than one match for the same link.
        -- 2. One of the matches is missing a starting square bracket.
        -- 3. There is a space at the end of each matche.
        --     * "[[...]] "
        --     * "[...]] "
        --
        -- For now, we trim the space so one of these will work...
        local text = vim.trim(string.sub(source, offset_start + 1, offset_end + 1))

        local is_valid_start = vim.startswith(text, "[[")
        local is_valid_end = vim.endswith(text, "]]")
        return is_valid_start and is_valid_end
    end

    -- Build out custom predicates so we can further validate our links
    vim.treesitter.query.add_predicate(
        "org-roam-is-valid-regular-link-range?",
        is_valid_regular_link_range
    )

    M.__is_initialized = true
end

---@param contents string
---@return org-roam.parser.Results
function M.parse(contents)
    M.init()

    local trees = vim.treesitter.get_string_parser(contents, "org"):parse()

    -- Build a query to find top-level drawers (with  name PROPERTIES)
    -- property drawers underneath headings, and expressions that are links
    --
    -- NOTE: The link-parsing logic is a bit of a hack and comes from
    --       https://github.com/nvim-orgmode/orgmode/blob/master/queries/org/markup.scm
    ---@type Query
    local query = vim.treesitter.query.parse("org", [=[
        (
            (drawer
                name: (expr) @top-level-drawer-name
                contents: (contents) @top-level-drawer-contents)
            (#eq? @top-level-drawer-name "PROPERTIES")
        )
        (section
            (headline
                stars: (stars) @property-drawer-headline-stars) @property-drawer-headline
            (property_drawer
                (property
                    name: (expr) @property-name
                    value: (value) @property-value))
        )
        [
            (paragraph
                ((expr "[" @hyperlink.start . "[" _) (expr _ "]" . "]" @hyperlink.end)
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end)))
            (paragraph
                (expr "[" @hyperlink.start . "[" _  "]" . "]" @hyperlink.end
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end)))
            (item
                ((expr "[" @hyperlink.start . "[" _) (expr _ "]" . "]" @hyperlink.end)
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end)))
            (item
                (expr "[" @hyperlink.start . "[" _  "]" . "]" @hyperlink.end
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end)))
            (cell
                (contents ((expr "[" @hyperlink.start . "[" _) (expr _ "]" . "]" @hyperlink.end)
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end))))
            (cell
                (contents (expr "[" @hyperlink.start . "[" _  "]" . "]" @hyperlink.end
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end))))
            (drawer
                (contents ((expr "[" @hyperlink.start . "[" _) (expr _ "]" . "]" @hyperlink.end)
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end))))
            (drawer
                (contents (expr "[" @hyperlink.start . "[" _  "]" . "]" @hyperlink.end
                    (#org-roam-is-valid-regular-link-range? @hyperlink.start @hyperlink.end))))
        ]
    ]=])

    ---@type org-roam.parser.Results
    local results = { drawers = {}, links = {} }
    for _, tree in ipairs(trees) do
        for pattern, match, _ in query:iter_matches(tree:root(), contents) do
            -- Currently, we handle three different patterns:
            --
            -- 1. Top Level Property Drawer: this shows up when we find a
            --                               normal drawer named PROPERTIES
            --                               that is not within a section.
            --
            -- 2. Section Property Drawer: this shows up when we find a
            --                             property drawer within a section.
            --
            -- 3. Regular Link: this shows up when we find a regullar link.
            --                  Angle, plain, and radio links do not match.
            --
            -- For the top-level property drawer, we have to parse out the
            -- properties and their values as we only have the overall contents.
            --
            -- For the property drawer, everything comes as expected.
            --
            -- For regular links, we have to parse out the link and the
            -- optional description as we only have an overall expression.
            if pattern == QUERY_TYPES.TOP_LEVEL_PROPERTY_DRAWER then
                local properties = {}
                for id, node in pairs(match) do
                    local name = query.captures[id]

                    -- We only expect to deal with the full contents within a property
                    -- drawer in this situation.
                    --
                    -- :PROPERTIES:
                    -- ... <-- everything in here we need to parse
                    -- :END:
                    if name == QUERY_CAPTURE_TYPES.TOP_LEVEL_PROPERTY_DRAWER_CONTENTS then
                        -- Store the starting row and offset of drawer contents
                        -- so we can build up ranges for the lines within
                        local start_row, _, start_offset = node:start()

                        -- Get the lines within the drawer, which we will iterate through
                        -- NOTE: We do NOT skip empty lines!
                        local inner = vim.treesitter.get_node_text(node, contents)
                        local lines = vim.split(inner, "\n", { plain = true })

                        local row = start_row
                        local offset = start_offset
                        for _, line in ipairs(lines) do
                            -- Remember that i is starting from 1 index and not 0, which our slice uses
                            local i, _, key, space, value = string.find(line, ":([^%c%z\\n]+):(%s+)([^%c%z\\n]+)")
                            if key and value then
                                -- Total key len includes the colon on either side
                                local key_len = string.len(key) + 2
                                local key_col = i - 1
                                local key_offset = offset + key_col

                                local space_len = string.len(space)

                                local value_len = string.len(value)
                                local value_col = key_col + key_len + space_len
                                local value_offset = offset + value_col

                                -- TODO: Set the slice key to adjust for the colon on either side
                                local property = Property:new(
                                    Slice:new(key, Range:new({
                                        row = row,
                                        column = key_col,
                                        offset = key_offset
                                    }, {
                                        row = row,
                                        column = key_col + key_len,
                                        offset = key_offset + key_len
                                    })),
                                    Slice:new(value, Range:new({
                                        row = row,
                                        column = value_col,
                                        offset = value_offset
                                    }, {
                                        row = row,
                                        column = value_col + value_len,
                                        offset = value_offset + value_len
                                    }))
                                )
                                table.insert(properties, property)
                            end

                            -- Next line means next row
                            row = row + 1

                            -- Advance the offset by the line (including the newline)
                            offset = offset + string.len(line)
                        end
                    end
                end

                table.insert(results.drawers, PropertyDrawer:new(properties))
            elseif pattern == QUERY_TYPES.SECTION_PROPERTY_DRAWER then
                local drawer = { range = {}, properties = {} }

                ---@type {[1]:string, [2]:org-roam.parser.Range, [3]:string, [4]:org-roam.parser.Range}[]
                local properties = {}

                local heading_range
                local heading_stars
                for id, node in pairs(match) do
                    local name = query.captures[id]

                    if name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_HEADLINE then
                        heading_range = Range:from_node(node)
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_HEADLINE_STARS then
                        local stars = vim.treesitter.get_node_text(node, contents)
                        if type(stars) == "string" then
                            heading_stars = string.len(stars)
                        end
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_PROPERTY_KEY then
                        local range = Range:from_node(node)
                        local key = vim.treesitter.get_node_text(node, contents)
                        table.insert(properties, { key, range })
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_PROPERTY_VALUE then
                        local range = Range:from_node(node)
                        local value = vim.treesitter.get_node_text(node, contents)
                        table.insert(properties[#properties], value)
                        table.insert(properties[#properties], range)
                    end
                end

                for _, tuple in ipairs(properties) do
                    table.insert(drawer.properties, Property:new(
                        Slice:new(tuple[1], tuple[2]),
                        Slice:new(tuple[3], tuple[4])
                    ))
                end

                ---@type org-roam.parser.Heading|nil
                local heading
                if heading_range and heading_stars then
                    heading = Heading:new(heading_range, heading_stars)
                end

                table.insert(results.drawers, PropertyDrawer:new(properties, heading))
            elseif pattern == QUERY_TYPES.REGULAR_LINK then
                ---@type org-roam.parser.Position
                local start = { row = 0, column = 0, offset = math.huge }
                ---@type org-roam.parser.Position
                local end_ = { row = 0, column = 0, offset = -1 }

                -- Find start and end of match
                for _, node in pairs(match) do
                    local start_row, start_col, offset_start = node:start()
                    local end_row, end_col, offset_end = node:end_()

                    local cur_start_offset = start.offset
                    local cur_end_offset = end_.offset

                    start.offset = math.min(start.offset, offset_start)
                    end_.offset = math.max(end_.offset, offset_end)

                    -- Start changed, so adjust row/col
                    if start.offset ~= cur_start_offset then
                        start.row = start_row
                        start.column = start_col
                    end

                    -- End changed, so adjust row/col
                    if end_.offset ~= cur_end_offset then
                        end_.row = end_row
                        end_.column = end_col
                    end
                end

                -- Create range from match scan
                local range = Range:new(start, end_)

                -- Get the raw link from the contents
                local raw_link = vim.trim(string.sub(contents, range.start.offset + 1, range.end_.offset + 1))

                -- Because Lua does not support modifiers on group patterns, we test for path & description
                -- first and then try just path second
                local _, _, path, description = string.find(raw_link, "^%[%[([^%c%z]*)%]%[([^%c%z]*)%]%]$")
                if path and description then
                    local link = Link:new("regular", range, path, description)
                    table.insert(results.links, link)
                else
                    local _, _, path = string.find(raw_link, "^%[%[([^%c%z]*)%]%]$")
                    if path then
                        local link = Link:new("regular", range, path)
                        table.insert(results.links, link)
                    end
                end
            end
        end
    end
    return results
end

return M
