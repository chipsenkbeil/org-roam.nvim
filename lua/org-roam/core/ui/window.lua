-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Logic to create windows.
-------------------------------------------------------------------------------

---@alias org-roam.core.ui.window.Type
---| "left"
---| "right"
---| "top"
---| "bottom"
---| "float"

---@class org-roam.core.ui.window.Opts
---@field type org-roam.core.ui.window.Type

---@class org-roam.core.ui.Window
---@field private __opts org-roam.core.ui.window.Opts
---@field private __buf integer|nil
---@field private __win integer|nil
local M = {}
M.__index = M

---Creates a new org-roam ui window.
---@param opts org-roam.core.ui.window.Opts
---@return org-roam.core.ui.Window
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.__opts = opts
    instance.__buf = nil
    instance.__win = nil

    return instance
end

---@return integer
function M:open()
    -- If already open, return the window handle
    if self.__win then
        return self.__win
    end

    -- Use or create a buffer
    local buf = self.__buf
    if not buf then
        buf = vim.api.nvim_create_buf(false, true)
        assert(buf ~= 0, "failed to create buffer")
        self.__buf = buf
    end

    -- Create the window
    local win = vim.api.nvim_open_win(buf, true)
    assert(win ~= 0, "failed to create window")
    self.__win = win

    return win
end

---Closes the window if it is open.
function M:close()
    local win = self.__win
    if not win then
        return
    end

    vim.api.nvim_win_close(win, true)
    self.__win = nil
end

---@return boolean
function M:is_open()
    return self.__win ~= nil
end

---Opens the window if closed, or closes if open.
function M:toggle()
    if self:is_open() then
        self:close()
    else
        self:open()
    end
end

---Returns the handle to the underlying buffer.
---@return integer|nil
function M:bufnr()
    return self.__buf
end

---Returns the handle to the underlying window.
---@return integer|nil
function M:winnr()
    return self.__win
end

---Returns a copy of the options provided to the window.
---@return org-roam.core.ui.window.Opts
function M:opts()
    return vim.deepcopy(self.__opts)
end

return M
