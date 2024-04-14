-------------------------------------------------------------------------------
-- COMPLETION.LUA
--
-- Contains functionality tied to roam completion api.
-------------------------------------------------------------------------------

local db = require("org-roam.database")
local Promise = require("orgmode.utils.promise")
local utils = require("org-roam.utils")

local M = {}

---Opens a dialog to select a node based on the expression under the cursor
---and replace the expression with a link to the selected node. If there is
---only one choice, this will automatically inject the link without bringing
---up the selection dialog.
---
---This implements the functionality of both:
---
---* `org-roam-complete-link-at-point`
---* `org-roam-complete-everywhere`
---@param opts? {win?:integer}
---@return OrgPromise<boolean>
function M.complete_node_under_cursor(opts)
    opts = opts or {}
    local winnr = opts.win or vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_win_get_buf(winnr)

    -- Figure out our selection range and input
    -- to feed into our dialog based on whether
    -- we are on a link or completing an expression
    local selection = ""

    ---@type string|nil
    local input

    local link = utils.link_under_cursor({ win = winnr })
    if link then
        local cursor = vim.api.nvim_win_get_cursor(winnr)
        local row = cursor[1] - 1 -- make zero-indexed
        local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]

        selection = string.sub(
            line,
            link.range.start.column + 1,
            link.range.end_.column + 1
        )

        -- Set initial input to be the link's existing path,
        -- stripping id: if already starting with that
        input = vim.trim(link.path)
        if vim.startswith(input, "id:") then
            input = string.sub(input, 4)
        end
    else
        selection = utils.expr_under_cursor({ win = winnr })
        input = selection
    end

    return Promise.new(function(resolve)
        require("org-roam.ui.select-node")({
            auto_select = true,
            init_input = input,
        }, function(choice)
            local node = db:get_sync(choice.id)
            if not node then
                return resolve(false)
            end

            -- Get our cursor position
            local cursor = vim.api.nvim_win_get_cursor(winnr)

            -- Row & column are now zero-indexed
            local row = cursor[1] - 1
            local col = cursor[2]

            -- We can safely assume that a line of text exists here
            local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]

            -- Continue searching through line until we find the match
            -- that overlaps with our cursor position
            ---@type integer|nil
            local i = 0
            while i < string.len(line) do
                i = string.find(line, selection, i + 1, true)
                if i == nil then break end

                -- Check if the current match contains the cursor column
                if i - 1 <= col and i - 1 + #selection > col then
                    col = i - 1
                    break
                end
            end

            -- Insert text representing the new link only if we found a match
            if i == nil then
                resolve(false)
                return
            end

            -- Replace the text (this will place us into insert mode)
            vim.api.nvim_buf_set_text(bufnr, row, col, row, col + #selection, {
                string.format("[[id:%s][%s]]", node.id, choice.label)
            })

            -- Force ourselves back into normal mode
            vim.cmd.stopinsert()

            -- Mark as successful
            resolve(true)
        end, function()
            resolve(false)
        end)
    end)
end

return M
