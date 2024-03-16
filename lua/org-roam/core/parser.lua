-------------------------------------------------------------------------------
-- PARSER.LUA
--
-- Parsing logic to extract information from org files.
-------------------------------------------------------------------------------

local Heading             = require("org-roam.core.parser.heading")
local PropertyDrawer      = require("org-roam.core.parser.property-drawer")
local Range               = require("org-roam.core.parser.range")
local Ref                 = require("org-roam.core.parser.ref")
local Section             = require("org-roam.core.parser.section")
local Slice               = require("org-roam.core.parser.slice")
local utils               = require("org-roam.core.parser.utils")

---@enum org-roam.core.parser.QueryTypes
local QUERY_TYPES         = {
    TOP_LEVEL_PROPERTY_DRAWER = 1,
    SECTION_PROPERTY_DRAWER = 2,
    FILETAGS = 3,
    TITLE = 4,
    CONTENTS = 5,
}

---@enum org-roam.core.parser.QueryCaptureTypes
local QUERY_CAPTURE_TYPES = {
    TOP_LEVEL_PROPERTY_DRAWER              = "top-level-drawer",
    TOP_LEVEL_PROPERTY_DRAWER_NAME         = "top-level-drawer-name",
    TOP_LEVEL_PROPERTY_DRAWER_CONTENTS     = "top-level-drawer-contents",
    SECTION                                = "section",
    SECTION_PROPERTY_DRAWER_HEADLINE       = "property-drawer-headline",
    SECTION_PROPERTY_DRAWER_HEADLINE_STARS = "property-drawer-headline-stars",
    SECTION_PROPERTY_DRAWER_HEADLINE_TAGS  = "property-drawer-headline-tags",
    SECTION_PROPERTY_DRAWER_HEADLINE_ITEM  = "property-drawer-headline-item",
    SECTION_PROPERTY_DRAWER                = "property-drawer",
    SECTION_PROPERTY_DRAWER_PROPERTY       = "property",
    SECTION_PROPERTY_DRAWER_PROPERTY_NAME  = "property-name",
    SECTION_PROPERTY_DRAWER_PROPERTY_VALUE = "property-value",
    DIRECTIVE_NAME                         = "directive-name",
    DIRECTIVE_VALUE                        = "directive-value",
}

---@class org-roam.core.parser.File
---@field title string|nil
---@field filetags string[]
---@field drawers org-roam.core.parser.PropertyDrawer[]
---@field sections org-roam.core.parser.Section[]
---@field links org-roam.core.parser.Link[]

---@class org-roam.core.Parser
---@field private __is_initialized boolean
local M                   = {
    __is_initialized = false,
}

function M.init()
    if M.__is_initialized then
        return
    end

    -- Build out custom predicates
    vim.treesitter.query.add_predicate("org-roam-eq-case-insensitive?", function(
        match, _, source, predicates
    )
        ---@type TSNode
        local node = match[predicates[2]]

        ---@type string
        local text = predicates[3]

        return string.lower(vim.treesitter.get_node_text(node, source)) == string.lower(text)
    end)

    M.__is_initialized = true
end

---@param contents string
---@return org-roam.core.parser.File
function M.parse(contents)
    M.init()

    local ref = Ref:new(contents)
    local trees = vim.treesitter.get_string_parser(ref.value, "org"):parse()

    -- Build a query to find top-level drawers (with name PROPERTIES),
    -- property drawers underneath headings, directives, and expressions
    -- that contain links.
    ---@type Query
    local query = vim.treesitter.query.parse("org", [=[
        ((drawer
            name: (expr) @top-level-drawer-name
            contents: (contents) @top-level-drawer-contents) @top-level-drawer
            (#eq? @top-level-drawer-name "PROPERTIES"))
        (section
            (headline
                stars: (stars) @property-drawer-headline-stars
                tags: ((tag_list)? @property-drawer-headline-tags)
                item: ((item)? @property-drawer-headline-item)) @property-drawer-headline
            (property_drawer) @property-drawer) @section
        ((directive
            name: (expr) @directive-name
            value: (value) @directive-value)
            (#org-roam-eq-case-insensitive? @directive-name "filetags"))
        ((directive
            name: (expr) @directive-name
            value: (value) @directive-value)
            (#org-roam-eq-case-insensitive? @directive-name "title"))
        [
            (paragraph) @paragraph
            (item) @item
            (contents) @contents
        ]
    ]=])

    ---@type org-roam.core.parser.File
    local file = { drawers = {}, sections = {}, filetags = {}, links = {} }
    for _, tree in ipairs(trees) do
        ---@diagnostic disable-next-line:missing-parameter
        for pattern, match, _ in query:iter_matches(tree:root(), ref.value) do
            -- Currently, we handle four different patterns:
            --
            -- 1. Top Level Property Drawer: this shows up when we find a
            --                               normal drawer named PROPERTIES
            --                               that is not within a section.
            --
            -- 2. Section Property Drawer: this shows up when we find a
            --                             property drawer within a section.
            --
            -- 3. Directive: this shows up when we find a directive anywhere
            --               within the contents. Currently, we limit
            --               the match to be a filetags and title directives.
            --
            -- 4. Content containing Links: this shows up when we find content
            --                              that we will parse for links.
            if pattern == QUERY_TYPES.TOP_LEVEL_PROPERTY_DRAWER then
                ---@type org-roam.core.parser.Range|nil
                local range
                local properties = {}
                for id, node in pairs(match) do
                    local name = query.captures[id]

                    -- We only expect to deal with the full contents within a property
                    -- drawer in this situation.
                    --
                    -- :PROPERTIES:
                    -- ... <-- everything in here we need to parse
                    -- :END:
                    if name == QUERY_CAPTURE_TYPES.TOP_LEVEL_PROPERTY_DRAWER then
                        range = Range:from_node(node)
                    elseif name == QUERY_CAPTURE_TYPES.TOP_LEVEL_PROPERTY_DRAWER_CONTENTS then
                        -- Store the starting row and offset of drawer contents
                        -- so we can build up ranges for the lines within
                        local start_row, _, start_offset = node:start()

                        -- Get the lines within the drawer, which we will iterate through
                        -- NOTE: We do NOT skip empty lines!
                        local inner = vim.treesitter.get_node_text(node, ref.value)
                        local lines = vim.split(inner, "\n", { plain = true })
                        utils.parse_lines_as_properties(
                            properties,
                            ref,
                            lines,
                            start_row,
                            start_offset
                        )
                    end
                end

                table.insert(file.drawers, PropertyDrawer:new({
                    range = assert(range, "Impossible: Failed to find range of top-level property drawer"),
                    properties = properties,
                }))
            elseif pattern == QUERY_TYPES.SECTION_PROPERTY_DRAWER then
                local range
                ---@type org-roam.core.parser.Property[]
                local properties = {}
                local heading_range
                local heading_stars
                local heading_item
                local heading_tag_list
                local section_range

                -- TODO: Due to https://github.com/neovim/neovim/issues/17060, we cannot use iter_matches
                --       with a quantification using + in our query as the multiple node matches do not
                --       show up. Instead, we have to do a hack where we read the contents between the
                --       property drawer and parse them the same way as our top-level parser.
                for id, node in pairs(match) do
                    local name = query.captures[id]

                    if name == QUERY_CAPTURE_TYPES.SECTION then
                        section_range = Range:from_node(node)
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_HEADLINE then
                        heading_range = Range:from_node(node)
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_HEADLINE_STARS then
                        local stars = vim.treesitter.get_node_text(node, ref.value)
                        if type(stars) == "string" then
                            heading_stars = string.len(stars)
                        end
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_HEADLINE_TAGS then
                        local tag_list = vim.treesitter.get_node_text(node, ref.value)
                        heading_tag_list = Slice:new(
                            ref,
                            Range:from_node(node),
                            { cache = tag_list }
                        )
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER_HEADLINE_ITEM then
                        local item = vim.treesitter.get_node_text(node, ref.value)
                        heading_item = Slice:new(
                            ref,
                            Range:from_node(node),
                            { cache = item }
                        )
                    elseif name == QUERY_CAPTURE_TYPES.SECTION_PROPERTY_DRAWER then
                        range = Range:from_node(node)

                        -- Search for links throughout the contents of the property drawer
                        --
                        -- NOTE: This is done outside of the contents pattern so we don't
                        --       scan property drawers twice!
                        vim.list_extend(file.links, utils.scan_for_links(range, ref))

                        -- Get the lines between the property drawer for us to manually parse
                        -- due to https://github.com/neovim/neovim/issues/17060 preventing us
                        -- from capturing multiple properties using quantification operators.
                        local all_lines = vim.split(vim.treesitter.get_node_text(node, ref.value), "\n", { plain = true })

                        -- Start row for properties is one line after :PROPERTIES:
                        local start_row = range.start.row + 1

                        -- Start offset for properties is one line after :PROPERTIES:\n
                        local start_offset = range.start.offset + string.len(all_lines[1]) + 1

                        local lines = {}
                        for i, line in ipairs(all_lines) do
                            if i > 1 and i < #all_lines then
                                table.insert(lines, line)
                            end
                        end

                        utils.parse_lines_as_properties(
                            properties,
                            ref,
                            lines,
                            start_row,
                            start_offset
                        )
                    end
                end

                ---@type org-roam.core.parser.Heading|nil
                local heading
                if heading_range and heading_stars then
                    heading = Heading:new({
                        range = heading_range,
                        stars = heading_stars,
                        item = heading_item,
                        tags = heading_tag_list,
                    })
                end

                table.insert(file.sections, Section:new(
                    assert(section_range, "impossible: failed to find section range"),
                    assert(heading, "impossible: failed to find section heading"),
                    PropertyDrawer:new({
                        range = range,
                        properties = properties,
                        heading = heading,
                    })
                ))
            elseif pattern == QUERY_TYPES.FILETAGS then
                for id, node in pairs(match) do
                    local name = query.captures[id]

                    if name == QUERY_CAPTURE_TYPES.DIRECTIVE_VALUE then
                        local tags = utils.parser.parse_tags(
                            vim.treesitter.get_node_text(node, ref.value)
                        )

                        for _, tag in ipairs(tags) do
                            table.insert(file.filetags, tag)
                        end
                    end
                end
            elseif pattern == QUERY_TYPES.TITLE then
                for id, node in pairs(match) do
                    local name = query.captures[id]

                    if name == QUERY_CAPTURE_TYPES.DIRECTIVE_VALUE then
                        file.title = vim.trim(
                            vim.treesitter.get_node_text(node, ref.value)
                        )
                    end
                end
            elseif pattern == QUERY_TYPES.CONTENTS then
                -- Create range representing the contents
                local range = utils.get_pattern_range(match)

                -- Search for links throughout the contents
                vim.list_extend(file.links, utils.scan_for_links(range, ref))
            end
        end
    end

    -- TODO: I'm not sure if it's a bug or not - I couldn't reproduce using Lua
    --       as the treesitter language - but having two optional fields results
    --       in this pattern being triggered twice: once with tags and once with
    --       item.
    --
    --       Because of this situation, we need to merge duplicates of sections
    --       that each have either tags or item. We do this by using the section
    --       range, which should be unique, to look up a pre-existing section.
    ---@type table<string,org-roam.core.parser.Section>
    local sections_by_range = {}
    for _, section in ipairs(file.sections) do
        local key = string.format(
            "%s,%s",
            section.range.start.offset,
            section.range.end_.offset
        )

        -- If we already have a section, then update
        -- tags and items if they are missing and
        -- we have them
        local other = sections_by_range[key]
        if other then
            if other.heading.tags then
                section.heading.tags = other.heading.tags
            end
            if other.heading.item then
                section.heading.item = other.heading.item
            end
        end
        sections_by_range[key] = section
    end

    -- Rebuild section list in order of appearance
    local sections = vim.tbl_values(sections_by_range)
    table.sort(sections, function(a, b)
        return a.range.start.offset < b.range.start.offset
    end)
    file.sections = sections

    return file
end

---Loads a file from disk asynchronously and parses its contents.
---@param path string
---@param cb fun(err:string|nil, file:org-roam.core.parser.File|nil)
function M.parse_file(path, cb)
    utils.io.read_file(path, function(err, contents)
        cb(err, contents and M.parse(contents))
    end)
end

---Loads multiple files from disk asynchronously and parses their contents.
---@param paths string[]
---@param cb fun(errors:table<string, string>, files:table<string, org-roam.core.parser.File>)
function M.parse_files(paths, cb)
    local errors = {}
    local files = {}

    local i = 0
    local cnt = #paths
    for _, path in ipairs(paths) do
        M.parse_file(path, function(err, file)
            if err then
                errors[path] = err
            end

            if file then
                files[path] = file
            end

            -- Increment completed and check if we're done
            i = i + 1
            if i == cnt then
                cb(errors, files)
            end
        end)
    end
end

return M
