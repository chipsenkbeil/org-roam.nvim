-------------------------------------------------------------------------------
-- SCANNER.LUA
--
-- Logic to scan for org files, parse them, translate into nodes, and insert
-- into a database.
-------------------------------------------------------------------------------

local Emitter      = require("org-roam.core.utils.emitter")
local IntervalTree = require("org-roam.core.utils.tree")
local io           = require("org-roam.core.utils.io")
local Node         = require("org-roam.core.database.node")
local parser_utils = require("org-roam.core.parser.utils")
local Link         = require("org-roam.core.parser.link")
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
---| {path:string, file:OrgFile, nodes:org-roam.core.database.Node[]}

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
---@field file OrgFile
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
---@param file OrgFile
---@return org-roam.core.database.Node|nil
local function make_file_node(path, file)
    local id = file:get_property("ID")

    if id then
        local aliases_text = file:get_property("ROAM_ALIASES")
        local aliases = aliases_text
            and parser_utils.parse_property_value(aliases_text)
            or {}

        local title = file:get_directive_property("TITLE")
        local tags = file:get_filetags()

        return Node:new({
            id = id,
            range = Range:new(
                { row = 0, column = 0, offset = 0 },
                { row = math.huge, column = math.huge, offset = math.huge }
            ),
            file = path,
            title = title,
            aliases = aliases,
            tags = tags,
            level = 0,
            linked = {},
        })
    end

    return nil
end

---@param path string
---@param headline OrgHeadline
---@return org-roam.core.database.Node|nil
local function make_section_node(path, headline)
    local id = headline:get_property("ID")
    if id then
        -- Get range that represents the section containing the headline
        -- which should be the parent from the query (section (headline) @headline)
        local range = Range:from_node(headline.headline:parent())
        local aliases_text = headline:get_property("ROAM_ALIASES")
        local aliases = aliases_text
            and parser_utils.parse_property_value(aliases_text)
            or {}
        local title = headline:get_title()

        -- NOTE: By default, this will get filetags and respect tag inheritance
        --       for nested headlines. If this is turned off in orgmode, then
        --       this only returns tags for the headline itself. We're going
        --       to use this and let that be a decision the user makes.
        local tags = headline:get_tags()
        table.sort(tags)

        return Node:new({
            id = id,
            range = range,
            file = path,
            title = title,
            aliases = aliases,
            tags = tags,
            level = headline:get_level(),
            linked = {},
        })
    end
end

---@param path string
---@param file OrgFile
---@return org-roam.core.database.Node[], org-roam.core.parser.Link[]
local function file_to_nodes_and_links(path, file)
    local file_node = make_file_node(path, file)

    ---@type {[1]: org-roam.core.parser.Range, [2]: org-roam.core.database.Node}[]
    local section_nodes = {}
    for _, headline in ipairs(file:get_headlines()) do
        local node = make_section_node(path, headline)
        if node then
            table.insert(section_nodes, { node.range, node })
        end
    end

    -- Build an interval tree from our section nodes
    ---@type org-roam.core.utils.IntervalTree|nil
    local section_node_tree
    if #section_nodes > 0 then
        ---@param t {[1]:org-roam.core.parser.Range, [2]:org-roam.core.database.Node}
        section_node_tree = IntervalTree:from_list(vim.tbl_map(function(t)
            return { t[1].start.offset, t[1].end_.offset, t[2] }
        end, section_nodes))
    end

    -- Figure out which node contains the link
    local links = {}
    for _, link in ipairs(file:get_links()) do
        local link_id = link.url:get_id()
        local range = Range:from_org_file_and_range(file, link.range)
        table.insert(links, Link:new({
            kind = "regular",
            range = range,
            path = link.url:to_string(),
            description = link.desc,
        }))

        -- For now, we only consider links that are
        -- standard org id links, nothing else. This
        -- differs from org-roam in Emacs, where they
        -- cache all links and use the non-id links
        -- externally.
        if link_id then
            ---@type org-roam.core.database.Node|nil
            local target_node
            if section_node_tree then
                target_node = section_node_tree:find_last_data({
                    range.start.offset,
                    range.end_.offset,
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
                local pos = vim.deepcopy(range.start)

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

    return nodes, links
end

---@class org-roam.core.scanner.ScanFileResults
---@field file OrgFile
---@field nodes org-roam.core.database.Node[]
---@field links org-roam.core.parser.Link[]

---Performs a one-time scan of a file, parsing the contents.
---@private
---@param path string
---@param cb fun(err:string|nil, results:org-roam.core.scanner.ScanFileResults|nil)
function M:__scan_file(path, cb)
    local plugin = require("org-roam")

    ---@type OrgPromise
    plugin.files
        :load_file(path)
        :next(function(file)
            local nodes, links = file_to_nodes_and_links(path, file)
            cb(nil, {
                file = file,
                nodes = nodes,
                links = links,
            })
            return file
        end)
        :catch(cb)
end

---Performs a one-time scan of a string, parsing the contents.
---@param contents string
---@param opts? {path?:string}
---@return org-roam.core.scanner.ScanFileResults
function M.scan(contents, opts)
    local OrgFile = require("orgmode.files.file")

    opts = opts or {}

    ---@type OrgFile
    local file = OrgFile:new({
        -- Unless a path is provided, we use an empty string, which should
        -- result in the string parser being used
        filename = opts.path or "",
        lines = vim.split(contents, "\n", { plain = true }),
    })

    file:parse()

    local nodes, links = file_to_nodes_and_links(
        opts.path or "<STRING>",
        file
    )
    return {
        file = file,
        nodes = nodes,
        links = links,
    }
end

return M
