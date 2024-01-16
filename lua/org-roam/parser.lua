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

---@class org-roam.Parser
local M = {}

---@param contents string
function M.test_parse(contents)
    local trees = vim.treesitter.get_string_parser(contents, "org"):parse()

    -- Build a query to find top-level drawers (with  name PROPERTIES)
    -- or property drawers underneath headings
    local query = vim.treesitter.query.parse("org", [[
        (
            (drawer
                name: (expr) @name
                contents: (contents) @contents)
            (#eq? @name "PROPERTIES")
        )
        (
            property_drawer
            (property
                name: (expr) @name
                value: (value) @value)
        )
    ]])
    for _, tree in ipairs(trees) do
        for id, node, metadata in query:iter_captures(tree:root(), contents) do
            local name = query.captures[id] -- name of the capture in the query
            print("NAME: " .. vim.inspect(name))

            -- typically useful info about the node:
            local type = node:type() -- type of the captured node
            print("TYPE: " .. vim.inspect(type))

            local row1, col1, row2, col2 = node:range() -- range of the capture
            print("STARTING LINE " .. row1 .. ", COL " .. col1)
            print("ENDING LINE " .. row2 .. ", COL " .. col2)

            print("VALUE: " .. vim.treesitter.get_node_text(node, contents))
        end
    end
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
