-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- High-level utility functions leveraged by org-roam.
-------------------------------------------------------------------------------

local File = require("org-roam.core.file")
local IntervalTree = require("org-roam.core.utils.tree")
local OrgFile = require("orgmode.files.file")
local parse_property_value = require("org-roam.core.file.utils").parse_property_value
local unpack = require("org-roam.core.utils.table").unpack

---@class (exact) org-roam.utils.BufferCache
---@field file org-roam.core.File
---@field link_tree org-roam.core.utils.IntervalTree|nil
---@field node_tree org-roam.core.utils.IntervalTree|nil
---@field tick integer

---Internal cache of buffer -> cache of node ids used to look up
---nodes within buffers.
---@type table<integer, org-roam.utils.BufferCache>
local CACHE = {}

---Escape key used for `nvim_feedkeys()`.
local ESC_FEEDKEY = vim.api.nvim_replace_termcodes("<ESC>", true, false, true)

local M = {}

---@param bufnr integer
---@return org-roam.utils.BufferCache
local function get_buffer_cache(bufnr)
    local cache = CACHE[bufnr]
    ---@type integer
    local tick = vim.b[bufnr].changedtick

    local is_dirty = tick ~= (cache and cache.tick)

    -- If the buffer has changed or we had no cache, update
    if is_dirty or not cache then
        -- TODO: Can we just index by filename in the database
        --       and `find_by_index` to get nodes connected to the
        --       file represented by the buffer to build this
        --       up versus re-parsing the buffer?
        ---@type OrgFile
        local orgfile = OrgFile:new({
            filename = vim.api.nvim_buf_get_name(bufnr),
            lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
        })

        -- Trigger parsing of content, which should use string treesitter parser
        orgfile:parse()

        -- Convert file into roam version
        local file = File:from_org_file(orgfile)

        ---@type org-roam.core.utils.IntervalTree|nil
        local node_tree
        if not vim.tbl_isempty(file.nodes) then
            node_tree = IntervalTree:from_list(
            ---@param node org-roam.core.file.Node
                vim.tbl_map(function(node)
                    return {
                        node.range.start.offset,
                        node.range.end_.offset,
                        node,
                    }
                end, vim.tbl_values(file.nodes))
            )
        end

        ---@type org-roam.core.utils.IntervalTree|nil
        local link_tree
        if #file.links > 0 then
            link_tree = IntervalTree:from_list(
            ---@param link org-roam.core.file.Link
                vim.tbl_map(function(link)
                    return {
                        link.range.start.offset,
                        link.range.end_.offset,
                        link,
                    }
                end, file.links)
            )
        end

        -- Update cache pointer to reflect the current state
        CACHE[bufnr] = {
            file = file,
            link_tree = link_tree,
            node_tree = node_tree,
            tick = tick,
        }
    end

    return CACHE[bufnr]
end

---Retrieves the expression under cursor. In the case that
---an expression is not found or not within an orgmode buffer,
---the current word under cursor via `<cword>` is returned.
---@param opts? {win?:integer}
---@return string
function M.expr_under_cursor(opts)
    opts = opts or {}
    local bufnr = vim.api.nvim_win_get_buf(opts.win or 0)

    -- Figure out our word, trying out treesitter
    -- if we are in an orgmode buffer, otherwise
    -- defaulting back to the vim word under cursor
    local word = vim.fn.expand("<cword>")
    if vim.api.nvim_buf_get_option(bufnr, "filetype") == "org" then
        ---@type TSNode|nil
        local ts_node = vim.treesitter.get_node()
        if ts_node and ts_node:type() == "expr" then
            ---@type string
            word = vim.treesitter.get_node_text(ts_node, bufnr)
        end
    end
    return word
end

---Looks for a link under cursor. If it exists, the raw parsed link is returned.
---@param opts? {win?:integer}
---@return org-roam.core.file.Link|nil
function M.link_under_cursor(opts)
    opts = opts or {}
    local bufnr = vim.api.nvim_win_get_buf(opts.win or 0)
    local cursor = vim.api.nvim_win_get_cursor(opts.win or 0)
    local offset = vim.api.nvim_buf_get_offset(bufnr, cursor[1] - 1) + cursor[2]

    local cache = get_buffer_cache(bufnr)
    local tree = cache and cache.link_tree
    if tree then
        return tree:find_smallest_data({ offset, match = "contains" })
    end
end

---Returns a copy of the node under cursor of the current buffer.
---
---NOTE: This caches the state of the buffer (nodes), returning the pre-cached
---      result when possible. The cache is discarded whenever the current
---      buffer is detected as changed as seen via `b:changedtick`.
---
---@param cb fun(node:org-roam.core.file.Node|nil)
---@param opts? {win?:integer}
function M.node_under_cursor(cb, opts)
    opts = opts or {}
    local bufnr = vim.api.nvim_win_get_buf(opts.win or 0)
    local cursor = vim.api.nvim_win_get_cursor(opts.win or 0)
    local offset = vim.api.nvim_buf_get_offset(bufnr, cursor[1] - 1) + cursor[2]

    ---@return org-roam.core.file.Node|nil
    local function get_node()
        local cache = get_buffer_cache(bufnr)
        local tree = cache and cache.node_tree

        -- Find id of deepest node containing the offset
        if tree then
            return tree:find_smallest_data({ offset, match = "contains" })
        end
    end

    vim.schedule(function()
        cb(get_node())
    end)
end

---Converts a title into a slug that is acceptable in filenames.
---@param title string
---@return string
function M.title_to_slug(title)
    -- For conversion, we do the following steps:
    --
    -- 1. Convert anything not alphanumeric into an underscore
    -- 2. Remove consecutive underscores in favor of just one
    -- 3. Remove underscore at beginning
    -- 4. Remove underscore at end
    title = string.gsub(title, "%W", "_")
    title = string.gsub(title, "__", "_")
    title = string.gsub(title, "^_", "_")
    title = string.gsub(title, "_$", "_")
    return title
end

M.parse_prop_value = parse_property_value

---Wraps a value meant to be part of a proprty such that it can be quoted.
---This escapes " and \ characters.
---@param value string
---@return string
function M.wrap_prop_value(value)
    local text = string.gsub(string.gsub(value, "\\", "\\\\"), "\"", "\\\"")
    return text
end

---Searches an org file for a match with the specified `id`.
---
---The match could be an `OrgFile` (top-level property drawer) or an
---`OrgHeadline`. Returns `nil` if there is no match.
---
---@param file OrgFile
---@param id string
---@return OrgFile|OrgHeadline|nil
function M.find_id_match(file, id)
    if file:get_property("id") == id then
        return file
    else
        -- Search through all headlines to see if we have a match
        for _, headline in ipairs(file:get_headlines()) do
            if headline:get_property("id", false) == id then
                return headline
            end
        end

        -- Found nothing
        return
    end
end

---Opens the node in the specified window, defaulting to the current window.
---@param opts {node:org-roam.core.file.Node, win?:integer}
function M.goto_node(opts)
    local node = opts.node
    local win = opts.win or vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(win)
    vim.cmd.edit(node.file)

    local row = node.range.start.row + 1
    local col = node.range.start.column

    -- NOTE: We need to schedule to ensure the file has loaded
    --       into the buffer before we try to move the cursor!
    vim.schedule(function()
        vim.api.nvim_win_set_cursor(win, { row, col })
    end)
end

---@class org-roam.utils.Range
---@field start_row integer #starting row (one-indexed, inclusive)
---@field start_col integer #starting column (one-indexed, inclusive)
---@field end_row integer #end row (one-indexed, inclusive)
---@field end_col integer #end column (one-indexed, inclusive)

---Extracts visual selection (supports visual and linewise visual modes),
---returning lines and range. The range is 1-based and inclusive.
---
---If `buf` is provided, will select from that buffer, otherwise defaults to
---the current buffer.
---
---If `single_line` is true, will collapse all visual lines into a single line,
---filtering out empty lines and replacing newlines with spaces. The range will
---still represent the full range of the visual selection.
---
---From https://github.com/jackMort/ChatGPT.nvim/blob/df53728e05129278d6ea26271ec086aa013bed90/lua/chatgpt/utils.lua#L69
---@param opts? {buf?:integer, single_line?:boolean}
---@return string[] lines, org-roam.utils.Range[] ranges
function M.get_visual_selection(opts)
    opts = opts or {}
    local bufnr = opts.buf or 0

    -- Force a reset of visual selection, re-selecting it (gv), in order to get
    -- the markers '< and '> to map to the current selection instead of older
    vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)
    vim.api.nvim_feedkeys("gv", "x", false)
    vim.api.nvim_feedkeys(ESC_FEEDKEY, "n", true)

    local start_row, start_col = unpack(vim.api.nvim_buf_get_mark(bufnr, "<"))
    local end_row, end_col = unpack(vim.api.nvim_buf_get_mark(bufnr, ">"))
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row - 1, end_row, false)

    -- get whole buffer if there is no current/previous visual selection
    if start_row == 0 then
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        start_row = 1
        start_col = 0
        end_row = #lines
        end_col = #lines[#lines]
    end

    -- use 1-based indexing and handle selections made in visual line mode (see :help getpos)
    start_col = start_col + 1
    end_col = math.min(end_col, #lines[#lines] - 1) + 1

    -- shorten first/last line according to start_col/end_col
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
    lines[1] = string.sub(lines[1], start_col)

    -- If single line, we trim everything and collapse newlines into spaces
    if opts.single_line then
        local text = table.concat(vim.tbl_filter(function(line)
            return line ~= ""
        end, vim.tbl_map(function(line)
            return vim.trim(line)
        end, lines)), " ")
        lines = { text }
    end

    ---@type org-roam.utils.Range[]
    local ranges = {
        {
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
        },
    }

    return lines, ranges
end

return M
