-------------------------------------------------------------------------------
-- COMPLETION.LUA
--
-- Contains functionality tied to org-roam completion.
-------------------------------------------------------------------------------

local async = require("org-roam.core.utils.async")
local database = require("org-roam.database")
local utils = require("org-roam.utils")

local M = {}

---Function used to interface with the complete function.
---
---This will perform completion by search for nodes that start with the
---current `arg_lead` based on their id, title, or alias.
---
---@param arg_lead string #leading portion of the argument being completed
---@param cmd_line string #entire command line
---@param cursor_pos integer #cursor position in cmdline (byte index)
---@return string #candidates separated by newline
function M.CompleteNode(arg_lead, cmd_line, cursor_pos)
    local db = database()

    print("complete")
    return table.concat({
        string.format("%s-1", arg_lead),
        string.format("%s-2", arg_lead),
        string.format("%s-3", arg_lead),
    }, "\n")
    --[[
    -- Hack: Monkey-patch buffer keymap upon the first completion (<Tab>)
    -- TODO: This is taken from dap.lua, which uses nvim-cmp plugin.
    --       Since this needs to be a standalone (beyond orgmode), we
    --       need to figure out how to do this ourselves.
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_option(bufnr, "filetype", "dapui_eval_input")
    cmp.setup.buffer({ enabled = true })
    vim.keymap.set("i", "<Tab>", function()
        if cmp.visible() then
            cmp.select_next_item()
        else
            cmp.complete()
        end
    end, { buffer = bufnr })
    vim.keymap.set("i", "<S-Tab>", function()
        if cmp.visible() then cmp.select_prev_item() end
    end, { buffer = bufnr })

    return "" ]]
end

---Opens a dialog to select a node based on the expression under the cursor
---and replace the expression with a link to the selected node. If there is
---only one choice, this will automatically inject the link without bringing
---up the selection dialog.
---
---This implements the functionality of both:
---
---* `org-roam-complete-link-at-point`
---* `org-roam-complete-everywhere`
function M.complete_node_under_cursor()
    local db = database()
    local word = utils.expr_under_cursor()
    local is_empty_link = word == "[[]]"
    local winnr = vim.api.nvim_get_current_win()
    local bufnr = vim.api.nvim_get_current_buf()

    local input
    if not is_empty_link then
        input = word
    end

    require("org-roam.ui.select-node")({
        auto_select = true,
        init_input = input,
    }, function(id)
        ---@type org-roam.core.database.Node|nil
        local node = db:get(id)

        if node then
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
                i = string.find(line, word, i + 1, true)
                if i == nil then break end

                -- Check if the current match contains the cursor column
                if i - 1 <= col and i - 1 + #word > col then
                    col = i - 1
                    break
                end
            end

            -- Insert text representing the new link only if we found a match
            if i ~= nil then
                -- Replace the text (this will place us into insert mode)
                vim.api.nvim_buf_set_text(bufnr, row, col, row, col + #word, {
                    string.format("[[id:%s][%s]]", node.id, node.title)
                })

                -- Force ourselves back into normal mode
                vim.cmd("stopinsert")
            end
        end
    end)
end

return M
