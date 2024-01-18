-------------------------------------------------------------------------------
-- PARSER.LUA
--
-- Parsing logic to extract information from org files.
-------------------------------------------------------------------------------

-- THINGS WE NEED:
--
-- 1. Logic to parse org file into Treesitter trees
-- 2. Logic to scan Treesitter trees to find property drawers and return their
--    level, link to their heading, and support modification of their keys/values
-- 3. Take property drawer objects and transform them into nodes
-- 4. Insert nodes into database, or update existing nodes in database

---@enum org-roam.parser.QueryTypes
local QUERY_TYPES = {
    TOP_LEVEL_PROPERTY_DRAWER = 1,
    SECTION_PROPERTY_DRAWER = 2,
    REGULAR_LINK = 3,
}

---@enum org-roam.parser.QueryCaptureTypes
local QUERY_CAPTURE_TYPES = {
    TOP_LEVEL_PROPERTY_DRAWER_NAME = "top-level-drawer-name",
    TOP_LEVEL_PROPERTY_DRAWER_CONTENTS = "top-level-drawer-contents",
    SECTION_PROPERTY_DRAWER_KEY = "property-name",
    SECTION_PROPERTY_DRAWER_VALUE = "property-value",
    REGULAR_LINK = "regular-link",
}

---@class org-roam.parser.Results
---@field drawers org-roam.parser.PropertyDrawer[]
---@field links org-roam.parser.Link[]

---@class org-roam.parser.PropertyDrawer
---@field range org-roam.parser.Range
---@field heading? org-roam.parser.Heading
---@field properties org-roam.parser.Property[]

---@class org-roam.parser.Heading
---@field range org-roam.parser.Range
---@field stars integer #total number of stars associated with the heading

---@class org-roam.parser.Property
---@field key {text:string, range:org-roam.parser.Range}
---@field value {text:string, range:org-roam.parser.Range}

---@alias org-roam.parser.Link
---| org-roam.parser.RegularLink
---| org-roam.parser.RadioLink
---| org-roam.parser.PlainLink
---| org-roam.parser.AngleLink

---@class org-roam.parser.PlainLink
---@field kind 'plain'
---@field range org-roam.parser.Range
---@field path string

---@class org-roam.parser.AngleLink
---@field kind 'angle'
---@field range org-roam.parser.Range
---@field path string

---@class org-roam.parser.RadioLink
---@field kind 'radio'
---@field range org-roam.parser.Range
---@field path string

---@class org-roam.parser.RegularLink
---@field kind 'regular'
---@field range org-roam.parser.Range
---@field path string
---@field description? string

---@class org-roam.parser.Range
---@field start {row:integer, column:integer, offset:integer} #all zero-based
---@field end_ {row:integer, column:integer, offset:integer} #all zero-based

---@class org-roam.Parser
---@field private __is_initialized boolean
local M = {
    __is_initialized = false,
}

function M.init()
    if M.__is_initialized then
        return
    end

    ---Retrieves the text of a node.
    ---Pulled from nvim-orgmode/orgmode.
    ---@param node TSNode
    ---@param source number
    ---@param offset_col_start? number
    ---@param offset_col_end? number
    ---@return string
    local function get_node_text(node, source, offset_col_start, offset_col_end)
        local range = { node:range() }
        return vim.treesitter.get_node_text(node, source, {
            metadata = {
                range = {
                    range[1],
                    math.max(0, range[2] + (offset_col_start or 0)),
                    range[3],
                    math.max(0, range[4] + (offset_col_end or 0)),
                },
            },
        })
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
function M.test_parse(contents)
    M.init()

    local trees = vim.treesitter.get_string_parser(contents, "org"):parse()

    -- Build a query to find top-level drawers (with  name PROPERTIES)
    -- property drawers underneath headings, and expressions that are links
    --
    -- NOTE: The link-parsing logic is a bit of a hack and comes from
    --       https://github.com/nvim-orgmode/orgmode/blob/master/queries/org/markup.scm
    local query = vim.treesitter.query.parse("org", [=[
        (
            (drawer
                name: (expr) @top-level-drawer-name
                contents: (contents) @top-level-drawer-contents)
            (#eq? @top-level-drawer-name "PROPERTIES")
        )
        (section
            (headline
                stars: (stars) @headline-stars)
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

    ---@param node TSNode
    ---@return org-roam.parser.Range
    local function node_to_range(node)
        local range = {}

        local row, column, offset
        row, column, offset = node:start()
        range.start = { row = row, column = column, offset = offset }
        row, column, offset = node:end_()
        range.end_ = { row = row, column = column, offset = offset }

        return range
    end

    ---@type org-roam.parser.Results
    local results = { drawers = {}, links = {} }
    for _, tree in ipairs(trees) do
        for pattern, match, metadata in query:iter_matches(tree:root(), contents) do
            ---@type integer, integer
            local offset_start, offset_end = math.huge, -1

            -- Currently, we handle three different patterns:
            --
            -- 1. Top Level Property Drawer: this shows up when we find a
            --                               normal drawer named PROPERTIES
            --                               that is not within a section.
            --
            -- 2. Section Property Drawer: this shows up when we find a
            --                             property drawer within a sectin.
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
                print("KIND: top-level-property-drawer")
                local drawer = { range = {}, properties = {} }
                table.insert(results.drawers, drawer)

                for id, node in pairs(match) do
                    local name = query.captures[id]
                    local node_data = metadata[id]

                    -- We only expect to deal with the full contents within a property
                    -- drawer in this situation.
                    --
                    -- :PROPERTIES:
                    -- ... <-- everything in here we need to parse
                    -- :END:
                    if name == QUERY_CAPTURE_TYPES.TOP_LEVEL_PROPERTY_DRAWER_CONTENTS then
                        local inner = vim.treesitter.get_node_text(node, contents)
                        local lines = vim.split(inner, "\n", { plain = true, trimempty = true })
                        for _, line in ipairs(lines) do
                            -- Parse ":KEY: VALUE"
                            local _, _, key, value = string.find(line, ":([^%c%z\\n]):%s+([^%c%z\\n])")
                            if key and value then
                                local property = {

                                }
                                ---@field range org-roam.parser.Range
                                ---@field heading? org-roam.parser.Heading
                                ---@field properties org-roam.parser.Property[]
                            end
                        end
                    end
                end
            elseif pattern == QUERY_TYPES.SECTION_PROPERTY_DRAWER then
                local drawer = { range = {}, properties = {} }
                print("KIND: section-property-drawer")
            elseif pattern == QUERY_TYPES.REGULAR_LINK then
                print("KIND: regular-link")
            end
        end
    end
    return results
end

---Parses a file into zero or more org roam nodes.
---@param path string
---@return org-roam.Node[]
function M.parse(path)
    local trees = M.__load_org_file_as_treesitter_trees(path)
    return M.__treesitter_trees_into_nodes(trees)
end

---Parses a string into zero or more org roam nodes.
---@param contents string
---@return org-roam.Node[]
function M.parse_string(contents)
    local trees = M.__load_org_string_as_treesitter_trees(contents)
    return M.__treesitter_trees_into_nodes(trees)
end

---@private
---@param trees TSTree[]
---@return org-roam.Node[]
function M.__treesitter_trees_into_nodes(trees)
    local nodes = {}
    for _, tree in ipairs(trees) do
        for _, node in ipairs(M.__treesitter_root_into_org_nodes(tree:root())) do
            table.insert(nodes, node)
        end
    end
    return nodes
end

---@private
---@param root TSNode
---@return org-roam.Node[]
function M.__treesitter_root_into_org_nodes(root)
    local nodes = {}
    for _, tree in ipairs(trees) do
        error("TREE[" .. i .. "]" .. vim.inspect(tree:root():sexpr()))
    end
    return nodes
end

---@private
---@param path string
---@return {trees: TSTree[], contents: string}
function M.__load_org_file_as_treesitter_trees(path)
    -- Load file, read contents, and parse into TSTree[]; file closed on drop
    local file = assert(io.open(path, "r"), "Failed to open " .. path)

    ---@type string
    local contents = assert(file:read("*a"), "Failed to read org file @ " .. path)

    return M.__load_org_string_as_treesitter_trees(contents)
end

---@private
---@param contents string
---@return {trees: TSTree[], contents: string}
function M.__load_org_string_as_treesitter_trees(contents)
    return {
        trees = vim.treesitter.get_string_parser(contents, "org"):parse(),
        contents = contents,
    }
end

return M
