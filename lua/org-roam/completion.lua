-------------------------------------------------------------------------------
-- COMPLETION.LUA
--
-- Contains functionality tied to org-roam completion.
-------------------------------------------------------------------------------

local database = require("org-roam.database")

local M = {}

---@param arg_lead string #leading portion of the argument being completed
---@param cmd_line string #entire command line
---@param cursor_pos integer #cursor position in cmdline (byte index)
---@return string #candidates separated by newline
function M.SelectFixedNode(arg_lead, cmd_line, cursor_pos)
    local db = database()

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

    return ""
end

return M
