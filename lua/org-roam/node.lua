-------------------------------------------------------------------------------
-- NODE.LUA
--
-- Contains functionality tied to org-roam nodes.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")
local db = require("org-roam.database")
local io = require("org-roam.core.utils.io")
local path_utils = require("org-roam.core.utils.path")
local select_node = require("org-roam.ui.select-node")
local utils = require("org-roam.utils")

---General-purpose expansions tied to org roam.
local EXPANSIONS = {
    ["%r"] = function()
        return CONFIG.directory
    end,
    ["%R"] = function()
        return vim.fs.normalize(vim.fn.resolve(CONFIG.directory))
    end,
}

---Target-specific expansions (keys only).
local TARGET_EXPANSION_KEYS = {
    SEP   = "%[sep]",
    SLUG  = "%[slug]",
    TITLE = "%[title]",
}

---@param content string
---@param expansions? {[string]:fun():string}
---@return string
local function fill_expansions(content, expansions)
    for expansion, compiler in pairs(expansions or EXPANSIONS) do
        if string.match(content, vim.pesc(expansion)) then
            content = string.gsub(content, vim.pesc(expansion), vim.pesc(compiler()))
        end
    end
    return content
end

---@class org-roam.NodeApi
local M = {}

---@param s string
---@param ... string|string[]
local function string_contains_one_of(s, ...)
    ---@type string[]
    local candidates = vim.tbl_flatten({ ... })
    for _, c in ipairs(candidates) do
        if string.match(s, vim.pesc(c)) then
            return true
        end
    end
    return false
end

---Construct org-roam templates with custom expansions applied.
---Returns `nil` if requested input and received nothing.
---@param opts? {title?:string}
---@return OrgCaptureTemplates
local function build_templates(opts)
    opts = opts or {}
    local Templates = require("orgmode.capture.templates")

    -- Build our templates such that they include titles and org-ids
    ---@type OrgCaptureTemplates
    local templates = Templates:new(CONFIG.templates)
    for key, template in pairs(templates.templates) do
        -- Resolve our general expansions in the target
        if template.target then
            template.target = fill_expansions(template.target)
        end

        -- Always include the entire capture contents, not just
        -- the headline, to make sure the generated property
        -- drawer and title directive are included
        template.whole_file = true

        -- Each template should prefix with an org-roam id
        ---@param content string
        ---@param type "content"|"target"
        templates[key] = template:on_compile(function(content, type)
            -- Only handle content with our compile logic
            if type ~= "content" then return content end

            -- Figure out our template's target
            local target = template.target
                or require("orgmode.config").org_default_notes_file

            -- Check if the target exists by getting stat of it; if no error, it exists
            local exists = not io.stat_sync(target)

            -- Fill in org-roam general expansions for our content, and if the
            -- file does not exist then add our prefix
            content = fill_expansions(content)
            if not exists then
                local prefix = {
                    ":PROPERTIES:",
                    ":ID: " .. require('orgmode.org.id').new(),
                    ":END:",
                }

                -- Grab the title, which if it does not exist and we detect
                -- that we need it, we will prompt for it
                local title = opts.title
                if not title and string_contains_one_of(template.target, {
                        TARGET_EXPANSION_KEYS.TITLE,
                        TARGET_EXPANSION_KEYS.SLUG,
                    }) then
                    title = vim.fn.input("Enter title for node: ")

                    -- If we did not get a title, return nil to cancel
                    if vim.trim(title) == "" then
                        return
                    end
                end

                -- If we have a title specified, include it
                if title then
                    table.insert(prefix, "#+TITLE: " .. title)
                end

                -- Prepend our prefix ensuring blank line between it and content
                content = table.concat(prefix, "\n") .. "\n\n" .. content
            end

            return content
        end)
    end

    return templates
end

---@param opts? {title?:string}
---@return fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
local function make_on_pre_refile(opts)
    opts = opts or {}

    ---@param _ OrgCapture
    ---@param capture_opts OrgProcessCaptureOpts
    return function(_, capture_opts)
        local title = capture_opts.source_file:get_directive("title")
            or opts.title
            or vim.fn.fnamemodify(capture_opts.source_file.filename, ":t:r")
        local slug = utils.title_to_slug(title)

        local expansions = {
            [TARGET_EXPANSION_KEYS.TITLE] = function()
                return title
            end,
            [TARGET_EXPANSION_KEYS.SEP] = function()
                return path_utils.separator()
            end,
            [TARGET_EXPANSION_KEYS.SLUG] = function()
                return slug
            end,
        }

        local target = capture_opts.template.target
        if target then
            -- Fill in our custom target-only expansions
            capture_opts.template.target = fill_expansions(
                target,
                expansions
            )
        end
    end
end

---@param cb fun(id:org-roam.core.database.Id|nil)
---@return fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
local function make_on_post_refile(cb)
    ---@param capture_opts OrgProcessCaptureOpts
    return function(_, capture_opts)
        -- Look for the id of the newly-captured ram node
        local id = capture_opts.source_file:get_property("ID")

        -- If we don't find a file-level node, look for headline nodes
        if not id then
            for _, headline in ipairs(capture_opts.source_file:get_headlines()) do
                id = headline:get_property("ID", false)
                if id then break end
            end
        end

        -- Reload the file that was written due to a refile
        local filename = capture_opts.destination_file.filename
        db:load_file({ path = filename })
            :next(function(...)
                cb(id)
                return ...
            end)
            :catch(function(_) cb(nil) end)
    end
end

---Creates a node if it does not exist, and restores the current window
---configuration upon completion.
---@param opts? {title?:string, immediate?:boolean}
---@param cb? fun(id:org-roam.core.database.Id|nil)
function M.capture(opts, cb)
    opts = opts or {}
    cb = cb or function() end

    local templates = build_templates(opts)
    local on_pre_refile = make_on_pre_refile(opts)
    local on_post_refile = make_on_post_refile(cb)

    db:files():next(function(files)
        local Capture = require("orgmode.capture")
        local capture = Capture:new({
            files = files,
            templates = templates,
            on_pre_refile = on_pre_refile,
            on_post_refile = on_post_refile,
        })

        return capture:prompt()
    end)
end

---Creates a node if it does not exist, and inserts a link to the node
---at the current cursor location.
---
---If `immediate` is true, no template will be used to create a node and
---instead the node will be created with the minimum information and the
---link injected without navigating to another buffer.
---@param opts? {immediate?:boolean}
function M.insert(opts)
    opts = opts or {}
    local winnr = vim.api.nvim_get_current_win()
    local cursor = vim.api.nvim_win_get_cursor(winnr)

    ---@param id org-roam.core.database.Id
    local function insert_link(id)
        local node = db:get_sync(id)

        if node then
            local ok = pcall(vim.api.nvim_set_current_win, winnr)
            if not ok then return end

            -- Ignore errors that occur here
            pcall(vim.api.nvim_win_set_cursor, winnr, cursor)

            local bufnr = vim.api.nvim_win_get_buf(winnr)
            local row = cursor[1] - 1
            local col = cursor[2]
            vim.api.nvim_buf_set_text(bufnr, row, col, row, col, {
                string.format("[[id:%s][%s]]", node.id, node.title)
            })

            -- Force ourselves back into normal mode
            vim.cmd("stopinsert")
        end
    end

    select_node({ allow_select_missing = true }, function(node)
        if node.id then
            insert_link(node.id)
            return
        end

        M.capture({ title = node.label, immediate = opts.immediate }, function(id)
            if id then
                insert_link(id)
                return
            end
        end)
    end)
end

---Creates a node if it does not exist, and visits the node.
function M.find()
    local winnr = vim.api.nvim_get_current_win()

    ---@param id org-roam.core.database.Id
    local function visit_node(id)
        local node = db:get_sync(id)

        if node then
            local ok = pcall(vim.api.nvim_set_current_win, winnr)
            if not ok then return end
            vim.cmd("edit! " .. node.file)

            -- Force ourselves back into normal mode
            vim.cmd("stopinsert")
        end
    end

    select_node({ allow_select_missing = true }, function(node)
        if node.id then
            visit_node(node.id)
            return
        end

        M.capture({ title = node.label }, function(id)
            if id then
                visit_node(id)
                return
            end
        end)
    end)
end

return M
