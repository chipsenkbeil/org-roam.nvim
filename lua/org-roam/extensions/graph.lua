-------------------------------------------------------------------------------
-- GRAPH.LUA
--
-- Implementation of org-roam-graph extension.
--
-- See https://www.orgroam.com/manual.html#org_002droam_002dgraph
-------------------------------------------------------------------------------

---Escapes a string for use in a DOT label.
---@param s string
---@return string
local function dot_escape(s)
    return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
end

---Generates a DOT (Graphviz) representation of the node graph.
---@param roam OrgRoam
---@param opts? {path?:string}
---@return string dot #the DOT representation
local function roam_graph_to_dot(roam, opts)
    opts = opts or {}

    local lines = {
        "digraph OrgRoam {",
        "  rankdir=LR;",
        '  node [shape=box, style="rounded,filled", fillcolor="#f5f5f5", fontname="sans-serif"];',
        '  edge [color="#888888"];',
        "",
    }

    -- Emit all nodes first
    local ids = roam.database:ids()
    table.sort(ids)

    for _, id in ipairs(ids) do
        local node = roam.database:get_sync(id)
        if node then
            local label = dot_escape(node.title or id)
            table.insert(lines, string.format('  "%s" [label="%s"];', dot_escape(id), label))
        end
    end

    table.insert(lines, "")

    -- Emit all edges
    for _, id in ipairs(ids) do
        local outbound = roam.database:get_links(id)
        local targets = vim.tbl_keys(outbound)
        table.sort(targets)
        for _, target_id in ipairs(targets) do
            table.insert(lines, string.format('  "%s" -> "%s";', dot_escape(id), dot_escape(target_id)))
        end
    end

    table.insert(lines, "}")

    return table.concat(lines, "\n")
end

---@param roam OrgRoam
---@return org-roam.extensions.Graph
return function(roam)
    ---@class org-roam.extensions.Graph
    local M = {}

    ---Generates a DOT (Graphviz) representation of the entire node graph.
    ---@return string dot
    function M.to_dot()
        return roam_graph_to_dot(roam)
    end

    ---Exports the node graph as a DOT file.
    ---If no `path` is specified, prompts the user for a file path.
    ---@param opts? {path?:string}
    function M.export_to_dot(opts)
        opts = opts or {}

        local path = opts.path
        if not path then
            path = vim.fn.input("Export DOT graph to: ", vim.fn.getcwd() .. "/org-roam-graph.dot")
            if path == "" then
                return
            end
        end

        path = vim.fs.normalize(path)
        local dot = roam_graph_to_dot(roam)

        local fd = assert(io.open(path, "w"), "failed to open file for writing: " .. path)
        fd:write(dot)
        fd:write("\n")
        fd:close()

        require("org-roam.core.ui.notify").echo_info("Graph exported to " .. path)
    end

    return M
end
