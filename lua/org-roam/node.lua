-------------------------------------------------------------------------------
-- NODE.LUA
--
-- Contains functionality tied to org-roam nodes.
-------------------------------------------------------------------------------

local CONFIG = require("org-roam.config")
local db = require("org-roam.database")
local io = require("org-roam.core.utils.io")
local log = require("org-roam.core.log")
local notify = require("org-roam.core.ui.notify")
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

---@class org-roam.NodeApi
local M = {}

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

---@param file? OrgFile
---@param opts? {title?:string}
---@return fun(target:string):string
local function make_target_expander(file, opts)
    opts = opts or {}
    local title, sep, slug

    ---@return string
    local function get_title()
        title = title
            or (file and file:get_directive("title"))
            or opts.title
            or (file and vim.fn.fnamemodify(file.filename, ":t:r"))
            or vim.fn.input("Enter title for node: ")
        return title
    end

    local expansions = {
        [TARGET_EXPANSION_KEYS.TITLE] = get_title,
        [TARGET_EXPANSION_KEYS.SEP] = function()
            sep = sep or path_utils.separator()
            return sep
        end,
        [TARGET_EXPANSION_KEYS.SLUG] = function()
            slug = slug or utils.title_to_slug(get_title())
            return slug
        end,
    }

    return function(target)
        return fill_expansions(target, expansions)
    end
end

---Construct org-roam template with custom expansions applied.
---@param template_opts OrgCaptureTemplateOpts
---@param opts? {title?:string}
---@return OrgCaptureTemplate
local function build_template(template_opts, opts)
    opts = opts or {}
    local Template = require("orgmode.capture.template")
    local template = Template:new(template_opts)

    -- Resolve our general expansions in the target
    if template.target then
        template.target = fill_expansions(template.target)
    end

    -- Always include the entire capture contents, not just
    -- the headline, to make sure the generated property
    -- drawer and title directive are included
    template.whole_file = true

    ---@param content string
    ---@param content_type "content"|"target"
    return template:on_compile(function(content, content_type)
        -- Ignore types other than content
        if content_type ~= "content" then return content end

        -- Figure out our template's target
        local target = template.target or require("orgmode.config").org_default_notes_file
        template.target = target

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

---Construct org-roam templates with custom expansions applied.
---@param opts? {title?:string}
---@return OrgCaptureTemplates
local function build_templates(opts)
    opts = opts or {}
    local Templates = require("orgmode.capture.templates")

    -- Build our templates such that they include titles and org-ids
    local templates = {}
    for key, template in pairs(CONFIG.templates) do
        templates[key] = build_template(template, opts)
    end

    return Templates:new(templates)
end

---@param opts? {title?:string}
---@return fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
local function make_on_pre_refile(opts)
    opts = opts or {}

    ---@param _ OrgCapture
    ---@param capture_opts OrgProcessCaptureOpts
    return function(_, capture_opts)
        local expander = make_target_expander(capture_opts.source_file, {
            title = opts.title,
        })

        local target = capture_opts.template.target
        if target then
            capture_opts.template.target = expander(target)
        end
    end
end

---@param cb fun(id:org-roam.core.database.Id|nil)
---@return fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
local function make_on_post_refile(cb)
    ---@param capture_opts OrgProcessCaptureOpts
    return function(_, capture_opts)
        -- Look for the id of the newly-captured ram node
        local id = capture_opts.source_file:get_property("id")

        -- If we don't find a file-level node, look for headline nodes
        if not id then
            for _, headline in ipairs(capture_opts.source_file:get_headlines()) do
                id = headline:get_property("id", false)
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
---@param opts? {immediate?:boolean, title?:string}
---@param cb? fun(id:org-roam.core.database.Id|nil)
function M.capture(opts, cb)
    opts = opts or {}
    cb = cb or function() end

    if opts.immediate then
        M.__capture_immediate(opts, cb)
    else
        local templates = build_templates({ title = opts.title })
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
end

---@private
---@param opts {title?:string}
---@param cb fun(id:org-roam.core.database.Id|nil)
function M.__capture_immediate(opts, cb)
    local template = build_template({
        target = CONFIG.immediate.target,
        template = CONFIG.immediate.template,
    }, {
        title = opts.title,
    })

    ---@param content string[]|nil
    template:compile():next(function(content)
        if not content then
            return notify.echo_info("canceled")
        end

        local content_str = table.concat(content, "\n")

        -- Target needs to have target-specific expansions filled
        local expander = make_target_expander(nil, opts)
        local path = expander(template.target)

        io.write_file(path, content_str, function(err)
            if err then
                notify.error(err)
                log.error(err)
                return
            end

            vim.schedule(function()
                db:load_file({ path = path }):next(function(result)
                    local file = result.file

                    -- Look for the id of the newly-captured file
                    local id = file:get_property("ID")

                    -- If we don't find a file-level node, look for headline nodes
                    if not id then
                        for _, headline in ipairs(file:get_headlines()) do
                            id = headline:get_property("ID", false)
                            if id then break end
                        end
                    end

                    -- Trigger the callback regardless of whether we got an id
                    vim.schedule(function() cb(id) end)

                    return file
                end)
            end)
        end)
    end)
end

---Creates a node if it does not exist, and inserts a link to the node
---at the current cursor location.
---
---If `immediate` is true, no template will be used to create a node and
---instead the node will be created with the minimum information and the
---link injected without navigating to another buffer.
---@param opts? {immediate?:boolean, title?:string}
function M.insert(opts)
    opts = opts or {}
    local winnr = vim.api.nvim_get_current_win()
    local cursor = vim.api.nvim_win_get_cursor(winnr)

    ---@param id org-roam.core.database.Id
    local function insert_link(id)
        local node = db:get_sync(id)
        if not node then
            log.fmt_warn("node %s does not exist, so not inserting link", id)
            return
        end

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

    select_node({
        allow_select_missing = true,
        auto_select = opts.immediate,
        init_input = opts.title,
    }, function(node)
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
---@param opts? {title?:string}
function M.find(opts)
    opts = opts or {}
    local winnr = vim.api.nvim_get_current_win()

    ---@param id org-roam.core.database.Id
    local function visit_node(id)
        local node = db:get_sync(id)
        if not node then
            log.fmt_warn("node %s does not exist, so not visiting", id)
            return
        end

        local ok = pcall(vim.api.nvim_set_current_win, winnr)
        if not ok then return end
        vim.cmd("edit! " .. node.file)

        -- Force ourselves back into normal mode
        vim.cmd("stopinsert")
    end

    select_node({
        allow_select_missing = true,
        init_input = opts.title,
    }, function(node)
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
