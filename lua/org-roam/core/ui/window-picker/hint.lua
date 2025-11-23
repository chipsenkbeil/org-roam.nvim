-------------------------------------------------------------------------------
-- HINT.LUA
--
-- Contains logic to display hints on top of windows.
-- Taken from nvim-window-picker (https://github.com/s1n7ax/nvim-window-picker).
-------------------------------------------------------------------------------

local BORDER = {
    { "╭", "FloatBorder" },
    { "─", "FloatBorder" },
    { "╮", "FloatBorder" },
    { "│", "FloatBorder" },
    { "╯", "FloatBorder" },
    { "─", "FloatBorder" },
    { "╰", "FloatBorder" },
    { "│", "FloatBorder" },
}

local DEFAULT_CHARS = "FJDKSLA;CMRUEIWOQP"

--- @class org-roam.core.ui.window-picker.Hint
--- @field config { chars:string, win_width: integer, win_height: integer }
--- @field private windows number[] #list of window ids
local M = {}
M.__index = M

---@param opts? {chars?:string}
---@return org-roam.core.ui.window-picker.Hint
function M:new(opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)
    instance.config = {
        chars = opts.chars or DEFAULT_CHARS,
        win_width = 18,
        win_height = 8,
    }
    instance.__windows = {}

    return instance
end

---@private
---@param window integer
---@return {x:number, y:number}
function M:__get_float_win_pos(window)
    local width = vim.api.nvim_win_get_width(window)
    local height = vim.api.nvim_win_get_height(window)

    local point = {
        x = ((width - self.config.win_width) / 2),
        y = ((height - self.config.win_height) / 2),
    }

    return point
end

---@private
---@param lines string[]
---@return string[]
function M.__add_big_char_margin(lines)
    local max_text_width = 0
    ---@type string[]
    local centered_lines = {}

    local utf8len = require("org-roam.core.utils.utf8len")
    for _, line in ipairs(lines) do
        local len = utf8len(line)
        if max_text_width < len then
            max_text_width = len
        end
    end

    -- top padding
    table.insert(lines, 1, "")
    --bottom padding
    table.insert(lines, #lines + 1, "")

    --left & right padding

    for _, line in ipairs(lines) do
        local new_line = string.format("%s%s%s", string.rep(" ", 2), line, string.rep(" ", 2))

        table.insert(centered_lines, new_line)
    end

    return centered_lines
end

---@private
---@param window integer
---@param char string
---@return integer
function M:__show_letter_in_window(window, char)
    local point = self:__get_float_win_pos(window)
    local lines = self.__add_big_char_margin(vim.split(char, "\n"))
    local utf8len = require("org-roam.core.utils.utf8len")

    local width = 0
    for _, line in ipairs(lines) do
        width = math.max(width, utf8len(line))
    end
    local height = #lines

    local buffer_id = vim.api.nvim_create_buf(false, true)
    local window_id = vim.api.nvim_open_win(buffer_id, false, {
        relative = "win",
        win = window,
        focusable = true,
        row = point.y,
        col = point.x,
        width = width,
        height = height,
        style = "minimal",
        border = BORDER,
    })

    vim.api.nvim_buf_set_lines(buffer_id, 0, 0, true, lines)

    return window_id
end

---Draws a letter as a window on top of each valid, visible window supplied.
---@param windows integer[]
function M:draw(windows)
    -- Filter out to only include valid windows
    local valid_windows = {}
    for _, window in ipairs(windows) do
        if self:__should_draw_on_window(window) then
            table.insert(valid_windows, window)
        end
    end

    -- If we still have too many windows to populate with our characters,
    -- fail cleanly with a recommendation
    local max_windows = self:__max_windows()
    assert(
        #valid_windows <= max_windows,
        table.concat({
            "Too many valid, visible windows!",
            "Increase the characters available to the window picker.",
        }, " ")
    )

    local font = require("org-roam.core.ui.window-picker.font")
    for i, window in ipairs(valid_windows) do
        local char = string.sub(self.config.chars, i, i)
        local big_char = assert(font[char:lower()], "font missing for " .. char:lower())
        local window_id = self:__show_letter_in_window(window, big_char)
        table.insert(self.__windows, window_id)
    end
end

---Clears the hint.
function M:clear()
    for _, window in ipairs(self.__windows) do
        if vim.api.nvim_win_is_valid(window) then
            local buffer = vim.api.nvim_win_get_buf(window)
            vim.api.nvim_win_close(window, true)
            vim.api.nvim_buf_delete(buffer, { force = true })
        end
    end

    self.__windows = {}
end

---@private
---Returns true if the window should be drawn on, meaning it's valid and visible.
---@param window integer #handle of the window
---@return boolean
function M:__should_draw_on_window(window)
    if not vim.api.nvim_win_is_valid(window) then
        return false
    end

    ---@type vim.api.keyset.win_config
    local config = vim.api.nvim_win_get_config(window)
    return config.relative == ""
end

---@private
---Returns the maximum number of valid, visible windows supported.
---@return integer
function M:__max_windows()
    return string.len(self.config.chars)
end

return M
