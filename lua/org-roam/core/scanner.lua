-------------------------------------------------------------------------------
-- SCANNER.LUA
--
-- Logic to scan for org files, parse them, translate into nodes, and insert
-- into a database.
-------------------------------------------------------------------------------

local Emitter = require("org-roam.core.utils.emitter")
local Node    = require("org-roam.core.database.node")
local parser  = require("org-roam.core.parser")
local utils   = require("org-roam.core.utils")

local uv      = vim.loop

---@class org-roam.core.Scanner
---@field private emitter org-roam.core.utils.Emitter #used to emit scans
---@field private paths string[] #paths to scan
---@field private running boolean #true if scanning paths
local M       = {}
M.__index     = M

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

---Register callback to be invoked when a file is scanned.
---This can be triggered during the initial scan or when a file is changed.
---@param cb fun(scan:{path:string, nodes:org-roam.core.database.Node[]})
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

    for _, path in ipairs(self.paths) do
        if vim.fn.isdirectory(path) == 1 then
            self:__scan_dir(path, function(err, results)
                scan_cnt = scan_cnt + 1
                if err then
                    self.emitter:emit("scanner:error", err)
                end

                if results then
                    self.emitter:emit("scanner:scan", {
                        path = results.entry.path,
                        nodes = results.nodes,
                    })
                end
                if_done_then_emit()
            end)
        else
            self:__scan_file(path, function(err, nodes)
                scan_cnt = scan_cnt + 1
                if err then
                    self.emitter:emit("scanner:error", err)
                end

                if nodes then
                    self.emitter:emit("scanner:scan", {
                        path = path,
                        nodes = nodes,
                    })
                end
                if_done_then_emit()
            end)
        end
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

---Performs a one-time scan of a directory, parsing each org file found,
---invoking the provided callback once per file.
---@private
---@param path string
---@param cb fun(err:string|nil, results:{entry:org-roam.core.utils.io.WalkEntry, nodes:org-roam.core.database.Node[]}|nil)
function M:__scan_dir(path, cb)
    local it = utils.io.walk(path, { depth = math.huge })
        :filter(function(entry) return entry.type == "file" end)
        :filter(function(entry) return vim.endswith(entry.filename, ".org") end)

    local function do_parse()
        if self.running and it:has_next() then
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

---Performs a one-time scan of a file, parsing it,
---and invoking the provided callback once per file.
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

        -- Second, build an interval tree of our sections so we
        -- can look up tags that apply
        local tags_tree = utils.tree.interval:from_list(vim.tbl_map(function(section)
            ---@cast section org-roam.core.parser.Section
            return {
                section.range.start.offset,
                section.range.end_.offset,
                section.heading:tag_list(),
            }
        end, file.sections))

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
                    and utils.parser.parse_property_value(aliases_text)
                    or {}

                local title = heading.item and vim.trim(heading.item:text()) or nil

                -- Build up tags for the heading, which is a combination of
                -- the file tags, any tags from ancestor headings, and
                -- then this heading
                local tags = vim.deepcopy(file.filetags)
                local nodes = tags_tree:find_all({
                    section.range.start.offset,
                    section.range.end_.offset,
                    match = "contains",
                })
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

        ---@type org-roam.core.database.Node[]
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
