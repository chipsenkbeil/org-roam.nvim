-------------------------------------------------------------------------------
-- WINDOW.LUA
--
-- Logic to create windows.
-------------------------------------------------------------------------------

local Buffer = require("org-roam.core.ui.buffer")
local Emitter = require("org-roam.core.utils.emitter")
local random = require("org-roam.core.utils.random")

---@enum org-roam.core.ui.window.Open
local OPEN = {
    ---Configuration to open the window on the right side.
    RIGHT = "botright vsplit | vertical resize 50",

    ---Configuration to open the window on the bottom.
    BOTTOM = "botright split | resize 15",
}

local EVENTS = {
    OPEN = "window:open",
    CLOSE = "window:close",
}

---@class org-roam.core.ui.window.Opts
---@field name? string
---@field open? string|fun():integer
---@field focus_on_open? boolean
---@field close_on_bufleave? boolean
---@field destroy_on_close? boolean
---@field bufopts? table<string, any>
---@field winopts? table<string, any>
---@field components? (org-roam.core.ui.Component|org-roam.core.ui.ComponentFunction)[]

---@class org-roam.core.ui.Window
---@field private __buffer org-roam.core.ui.Buffer
---@field private __name string
---@field private __open string|fun():integer
---@field private __emitter org-roam.core.utils.Emitter
---@field private __bufopts table<string, any>
---@field private __winopts table<string, any>
---@field private __focus_on_open boolean
---@field private __close_on_bufleave boolean
---@field private __destroy_on_close boolean
---@field private __win integer|nil #handle of open window
local M = {}
M.__index = M
M.OPEN = OPEN

---Creates a new org-roam ui window with a pre-assigned buffer.
---@param opts? org-roam.core.ui.window.Opts
---@return org-roam.core.ui.Window
function M:new(opts)
    opts = vim.tbl_deep_extend("keep", opts or {}, {
        name = string.format("org-roam-%s", random.uuid_v4()),
        open = OPEN.RIGHT,
        bufopts = {
            -- Don't let the buffer represent a file or be editable by default
            modifiable = false,
            buftype = "nofile",
            swapfile = false,
            -- bufhidden = "wipe",
        },
        winopts = {
            -- These are settings we want for orgmode
            conceallevel = 2,
            concealcursor = "nc",

            -- These are some other nice settings
            winfixwidth = true,
            number = false,
            relativenumber = false,
            spell = false,
        },
    })

    local instance = {}
    setmetatable(instance, M)

    -- Create the buffer we will use with the window
    instance.__buffer = Buffer:new(vim.tbl_extend("keep", opts.bufopts or {}, {
        name = opts.name,
    }))

    -- Apply any components we've been assigned
    if type(opts.components) == "table" then
        instance.__buffer:add_components(opts.components)
    end

    -- Schedule the first rendering of the buffer
    instance.__buffer:render()

    instance.__name = assert(opts.name)
    instance.__open = assert(opts.open)
    instance.__emitter = Emitter:new()
    instance.__bufopts = assert(opts.bufopts)
    instance.__winopts = assert(opts.winopts)
    instance.__focus_on_open = opts.focus_on_open or false
    instance.__close_on_bufleave = opts.close_on_bufleave or false
    instance.__destroy_on_close = opts.destroy_on_close or false
    instance.__win = nil

    return instance
end

---Opens the window.
---@return integer handle
function M:open()
    -- If already open, return the window handle
    if self:is_open() then
        return self.__win
    end

    -- Save the window currently selected so we can restore focus
    local cur_win = vim.api.nvim_get_current_win()

    -- Create the new window using the configuratio
    if type(self.__open) == "string" then
        ---@type string
        ---@diagnostic disable-next-line:assign-type-mismatch
        local cmd = self.__open

        vim.cmd(cmd)
        self.__win = vim.api.nvim_get_current_win()
    elseif type(self.__open) == "function" then
        self.__win = self.__open() or vim.api.nvim_get_current_win()
    else
        error(string.format("invalid open config type: %s", type(self.__open)))
    end

    -- Restore focus to original window
    if not self.__focus_on_open then
        vim.api.nvim_set_current_win(cur_win)
    end

    -- Set the buffer for our window
    vim.api.nvim_win_set_buf(self.__win, self:bufnr())

    -- Configure the window with our options
    for k, v in pairs(self.__winopts) do
        vim.api.nvim_win_set_option(self.__win, k, v)
    end

    -- Configure an autocommand to trigger when the window closes
    vim.api.nvim_create_autocmd("WinClosed", {
        desc = "Triggered when window " .. self.__win .. " closed",
        pattern = tostring(self.__win),
        once = true,
        callback = function()
            -- Only close if the window that closed is still
            -- the one that we have selected
            local win = tonumber(vim.fn.expand("<amatch>"))
            if self.__win and self.__win == win then
                self:close()
            end
        end,
    })

    -- If configured to do so, add an autocommand to close
    -- the window once we exit the buffer
    if self.__close_on_bufleave then
        vim.api.nvim_create_autocmd("BufLeave", {
            desc = "Close window " .. self.__win .. " on BufLeave",
            buffer = self:bufnr(),
            nested = true,
            once = true,
            callback = function()
                self:close()
            end,
        })
    end

    -- Report that the window is now open
    self.__emitter:emit(EVENTS.OPEN, self.__win)

    return self.__win
end

---Closes the window if it is open.
function M:close()
    local win = self.__win
    if not win then
        return
    end

    self.__emitter:emit(EVENTS.CLOSE, win)

    if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
    end

    if self.__destroy_on_close then
        self.__buffer:destroy()
    end

    self.__win = nil
end

---@return boolean
function M:is_open()
    return self.__win ~= nil and vim.api.nvim_win_is_valid(self.__win)
end

---Opens the window if closed, or closes if open.
function M:toggle()
    if self:is_open() then
        self:close()
    else
        self:open()
    end
end

---Updates the window buffer contents.
---@param opts? {delay?:integer, force?:boolean, sync?:boolean}
function M:render(opts)
    opts = opts or {}

    if self:is_open() or opts.force then
        self.__buffer:render({
            delay = opts.delay,
            sync = opts.sync,
        })
    end
end

---Returns the buffer tied to the window.
---@return org-roam.core.ui.Buffer
function M:buffer()
    return self.__buffer
end

---Returns the handle to the underlying buffer.
---@return integer
function M:bufnr()
    return self.__buffer:bufnr()
end

---Returns the name of the window.
---@return string
function M:name()
    return self.__name
end

---Returns the handle to the underlying window.
---@return integer|nil
function M:winnr()
    return self.__win
end

---Returns a copy of the options provided to the buffer.
---@return table<string, any>
function M:bufopts()
    return vim.deepcopy(self.__bufopts)
end

---Returns a copy of the options provided to the window.
---@return table<string, any>
function M:winopts()
    return vim.deepcopy(self.__winopts)
end

---@param f fun(winnr:integer)
---@return org-roam.core.ui.Window
function M:on_open(f)
    self.__emitter:on(EVENTS.OPEN, f)
    return self
end

---@param f fun(winnr:integer)
---@return org-roam.core.ui.Window
function M:on_close(f)
    self.__emitter:on(EVENTS.CLOSE, f)
    return self
end

---Returns the size of the window in rows x columns.
---In the case that the window is not open, this returns {0,0}.
---@return {[1]:integer, [2]:integer}
function M:size()
    if not self.__win then
        return { 0, 0 }
    end

    local rows = vim.api.nvim_win_get_height(self.__win)
    local cols = vim.api.nvim_win_get_width(self.__win)
    return { rows, cols }
end

---Returns true if the window's buffer is the same as when it was created.
---If the buffer has been switched, this will return false.
---@return boolean
function M:has_original_buffer()
    local winnr = self.__win
    if not winnr then
        return false
    end
    return vim.api.nvim_win_get_buf(winnr) == self:bufnr()
end

return M
