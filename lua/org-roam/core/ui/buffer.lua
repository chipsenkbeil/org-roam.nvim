-------------------------------------------------------------------------------
-- BUFFER.LUA
--
-- Buffer interface for org-roam.
-------------------------------------------------------------------------------

local notify = require("org-roam.core.ui.notify")
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
---@param opts? {filetype?:string, name?:string, listed?:boolean, scratch?:boolean}
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

    return bufnr
end

---Creates a new org-roam buffer.
---@param opts? {filetype?:string, name?:string, listed?:boolean, scratch?:boolean}
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
---@param widget org-roam.core.ui.Widget
---@return org-roam.core.ui.Buffer
function M:add_widget(widget)
    table.insert(self.__widgets, widget)
    return self
end

---Returns handle to underlying buffer.
---@return integer
function M:bufnr()
    return self.__bufnr
end

---Appends the provided lines to the end of the buffer.
---@param lines string[]
function M:append_lines(lines)
    vim.api.nvim_buf_set_lines(self.__bufnr, -1, -1, true, lines)
end

---@private
---Clears the buffer's contents.
function M:__clear()
    vim.api.nvim_buf_set_lines(self.__bufnr, 0, -1, true, {})
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
        self:__clear()

        -- Redraw content using the provided widgets
        for _, widget in ipairs(self.__widgets) do
            local ok, err = widget:render(self)

            if not ok and not err then
                err = "unexpected error during rendering of widget"
            end

            if err then
                notify(err, vim.log.levels.ERROR)
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

return M
