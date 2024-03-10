-------------------------------------------------------------------------------
-- BUFFER.LUA
--
-- Buffer interface for org-roam.
-------------------------------------------------------------------------------

local notify = require("org-roam.core.ui.notify")
local Widget = require("org-roam.core.ui.widget")
local utils = require("org-roam.core.utils")

local EVENTS = {
    ---When rendering is about to start.
    PRE_RENDER = "pre_render",

    ---When rendering has just finished.
    POST_RENDER = "post_render",
}

---@enum org-roam.core.ui.buffer.State
local STATE = {
    ---When the buffer is not scheduled or rendering.
    IDLE = "idle",

    ---When the buffer is scheduled for rendering.
    SCHEDULED = "scheduled",

    ---When the buffer is in the midst of rendering.
    RENDERING = "rendering",
}

---@class org-roam.core.ui.Buffer
---@field private __bufnr integer
---@field private __emitter org-roam.core.utils.Emitter
---@field private __state org-roam.core.ui.buffer.State
---@field private __widgets org-roam.core.ui.Widget[]
local M = {}
M.__index = M

---Makes a new buffer configured for orgmode.
---@param opts? {filetype?:string, name?:string, listed?:boolean, scratch?:boolean, [string]:any}
---@return integer
local function make_buffer(opts)
    opts = opts or {}

    local bufnr = vim.api.nvim_create_buf(
        type(opts.listed) == "boolean" and opts.listed or false,
        type(opts.scratch) == "boolean" and opts.scratch or true
    )
    assert(bufnr ~= 0, "failed to create buffer")

    -- Set name to something random (unless specified)
    vim.api.nvim_buf_set_name(
        bufnr,
        opts.name or ("org-roam-" .. utils.random.uuid_v4())
    )

    -- Set the filetype to org (unless specified) because we're all in, baby!
    vim.api.nvim_buf_set_option(bufnr, "filetype", opts.filetype or "org")

    -- Clear out all options that we've used explicitly
    opts.name = nil
    opts.filetype = nil
    opts.listed = nil
    opts.scratch = nil

    -- Apply all remaining options passed
    for k, v in pairs(opts) do
        vim.api.nvim_buf_set_option(bufnr, k, v)
    end

    return bufnr
end

---Creates a new org-roam buffer.
---@param opts? {filetype?:string, name?:string, listed?:boolean, scratch?:boolean, [string]:any}
---@return org-roam.core.ui.Buffer
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    local emitter      = utils.emitter:new()
    instance.__bufnr   = make_buffer(opts)
    instance.__emitter = emitter
    instance.__state   = STATE.IDLE
    instance.__widgets = {}

    return instance
end

---Adds a widget to be used with this buffer.
---@param widget org-roam.core.ui.Widget|org-roam.core.ui.WidgetFunction
---@return org-roam.core.ui.Buffer
function M:add_widget(widget)
    -- If given a raw function, convert it into a widget
    if type(widget) == "function" then
        widget = Widget:new(widget)
    end

    table.insert(self.__widgets, widget)
    return self
end

---Adds widgets to be used with this buffer.
---@param widgets (org-roam.core.ui.Widget|org-roam.core.ui.WidgetFunction)[]
---@return org-roam.core.ui.Buffer
function M:add_widgets(widgets)
    for _, widget in ipairs(widgets) do
        self:add_widget(widget)
    end

    return self
end

---Returns handle to underlying buffer.
---@return integer
function M:bufnr()
    return self.__bufnr
end

---Invokes `cb` right before render has started.
---@param cb fun()
function M:on_pre_render(cb)
    self.__emitter:on(EVENTS.PRE_RENDER, cb)
end

---Invokes `cb` once render has finished.
---@param cb fun()
function M:on_post_render(cb)
    self.__emitter:on(EVENTS.POST_RENDER, cb)
end

---Returns the current state of the buffer.
---@return org-roam.core.ui.buffer.State
function M:state()
    return self.__state
end

---@return boolean
function M:is_idle()
    return self.__state == STATE.IDLE
end

---@return boolean
function M:is_scheduled()
    return self.__state == STATE.SCHEDULED
end

---@return boolean
function M:is_rendering()
    return self.__state == STATE.RENDERING
end

---@return boolean
function M:is_modifiable()
    return vim.api.nvim_buf_get_option(self.__bufnr, "modifiable") == true
end

---Clear and redraw the buffer using the current widgets.
---
---If `delay` specified, will wait N milliseconds before scheduling rendering.
---If `sync` specified, will render directly instead of scheduling rendering.
---
---@param opts? {delay?:integer, sync?:boolean}
function M:render(opts)
    opts = opts or {}

    -- Prevent accidental repeated render calls
    if self.__state ~= STATE.IDLE then
        return
    end

    local function do_render()
        -- Report that we are about to render
        self.__emitter:emit(EVENTS.PRE_RENDER)

        -- Mark as in the rendering state
        self.__state = STATE.RENDERING

        -- Clear the buffer of its content
        self:__clear({ force = true })

        -- Redraw content using the provided widgets
        for _, widget in ipairs(self.__widgets) do
            local ret = widget:render()
            if ret.ok then
                self:__append_lines({ utils.table.unpack(ret.lines), force = true })
            else
                notify.error("widget failed: " .. ret.error)
            end
        end

        -- Reset to idle state as we're done
        self.__state = STATE.IDLE

        -- Report that we have rendered
        self.__emitter:emit(EVENTS.POST_RENDER)
    end

    -- Mark as scheduled to render
    self.__state = STATE.SCHEDULED

    if opts.sync then
        do_render()
    elseif opts.delay then
        vim.defer_fn(do_render, opts.delay)
    else
        vim.schedule(do_render)
    end
end

---@private
---Appends the provided lines to the end of the buffer.
---@param lines {[integer]:string, force?:boolean}
function M:__append_lines(lines)
    local bufnr = self.__bufnr
    local force = lines.force or false
    lines.force = nil

    local modifiable = self:is_modifiable()
    if force then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    end

    -- Check if the buffer is empty
    local cnt = vim.api.nvim_buf_line_count(bufnr)
    local is_empty = cnt == 1
        and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""

    if is_empty then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines)
    else
        vim.api.nvim_buf_set_lines(bufnr, cnt, -1, true, lines)
    end

    if force then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", modifiable)
    end
end

---@private
---Clears the buffer's contents.
---@param opts? {force?:boolean}
function M:__clear(opts)
    opts = opts or {}
    local force = opts.force or false

    local modifiable = self:is_modifiable()
    if force then
        vim.api.nvim_buf_set_option(self.__bufnr, "modifiable", true)
    end

    vim.api.nvim_buf_set_lines(self.__bufnr, 0, -1, true, {})

    if force then
        vim.api.nvim_buf_set_option(self.__bufnr, "modifiable", modifiable)
    end
end

return M
