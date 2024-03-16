-------------------------------------------------------------------------------
-- SCANNER.LUA
--
-- Logic to scan for org files, parse them, translate into nodes, and insert
-- into a database.
-------------------------------------------------------------------------------

local Emitter      = require("org-roam.core.utils.emitter")
local IntervalTree = require("org-roam.core.utils.tree.interval")
local io           = require("org-roam.core.utils.io")
local Node         = require("org-roam.core.database.node")
local parser       = require("org-roam.core.parser")
local parser_utils = require("org-roam.core.parser.utils")
local Range        = require("org-roam.core.parser.range")

local uv           = vim.loop

---@class org-roam.core.Scanner
---@field private emitter org-roam.core.utils.Emitter #used to emit scans
---@field private paths string[] #paths to scan
---@field private running boolean #true if scanning paths
local M            = {}
M.__index          = M

---Creates a new instance of the scanner.
---@param paths string[]
---@return org-roam.core.Scanner
function M:new(paths)
    local instance = {}
    setmetatable(instance, M)
    instance.emitter = Emitter:new()
    instance.paths = paths
    instance.running = false

    return instance
end

---@alias org-roam.core.scanner.Scan
---| {path:string, file:org-roam.core.parser.File, nodes:org-roam.core.database.Node[]}

---Register callback to be invoked when a file is scanned.
---This can be triggered during the initial scan or when a file is changed.
---@param cb fun(scan:org-roam.core.scanner.Scan)
---@return org-roam.core.Scanner
function M:on_scan(cb)
    self.emitter:on("scanner:scan", cb)
    return self
end

---Register callback to be invoked when initial scanning has finished.
---@param cb fun()
---@return org-roam.core.Scanner
function M:on_done(cb)
    self.emitter:on("scanner:done", cb)
    return self
end

---Register callback to be invoked when an unexpected error occurs.
---@param cb fun(err:string)
---@return org-roam.core.Scanner
function M:on_error(cb)
    self.emitter:on("scanner:error", cb)
    return self
end

---Start scanning paths for nodes.
---@return org-roam.core.Scanner
function M:start()
    self.running = true

    local scan_cnt = 0
    local scan_max = #self.paths

    local function if_done_then_emit()
        if self.running and scan_cnt == scan_max then
            self.running = false
            self.emitter:emit("scanner:done")
        end
    end

    -- In case we have no paths
    if_done_then_emit()

    -- For each path, we kick off a stat check to see if it's a directory
    -- or a file and process accordingly
    for _, path in ipairs(self.paths) do
        uv.fs_stat(path, function(e, stat)
            -- Special case where we fail to read some path where we
            -- need to manually increment the count, report an error,
            -- and potentially emit done status
            if e then
                scan_cnt = scan_cnt + 1
                self.emitter:emit("scanner:error", e)
                if_done_then_emit()
                return
            end

            ---@cast stat -nil
            if stat.type == "directory" then
                self:__scan_dir(path, function(err, results)
                    if err then
                        self.emitter:emit("scanner:error", err)
                    end

                    if results then
                        self.emitter:emit("scanner:scan", {
                            path = results.entry.path,
                            file = results.file,
                            nodes = results.nodes,
                        })
                    end
                end, function()
                    -- Invoked when done scanning directory
                    scan_cnt = scan_cnt + 1
                    if_done_then_emit()
                end)
            elseif stat.type == "file" then
                self:__scan_file(path, function(err, results)
                    scan_cnt = scan_cnt + 1
                    if err then
                        self.emitter:emit("scanner:error", err)
                    end

                    if results then
                        self.emitter:emit("scanner:scan", {
                            path = path,
                            file = results.file,
                            nodes = results.nodes,
                        })
                    end
                    if_done_then_emit()
                end)
            else
                -- Situation where this path was neither a file nor a
                -- directory; therefore, we still increment as processed
                -- and emit done status if finished, but otherwise do
                -- nothing else
                scan_cnt = scan_cnt + 1
                if_done_then_emit()
            end
        end)
    end

    return self
end

---Stop scanning paths for nodes.
function M:stop()
    if self.running then
        self.running = false
        self.emitter:emit("scanner:done")
    end
end

---Returns true if scanner is currently doing a scan.
---@return boolean
function M:is_running()
    return self.running
end

---@class org-roam.core.scanner.ScanDirResults
---@field entry org-roam.core.utils.io.WalkEntry
---@field file org-roam.core.parser.File
---@field nodes org-roam.core.database.Node[]

---Performs a one-time scan of a directory, parsing each org file found,
---invoking the provided callback once per file.
---@private
---@param path string
---@param cb fun(err:string|nil, results:org-roam.core.scanner.ScanDirResults|nil)
---@param done fun()
function M:__scan_dir(path, cb, done)
    local it = io.walk(path, { depth = math.huge })
        :filter(function(entry) return entry.type == "file" end)
        :filter(function(entry) return vim.endswith(entry.filename, ".org") end)

    local function do_parse()
        if self.running and it:has_next() then
            ---@type org-roam.core.utils.io.WalkEntry
            local entry = it:next()

            self:__scan_file(entry.path, function(err, results)
                if err then
                    cb(err)
                    return
                end

                vim.schedule(function()
                    ---@cast results -nil
                    cb(nil, {
                        entry = entry,
                        file = results.file,
                        nodes = results.nodes,
                    })
                end)

                vim.schedule(do_parse)
            end)

            -- Exit so we wait for next scheduled parse
            return
        else
            vim.schedule(done)
        end
    end

    do_parse()
end

---@param path string
---@param file org-roam.core.parser.File
---@return org-roam.core.database.Node[]
local function file_to_nodes(path, file)
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
                and parser_utils.parse_property_value(aliases_text)
                or {}

            file_node = Node:new({
                id = id,
                range = Range:new(
                    { row = 0, column = 0, offset = 0 },
                    { row = math.huge, column = math.huge, offset = math.huge }
                ),
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

    -- Second, build an interval tree of our sections so we
    -- can look up tags that apply
    ---@type org-roam.core.utils.tree.IntervalTree|nil
    local tags_tree
    if #file.sections > 0 then
        tags_tree = IntervalTree:from_list(vim.tbl_map(function(section)
            ---@cast section org-roam.core.parser.Section
            return {
                section.range.start.offset,
                section.range.end_.offset,
                section.heading:tag_list(),
            }
        end, file.sections))
    end

    -- Third, for each section, check if it has a node
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
                and parser_utils.parse_property_value(aliases_text)
                or {}

            local title = heading.item and vim.trim(heading.item:text()) or nil

            -- Build up tags for the heading, which is a combination of
            -- the file tags, any tags from ancestor headings, and
            -- then this heading
            local tags = vim.deepcopy(file.filetags)
            local nodes = {}
            if tags_tree then
                nodes = tags_tree:find_all({
                    section.range.start.offset,
                    section.range.end_.offset,
                    match = "contains",
                })
            end

            for _, node in ipairs(nodes) do
                for _, tag in ipairs(node.data) do
                    ---@cast tag string
                    table.insert(tags, tag)
                end
            end

            table.sort(tags)

            table.insert(section_nodes, {
                section.range,
                Node:new({
                    id = id,
                    range = section.range,
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

    -- Build an interval tree from our section nodes
    ---@type org-roam.core.utils.tree.IntervalTree|nil
    local section_node_tree
    if #section_nodes > 0 then
        section_node_tree = IntervalTree:from_list(vim.tbl_map(function(t)
            return { t[1].start.offset, t[1].end_.offset, t[2] }
        end, section_nodes))
    end

    -- Figure out which node contains the link
    for _, link in ipairs(file.links) do
        local link_path = vim.trim(link.path)
        local link_id = string.match(link_path, "^id:(.+)$")

        -- For now, we only consider links that are
        -- standard org id links, nothing else. This
        -- differs from org-roam in Emacs, where they
        -- cache all links and use the non-id links
        -- externally.
        if link_id then
            local target_node
            if section_node_tree then
                target_node = section_node_tree:find_last_data({
                    link.range.start.offset,
                    link.range.end_.offset,
                    match = "contains",
                })
            end

            if not target_node then
                target_node = file_node
            end

            if target_node then
                if not target_node.linked[link_id] then
                    target_node.linked[link_id] = {}
                end

                ---@type org-roam.core.parser.Position
                local pos = vim.deepcopy(link.range.start)

                table.insert(target_node.linked[link_id], pos)
            end
        end
    end

    ---@type org-roam.core.database.Node[]
    local nodes = {}
    if file_node then
        table.insert(nodes, file_node)
    end

    for _, tbl in ipairs(section_nodes) do
        table.insert(nodes, tbl[2])
    end

    return nodes
end

---@class org-roam.core.scanner.ScanFileResults
---@field file org-roam.core.parser.File
---@field nodes org-roam.core.database.Node[]

---Performs a one-time scan of a file, parsing the contents.
---@private
---@param path string
---@param cb fun(err:string|nil, results:org-roam.core.scanner.ScanFileResults|nil)
function M:__scan_file(path, cb)
    parser.parse_file(path, function(err, file)
        if err then
            cb(err)
            return
        end

        ---@cast file -nil
        cb(nil, {
            file = file,
            nodes = file_to_nodes(path, file),
        })
    end)
end

---Performs a one-time scan of a string, parsing the contents.
---@param contents string
---@param opts? {path?:string}
---@return org-roam.core.scanner.ScanFileResults
function M.scan(contents, opts)
    opts = opts or {}
    local file = parser.parse(contents)

    return {
        file = file,
        nodes = file_to_nodes(
            opts.path or "<STRING>",
            file
        ),
    }
end

return M
