-------------------------------------------------------------------------------
-- UI.LUA
--
-- Contains utility functions to assist with user interface operations.
-------------------------------------------------------------------------------

local M = {}

---Gets handles of windows containing the buffer.
---@param buf integer
---@return integer[]
function M.get_windows_for_buffer(buf)
    local windows = {}
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
        for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            local bufnr = vim.api.nvim_win_get_buf(winnr)
            if buf == bufnr then
                table.insert(windows, winnr)
            end
        end
    end
    return windows
end

return M
