-------------------------------------------------------------------------------
-- WINDOW-PICKER.LUA
--
-- Specialized visual interface to select a window by overlaying choices.
-- Modelled after nvim-window-picker (https://github.com/s1n7ax/nvim-window-picker).
-------------------------------------------------------------------------------

local Emitter = require("org-roam.core.utils.emitter")
local Hint = require("org-roam.core.ui.window-picker.hint")
local notify = require("org-roam.core.ui.notify")

local DEFAULT_CHARS = "FJDKSLA;CMRUEIWOQP"

---Escape character as a numeric code.
---@type integer
local ESCAPE_CODE = 27

---Collection of events that can be fired.
local EVENTS = {
    ---Selection dialog is canceled.
    CANCEL = "window-picker:cancel",

    ---A specific choice from items has been made.
    CHOICE = "window-picker:choice",
}

---@class org-roam.core.ui.WindowPicker
---@field private __autoselect boolean
---@field private __chars string
---@field private __emitter org-roam.core.utils.Emitter
---@field private __filter fun(win:integer):boolean
local M = {}
M.__index = M

---Creates a new org-roam window picker.
---@param opts? {autoselect?:boolean, chars?:string, filter?:fun(win:integer):boolean}
---@return org-roam.core.ui.WindowPicker
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)
    instance.__autoselect = opts.autoselect or false
    instance.__chars = string.lower(opts.chars or DEFAULT_CHARS)
    instance.__emitter = Emitter:new()
    instance.__filter = opts.filter or function() return true end

    return instance
end

---Register callback when no choice is made.
---@param f fun()
---@return org-roam.core.ui.WindowPicker
function M:on_cancel(f)
    self.__emitter:on(EVENTS.CANCEL, f)
    return self
end

---Register callback when a choice is made.
---This is not triggered if the choice is canceled.
---@param f fun(winnr:integer)
---@return org-roam.core.ui.WindowPicker
function M:on_choice(f)
    self.__emitter:on(EVENTS.CHOICE, f)
    return self
end

---Opens the window picker dialog.
function M:open()
    local hint = Hint:new({ chars = self.__chars })
    local windows = self:__get_windows()

    if #windows == 0 then
        notify.warn("No windows left to pick after filtering")
        self.__emitter:emit(EVENTS.CANCEL)
        return
    end

    if self.__autoselect and #windows == 1 then
        self.__emitter:emit(EVENTS.CHOICE, windows[1])
        return
    end

    -- Display hint on top of each window
    hint:draw(windows)
    vim.cmd("redraw")

    -- Get a character from our selection, or nil if escaped
    self:__get_user_input_char(function(char)
        vim.cmd("redraw")
        hint:clear()

        if not char then
            self.__emitter:emit(EVENTS.CANCEL)
            return
        end

        local window = self:__find_matching_win_for_char(char, windows)

        if window then
            self.__emitter:emit(EVENTS.CHOICE, window)
        else
            notify.warn("Invalid window selected using char: " .. char)
            self.__emitter:emit(EVENTS.CANCEL)
        end
    end)
end

---Retrieves single-key input until we get a valid character.
---If `escape` is pressed, this will trigger the callback to return nil.
---@param cb fun(char:string|nil)
function M:__get_user_input_char(cb)
    local ok, c = pcall(vim.fn.getchar)

    if not ok then
        vim.schedule(cb)
        return
    end

    -- Invalid character returned
    if type(c) ~= "number" then
        vim.schedule(function()
            self:__get_user_input_char(cb)
        end)
        return
    end

    -- If we get escape, cancel
    if c == ESCAPE_CODE then
        vim.schedule(cb)
        return
    end

    -- NOTE: chars should be lowercase at this point,
    --       so we can loop through and check the byte
    --       to see if it matches the one from getchar.
    for i = 1, string.len(self.__chars) do
        if c == string.byte(self.__chars, i) then
            cb(vim.fn.nr2char(c))
            return
        end
    end

    -- Did not find a matching character, so check again
    vim.schedule(function()
        self:__get_user_input_char(cb)
    end)
end

---@private
---@return integer[]
function M:__get_windows()
    local all_windows = vim.api.nvim_tabpage_list_wins(0)
    return vim.tbl_filter(self.__filter, all_windows)
end

---@private
---@param user_input_char string
---@param windows integer[]
---@return integer|nil
function M:__find_matching_win_for_char(user_input_char, windows)
    local len = string.len(self.__chars)
    for i = 1, len do
        local char = string.sub(self.__chars, i, i)
        if user_input_char:lower() == char:lower() then
            return windows[i]
        end
    end
end

return M
