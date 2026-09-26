-------------------------------------------------------------------------------
-- HIGHLIGHTER.LUA
--
-- Specific logic to perform specialized highlights within buffers.
-------------------------------------------------------------------------------

---Cache of hashed lines from a range to the extmarks as derived from the
---scratch buffer. This means that the start line and end line have not been
---adjusted to the destination range.
---@type {[string]: {[1]:integer, [2]:integer, [3]:integer, [4]:table}[]}
local CACHE = {}

local M = {}

---Determines extmarks for one or more ranges within a buffer as if they were orgmode filetype.
---@param buffer integer #buffer number or 0 for current buffer
---@param ranges {[1]:integer, [2]:integer}[] #list of ranges containing starting & ending lines (zero-based, end-exclusive)
---@param opts? {ephemeral?:boolean, namespace?:integer, no_cache?:boolean}
---@return {[1]:integer, [2]:integer, [3]:integer, [4]:table}[][]
function M.get_extmarks_for_ranges_as_org(buffer, ranges, opts)
    opts = opts or {}
    local all_extmarks = {}

    -- Create a scratch buffer where we will place the portion of our desired buffer's lines
    local scratch_buffer = vim.api.nvim_create_buf(false, true)
    assert(scratch_buffer ~= 0, "failed to create scratch buffer")

    -- Populate the scratch buffer
    local name = vim.fn.tempname() .. ".org"
    vim.api.nvim_buf_set_name(scratch_buffer, name)
    vim.api.nvim_set_option_value("filetype", "org", { buf = scratch_buffer })

    -- Create a temporary floating window to hold the scratch buffer.
    --
    -- NOTE: We do this instead of relying on `nvim_buf_call()` creating
    --       a new autocmd window because the window's height is locked
    --       to 5 rows, which means that any lines after the 5th will
    --       not have extmarks applied in view.
    local win = vim.api.nvim_open_win(scratch_buffer, false, {
        relative = "editor",
        row = 0,
        col = 0,
        width = vim.opt.columns:get(),
        height = vim.opt.lines:get(),
    })
    assert(win ~= 0, "failed to create scratch window")

    for _, range in ipairs(ranges) do
        local start = range[1]
        local end_ = range[2]

        local lines = vim.api.nvim_buf_get_lines(buffer, start, end_, false)
        local hash = vim.fn.sha256(table.concat(lines, "\n"))

        local extmarks = CACHE[hash]

        -- If we do not have a cached extmarks, fine new ones
        if opts.no_cache or not extmarks then
            vim.api.nvim_buf_set_lines(scratch_buffer, 0, -1, true, lines)

            -- Retrieve the global orgmode highlighter in order to support
            -- retrieving the extmarks from our scratch buffer
            local highlighter = require("orgmode").highlighter

            ---@diagnostic disable-next-line:invisible
            local ephemeral = highlighter._ephemeral

            -- For ephemeral to be false so we have extmarks available
            ---@diagnostic disable-next-line:invisible
            highlighter._ephemeral = false

            vim.api.nvim_buf_call(scratch_buffer, function()
                vim.cmd("filetype detect")
                vim.cmd("redraw!")
            end)

            -- Restore the ephemeral status to whatever it was before
            ---@diagnostic disable-next-line:invisible
            highlighter._ephemeral = ephemeral

            -- Read all highlights from the buffer (extmark_id, line, col, details), zero-indexed
            ---@type {[1]:integer, [2]:integer, [3]:integer, [4]:table}[]
            extmarks = vim.api.nvim_buf_get_extmarks(scratch_buffer, -1, 0, -1, {
                details = true,
            })

            -- Save the newly-evaluated extmarks
            if not opts.no_cache then
                CACHE[hash] = extmarks
            end
        end

        -- Create a copy so we don't modify the cached version
        extmarks = vim.deepcopy(extmarks)

        -- Translate the positions of the extmarks relative to our starting point
        -- and apply to the original buffer
        for _, extmark in ipairs(extmarks) do
            extmark[2] = extmark[2] + start

            ---@type {end_row:integer, ns_id:integer}
            local details = extmark[4]
            if details.end_row then
                details.end_row = details.end_row + start
            end

            -- Get the namespace using the one specified or the
            -- existing namespace from the extmarks
            details.ns_id = opts.namespace or details.ns_id
        end

        table.insert(all_extmarks, extmarks)
    end

    -- Close the scratch window
    vim.api.nvim_win_close(win, true)

    -- Delete the scratch buffer now that we're done with it
    vim.api.nvim_buf_delete(scratch_buffer, { force = true })

    return all_extmarks
end

---Applies conceal extmarks for org links within the given ranges.
---
---Treesitter-based conceal marks (from highlights.scm `#set! conceal`) are
---ephemeral and not captured by `nvim_buf_get_extmarks`. This function
---manually applies conceal marks for org links so they render properly
---in non-org buffers like the node buffer.
---@param buffer integer
---@param ranges {[1]:integer, [2]:integer}[]
---@param opts {ephemeral?:boolean, namespace?:integer}
local function apply_link_conceal(buffer, ranges, opts)
    local ns = opts.namespace or vim.api.nvim_create_namespace("org-roam-link-conceal")

    for _, range in ipairs(ranges) do
        local lines = vim.api.nvim_buf_get_lines(buffer, range[1], range[2], false)
        for i, line in ipairs(lines) do
            local row = range[1] + i - 1

            -- Match [[url][desc]] links: conceal [[ ]] ][ parts, highlight url and desc
            local pos = 1
            while pos <= #line do
                -- Find [[ opening
                local link_start = string.find(line, "%[%[", pos, false)
                if not link_start then
                    break
                end

                -- Find matching ]]
                local link_end = string.find(line, "%]%]", link_start + 2, false)
                if not link_end then
                    break
                end

                -- Check if this is a [[url][desc]] or [[url]] link
                local separator = string.find(line, "%]%[", link_start + 2, false)
                local has_desc = separator and separator < link_end

                local mark_opts = { ephemeral = opts.ephemeral or false }

                if has_desc then
                    -- Conceal [[ at start
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        ns,
                        row,
                        link_start - 1,
                        vim.tbl_extend("force", mark_opts, {
                            end_col = link_start + 1,
                            conceal = "",
                        })
                    )
                    -- Conceal url][ (from after [[ to after ][)
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        ns,
                        row,
                        link_start + 1,
                        vim.tbl_extend("force", mark_opts, {
                            end_col = separator + 1,
                            conceal = "",
                        })
                    )
                    -- Highlight desc
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        ns,
                        row,
                        separator + 1,
                        vim.tbl_extend("force", mark_opts, {
                            end_col = link_end - 1,
                            hl_group = "@org.hyperlink",
                        })
                    )
                    -- Conceal ]] at end
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        ns,
                        row,
                        link_end - 1,
                        vim.tbl_extend("force", mark_opts, {
                            end_col = link_end + 1,
                            conceal = "",
                        })
                    )
                else
                    -- [[url]] without description: conceal [[ and ]]
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        ns,
                        row,
                        link_start - 1,
                        vim.tbl_extend("force", mark_opts, {
                            end_col = link_start + 1,
                            conceal = "",
                        })
                    )
                    -- Highlight url
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        ns,
                        row,
                        link_start + 1,
                        vim.tbl_extend("force", mark_opts, {
                            end_col = link_end - 1,
                            hl_group = "@org.hyperlink",
                        })
                    )
                    vim.api.nvim_buf_set_extmark(
                        buffer,
                        ns,
                        row,
                        link_end - 1,
                        vim.tbl_extend("force", mark_opts, {
                            end_col = link_end + 1,
                            conceal = "",
                        })
                    )
                end

                pos = link_end + 2
            end
        end
    end
end

---Highlights range within a buffer using org filetype.
---@param buffer integer #buffer number or 0 for current buffer
---@param ranges {[1]:integer, [2]:integer}[] #list of ranges containing starting & ending lines (zero-based, end-exclusive)
---@param opts? {ephemeral?:boolean, namespace?:integer, no_cache?:boolean}
function M.highlight_ranges_as_org(buffer, ranges, opts)
    opts = opts or {}

    local extmarks_per_range = M.get_extmarks_for_ranges_as_org(buffer, ranges, {
        ephemeral = opts.ephemeral,
        namespace = opts.namespace,
        no_cache = opts.no_cache,
    })

    for _, extmarks in ipairs(extmarks_per_range) do
        for _, extmark in ipairs(extmarks) do
            local row = extmark[2]
            local col = extmark[3]
            local details = extmark[4]

            local ns = opts.namespace or details.ns_id
            details.ns_id = nil

            vim.api.nvim_buf_set_extmark(buffer, ns, row, col, details)
        end
    end

    -- Apply link conceal marks manually since treesitter conceal marks
    -- are ephemeral and not captured by nvim_buf_get_extmarks
    apply_link_conceal(buffer, ranges, {
        ephemeral = opts.ephemeral,
        namespace = opts.namespace,
    })
end

---Clears the cache of text to highlights.
function M.clear_cache()
    CACHE = {}
end

return M
