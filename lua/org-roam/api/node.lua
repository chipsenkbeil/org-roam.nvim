-------------------------------------------------------------------------------
-- NODE.LUA
--
-- Contains functionality tied to the roam node api.
-------------------------------------------------------------------------------

local io = require("org-roam.core.utils.io")
local log = require("org-roam.core.log")
local notify = require("org-roam.core.ui.notify")
local path_utils = require("org-roam.core.utils.path")
local Promise = require("orgmode.utils.promise")
local utils = require("org-roam.utils")

---General-purpose expansions tied to org roam.
---@param roam OrgRoam
---@return table<string, fun()>
local function make_expansions(roam)
    return {
        ["%r"] = function()
            return roam.config.directory
        end,
        ["%R"] = function()
            return vim.fs.normalize(vim.fn.resolve(roam.config.directory))
        end,
    }
end

---Target-specific expansions (keys only).
local TARGET_EXPANSION_KEYS = {
    SEP   = "%[sep]",
    SLUG  = "%[slug]",
    TITLE = "%[title]",
}

---@param roam OrgRoam
---@param content string
---@param expansions? {[string]:fun():string}
---@return string
local function fill_expansions(roam, content, expansions)
    for expansion, compiler in pairs(expansions or make_expansions(roam)) do
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

---Retrieves the id of the noude under cursor.
---@param opts? {win?:integer}
---@return OrgPromise<string|nil>
local function node_id_under_cursor(opts)
    opts = opts or {}

    return Promise.new(function(resolve)
        utils.node_under_cursor(function(node)
            resolve(node and node.id)
        end, { win = opts.win })
    end)
end

---Retrieves the id of the noude under cursor.
---@param opts? {timeout?:integer, win?:integer}
---@return string|nil
local function node_id_under_cursor_sync(opts)
    opts = opts or {}
    return node_id_under_cursor(opts):wait(opts.timeout)
end

---@param roam OrgRoam
---@param file? OrgFile
---@param opts? {title?:string}
---@return fun(target:string):string
local function make_target_expander(roam, file, opts)
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
        return fill_expansions(roam, target, expansions)
    end
end

---Construct org-roam template with custom expansions applied.
---@param roam OrgRoam
---@param template_opts OrgCaptureTemplateOpts
---@param opts? {origin?:string, title?:string}
---@return OrgCaptureTemplate
local function build_template(roam, template_opts, opts)
    opts = opts or {}
    local Template = require("orgmode.capture.template")
    local template = Template:new(template_opts)

    -- Resolve our general expansions in the target
    if template.target then
        template.target = fill_expansions(roam, template.target)
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

        -- Make a target expander so we can fully resolve the target, but if
        -- there is no title, we use empty string so we don't prompt
        local expander = make_target_expander(roam, nil, { title = opts.title or "" })

        -- Check if the target exists by getting stat of it; if no error, it exists
        local exists = vim.fn.filereadable(expander(target)) == 1

        -- Fill in org-roam general expansions for our content, and if the
        -- file does not exist then add our prefix
        content = fill_expansions(roam, content)
        if not exists then
            local prefix = {
                ":PROPERTIES:",
                ":ID: " .. require('orgmode.org.id').new(),
            }

            if opts.origin then
                table.insert(prefix, ":ROAM_ORIGIN: " .. opts.origin)
            end

            table.insert(prefix, ":END:")

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
---@param roam OrgRoam
---@param opts? {origin?:string, title?:string}
---@return OrgCaptureTemplates
local function build_templates(roam, opts)
    opts = opts or {}
    local Templates = require("orgmode.capture.templates")

    -- Build our templates such that they include titles and org-ids
    local templates = Templates:new(roam.config.templates)
    for key, template in pairs(roam.config.templates) do
        templates.templates[key] = build_template(roam, template, opts)
    end

    return templates
end

---@param roam OrgRoam
---@param opts? {title?:string}
---@return fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
local function make_on_pre_refile(roam, opts)
    opts = opts or {}

    ---@param _ OrgCapture
    ---@param capture_opts OrgProcessCaptureOpts
    return function(_, capture_opts)
        local expander = make_target_expander(roam, capture_opts.source_file, {
            title = opts.title,
        })

        local target = capture_opts.template.target
        if target then
            capture_opts.template.target = expander(target)
        end
    end
end

---@param roam OrgRoam
---@param cb fun(id:org-roam.core.database.Id|nil)
---@return fun(capture:OrgCapture, opts:OrgProcessCaptureOpts)
local function make_on_post_refile(roam, cb)
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
        roam.database:load_file({ path = filename })
            :next(function(...)
                cb(id)
                return ...
            end)
            :catch(function(_) cb(nil) end)
    end
end

---@param roam OrgRoam
---@param opts {origin:string|nil, title:string|nil}
---@param cb fun(id:org-roam.core.database.Id|nil)
local function roam_capture_immediate(roam, opts, cb)
    local template = build_template(roam, {
        target = roam.config.immediate.target,
        template = roam.config.immediate.template,
    }, opts)

    ---@param content string[]|nil
    template:compile():next(function(content)
        if not content then
            return notify.echo_info("canceled")
        end

        local content_str = table.concat(content, "\n")

        -- Target needs to have target-specific expansions filled
        local expander = make_target_expander(roam, nil, opts)
        local path = expander(template.target)

        io.write_file(path, content_str, function(err)
            if err then
                notify.error(err)
                log.error(err)
                return
            end

            vim.schedule(function()
                roam.database:load_file({ path = path }):next(function(result)
                    local file = result.file

                    -- Look for the id of the newly-captured file
                    local id = file:get_property("id")

                    -- If we don't find a file-level node, look for headline nodes
                    if not id then
                        for _, headline in ipairs(file:get_headlines()) do
                            id = headline:get_property("id", false)
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

---@param roam OrgRoam
---@param opts? {immediate?:boolean, origin?:string, title?:string}
---@param cb? fun(id:org-roam.core.database.Id|nil)
local function roam_capture(roam, opts, cb)
    opts = opts or {}
    cb = cb or function() end

    if roam.config.capture.include_origin and not opts.origin then
        opts.origin = node_id_under_cursor_sync()
    end

    if opts.immediate then
        roam_capture_immediate(roam, opts, cb)
    else
        local templates = build_templates(roam, {
            origin = opts.origin,
            title = opts.title,
        })
        local on_pre_refile = make_on_pre_refile(opts)
        local on_post_refile = make_on_post_refile(roam, cb)
        roam.database:files():next(function(files)
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

---@param roam OrgRoam
---@param opts? {immediate?:boolean, origin?:string, title?:string, ranges?:org-roam.utils.Range[]}
---@param cb? fun(id:org-roam.core.database.Id|nil)
local function roam_insert(roam, opts, cb)
    opts = opts or {}
    local winnr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()
    local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(winnr)

    ---@param id org-roam.core.database.Id|nil
    local function do_cb(id)
        if type(cb) == "function" then
            vim.schedule(function()
                cb(id)
            end)
        end
    end

    ---@param id org-roam.core.database.Id
    local function insert_link(id)
        local node = roam.database:get_sync(id)
        if not node then
            log.fmt_warn("node %s does not exist, so not inserting link", id)
            return
        end

        -- If the buffer has changed since we started, we don't want to
        -- inject in the wrong place, so instead report an error and exit
        if vim.api.nvim_buf_get_changedtick(bufnr) ~= changedtick then
            local msg = "buffer " .. bufnr .. " has changed, so canceling link insertion"
            log.warn(msg)
            notify.echo_warning(msg)
            return
        end

        -- Ignore errors that occur here when resetting ourselves
        -- to the appropriate window and repositioning the cursor
        pcall(vim.api.nvim_set_current_win, winnr)
        pcall(vim.api.nvim_win_set_cursor, winnr, cursor)

        local bufnr = vim.api.nvim_win_get_buf(winnr)
        local start_row = cursor[1] - 1
        local start_col = cursor[2]
        local end_row = start_row
        local end_col = start_col

        -- If we have a range, use that for setting text replacement
        if opts.ranges then
            -- For each range, we remove it (except first); do so
            -- in reverse so we don't have to recalcuate the ranges
            for i = #opts.ranges, 1, -1 do
                start_row = opts.ranges[i].start_row - 1
                start_col = opts.ranges[i].start_col - 1
                end_row = opts.ranges[i].end_row - 1
                end_col = opts.ranges[i].end_col -- No -1 because this is exclusive

                -- Don't remove the first range as we will replace instead
                if i == 1 then break end

                -- Clear the text of this range
                vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, {})
            end
        end

        -- Replace or insert the link
        vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, {
            string.format("[[id:%s][%s]]", node.id, node.title),
        })

        -- Force ourselves back into normal mode
        vim.cmd.stopinsert()
    end

    roam.ui.select_node({
        allow_select_missing = true,
        auto_select = opts.immediate,
        init_input = opts.title,
    }, function(node)
        if node.id then
            insert_link(node.id)
            do_cb(node.id)
            return
        end

        if roam.config.capture.include_origin and not opts.origin then
            opts.origin = node_id_under_cursor_sync({ win = winnr })
        end

        roam_capture(roam, {
            immediate = opts.immediate,
            origin = opts.origin,
            title = node.label,
        }, function(id)
            do_cb(id)
            if id then
                insert_link(id)
                return
            end
        end)
    end)
end

---@param roam OrgRoam
---@param opts? {origin?:string, title?:string}
---@param cb? fun(id:org-roam.core.database.Id|nil)
local function roam_find(roam, opts, cb)
    opts = opts or {}
    local winnr = vim.api.nvim_get_current_win()

    ---@param id org-roam.core.database.Id|nil
    local function do_cb(id)
        if type(cb) == "function" then
            vim.schedule(function()
                cb(id)
            end)
        end
    end

    ---@param id org-roam.core.database.Id
    local function visit_node(id)
        local node = roam.database:get_sync(id)
        if not node then
            log.fmt_warn("node %s does not exist, so not visiting", id)
            return
        end

        -- Try to switch back to the original window, but ignore errors
        -- in case we did something like close that window inbetween
        pcall(vim.api.nvim_set_current_win, winnr)

        vim.cmd("edit! " .. node.file)

        -- Force ourselves back into normal mode
        vim.cmd.stopinsert()
    end

    roam.ui.select_node({
        allow_select_missing = true,
        init_input = opts.title,
    }, function(node)
        if node.id then
            visit_node(node.id)
            do_cb(node.id)
            return
        end

        if roam.config.capture.include_origin and not opts.origin then
            opts.origin = node_id_under_cursor_sync({ win = winnr })
        end

        roam_capture(roam, {
            origin = opts.origin,
            title = node.label,
        }, function(id)
            do_cb(id)
            if id then
                visit_node(id)
                return
            end
        end)
    end)
end

---@param roam OrgRoam
---@return org-roam.api.NodeApi
return function(roam)
    ---@class org-roam.api.NodeApi
    local M = {}

    ---Creates a node if it does not exist, and restores the current window
    ---configuration upon completion.
    ---@param opts? {immediate?:boolean, origin?:string, title?:string}
    ---@param cb? fun(id:org-roam.core.database.Id|nil)
    function M.capture(opts, cb)
        return roam_capture(roam, opts, cb)
    end

    ---Creates a node if it does not exist, and inserts a link to the node
    ---at the current cursor location.
    ---
    ---If `immediate` is true, no template will be used to create a node and
    ---instead the node will be created with the minimum information and the
    ---link injected without navigating to another buffer.
    ---
    ---If `ranges` is provided, will replace the given ranges within the buffer
    ---versus inserting at point.
    ---where everything uses 1-based indexing and inclusive.
    ---@param opts? {immediate?:boolean, origin?:string, title?:string, ranges?:org-roam.utils.Range[]}
    ---@param cb? fun(id:org-roam.core.database.Id|nil)
    function M.insert(opts, cb)
        return roam_insert(roam, opts, cb)
    end

    ---Creates a node if it does not exist, and visits the node.
    ---@param opts? {origin?:string, title?:string}
    ---@param cb? fun(id:org-roam.core.database.Id|nil)
    function M.find(opts, cb)
        return roam_find(roam, opts, cb)
    end

    return M
end
