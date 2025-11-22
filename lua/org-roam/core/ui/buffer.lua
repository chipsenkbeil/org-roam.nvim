-------------------------------------------------------------------------------
-- BUFFER.LUA
--
-- Buffer interface for org-roam.
-------------------------------------------------------------------------------

local Emitter = require("org-roam.core.utils.emitter")
local notify = require("org-roam.core.ui.notify")
local random = require("org-roam.core.utils.random")
local ui_utils = require("org-roam.core.utils.ui")
local Component = require("org-roam.core.ui.component")

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

    ---When the buffer is avoiding rending.
    PAUSED = "paused",

    ---When the buffer is scheduled for rendering.
    SCHEDULED = "scheduled",

    ---When the buffer is in the midst of rendering.
    RENDERING = "rendering",
}

local MOUSE_EVENTS = {
    "<mousemove>",
    "<leftdrag>",
    "<leftrelease>",
    "<rightmouse>",
}

---@class org-roam.core.ui.buffer.Keybindings
---@field registered table<string, boolean> #mapping of lhs -> boolean to indicate registration done
---@field callbacks table<integer, table<string, function[]>> #line -> lhs -> callbacks

---@class org-roam.core.ui.Buffer
---@field private __bufnr integer
---@field private __offset integer
---@field private __namespace integer
---@field private __emitter org-roam.core.utils.Emitter
---@field private __state org-roam.core.ui.buffer.State
---@field private __keybindings org-roam.core.ui.buffer.Keybindings
---@field private __components org-roam.core.ui.Component[]
local M = {}
M.__index = M

---Makes a new buffer configured for orgmode.
---@param opts? {name?:string, listed?:boolean, scratch?:boolean, [string]:any}
---@return integer
local function make_buffer(opts)
    opts = opts or {}

    local bufnr = vim.api.nvim_create_buf(
        type(opts.listed) == "boolean" and opts.listed or false,
        type(opts.scratch) == "boolean" and opts.scratch or true
    )
    assert(bufnr ~= 0, "failed to create buffer")

    -- Set name to something random (unless specified)
    vim.api.nvim_buf_set_name(bufnr, opts.name or ("org-roam-" .. random.uuid_v4()))

    -- Clear out all options that we've used explicitly
    opts.name = nil
    opts.listed = nil
    opts.scratch = nil

    -- Apply all remaining options passed
    for k, v in pairs(opts) do
        vim.api.nvim_buf_set_option(bufnr, k, v)
    end

    return bufnr
end

---Creates a new org-roam buffer.
---@param opts? {name?:string, offset?:integer, listed?:boolean, scratch?:boolean, [string]:any}
---@return org-roam.core.ui.Buffer
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    local offset = opts.offset or 0
    opts.offset = nil

    instance.__bufnr = make_buffer(opts)
    instance.__offset = offset
    instance.__namespace = vim.api.nvim_create_namespace(vim.api.nvim_buf_get_name(instance.__bufnr))
    instance.__emitter = Emitter:new()
    instance.__state = STATE.IDLE
    instance.__keybindings = { registered = {}, callbacks = {} }
    instance.__components = {}

    return instance
end

---Adds a component to be used with this buffer.
---@param component org-roam.core.ui.Component|org-roam.core.ui.ComponentFunction
---@return org-roam.core.ui.Buffer
function M:add_component(component)
    -- If given a raw function, convert it into a component
    if type(component) == "function" then
        component = Component:new(component)
    end

    table.insert(self.__components, component)
    return self
end

---Adds components to be used with this buffer.
---@param components (org-roam.core.ui.Component|org-roam.core.ui.ComponentFunction)[]
---@return org-roam.core.ui.Buffer
function M:add_components(components)
    for _, component in ipairs(components) do
        self:add_component(component)
    end

    return self
end

---Returns handle to underlying buffer.
---@return integer
function M:bufnr()
    return self.__bufnr
end

---Returns the namespace associated with the underlying buffer.
---@return integer
function M:namespace()
    return self.__namespace
end

---Returns the name of the underlying buffer.
---@return string
function M:name()
    return vim.api.nvim_buf_get_name(self.__bufnr)
end

---Returns the lines of the underlying buffer.
---@return string[]
function M:lines()
    return vim.api.nvim_buf_get_lines(self.__bufnr, 0, -1, true)
end

---Returns true if the buffer exists and has not been deleted.
---@return boolean
function M:is_valid()
    return vim.api.nvim_buf_is_valid(self.__bufnr)
end

---Returns a list of window handles containing this buffer.
---@return integer[]
function M:windows()
    local windows = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(win)
        if bufnr == self.__bufnr then
            table.insert(windows, win)
        end
    end
    return windows
end

---Returns a list of window handles within the specified tabpage containing
---this buffer.
---@param tabpage integer
---@return integer[]
function M:windows_for_tabpage(tabpage)
    local windows = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        local bufnr = vim.api.nvim_win_get_buf(win)
        if bufnr == self.__bufnr then
            table.insert(windows, win)
        end
    end
    return windows
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
function M:is_paused()
    return self.__state == STATE.PAUSED
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

---Set buffer to paused rendering state, canceling any scheduled render.
function M:pause()
    self.__state = STATE.PAUSED
end

---Set buffer to unpaused (idle) rendering state if currently paused.
function M:unpause()
    if self.__state == STATE.PAUSED then
        self.__state = STATE.IDLE
    end
end

---Destroys the buffer.
---NOTE: Once destroyed, the buffer should not be used again.
function M:destroy()
    vim.schedule(function()
        if self:is_valid() then
            vim.api.nvim_buf_delete(self.__bufnr, { force = true })
        end
    end)
end

---Clear and redraw the buffer using the current components.
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
        -- If buffer not in scheduled state (e.g. paused), exit without rendering
        if self.__state ~= STATE.SCHEDULED then
            return
        end

        -- If buffer is no longer valid at this point, skip rendering
        if not self:is_valid() then
            self.__state = STATE.IDLE
            return
        end

        -- Report that we are about to render
        self.__emitter:emit(EVENTS.PRE_RENDER)

        -- Mark as in the rendering state
        self.__state = STATE.RENDERING

        -- Get position of cursor within windows containing buffer
        -- so we can restore them after changing the buffer
        ---@type {win:integer, pos:{[1]:integer, [2]:integer}}[]
        local cursors = vim.tbl_map(function(winnr)
            return { win = winnr, pos = vim.api.nvim_win_get_cursor(winnr) }
        end, ui_utils.get_windows_for_buffer(self.__bufnr))

        -- Clear the buffer of its content
        -- NOTE: If clear fails, something has gone wrong in neovim, which
        --       seems to happen in our CI tests. Otherwise, we continue
        --       to process components as expected.
        if self:__clear({ force = true }) then
            -- Redraw content using the provided components
            for _, component in ipairs(self.__components) do
                local ret = component:render()
                if ret.ok then
                    self:__apply_lines(ret.lines, true)
                else
                    notify.error("component failed: " .. ret.error)
                end
            end
        end

        -- Restore cursors of windows where buffer was modified
        for _, cursor in ipairs(cursors) do
            -- Each of these can fail, so we just try
            pcall(vim.api.nvim_win_set_cursor, cursor.win, cursor.pos)
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
---Applies the provided lines to the buffer.
---@param ui_lines org-roam.core.ui.Line[]
---@param force? boolean
function M:__apply_lines(ui_lines, force)
    local bufnr = self.__bufnr

    local modifiable = self:is_modifiable()
    if force then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    end

    -- Check if the buffer is empty
    local cnt = vim.api.nvim_buf_line_count(bufnr)
    local is_empty = cnt == 1 and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""

    -- Calculate the starting line for appending and highlights
    -- NOTE: This should always be at or after the offset!
    local start = is_empty and self.__offset or math.max(self.__offset, cnt)

    -- Check if we have less lines than needed for offset and append
    -- blank lines to cover
    local offset_lines_needed = self.__offset - cnt
    if offset_lines_needed > 0 then
        local lines = {}
        for _ = 1, offset_lines_needed do
            table.insert(lines, "")
        end
        vim.api.nvim_buf_set_lines(bufnr, cnt, -1, false, lines)
    end

    -- Build up the complete lines and highlights
    ---@type string[]
    local lines = {}

    ---@type {group:string, line:integer, cstart:integer, cend:integer}[]
    local highlights = {}

    ---@type {start:integer, end_:integer, global:boolean, f:org-roam.core.ui.LazyHighlightFunction}[]
    local lazy = {}

    ---@type {lhs:string, rhs:function, line:integer}[]
    local keybindings = {}

    for _, line in ipairs(ui_lines) do
        ---Zero-indexed line number
        local line_idx = start + #lines

        ---@param segments org-roam.core.ui.LineSegment[]
        ---@return string|nil
        local function process_segments(segments)
            local text = ""
            local has_text = false
            for _, seg in ipairs(segments) do
                if seg.type == "action" then
                    table.insert(keybindings, {
                        lhs = seg.lhs,
                        rhs = seg.rhs,
                        line = seg.global and -1 or line_idx,
                    })
                elseif seg.type == "text" then
                    has_text = true
                    text = text .. seg.text
                elseif seg.type == "hl" then
                    has_text = true
                    -- col start/end are zero-indexed and
                    -- col end is exclusive
                    local cstart = string.len(text)
                    local cend = cstart + string.len(seg.text)
                    text = text .. seg.text
                    table.insert(highlights, {
                        group = seg.group,
                        line = line_idx,
                        cstart = cstart,
                        cend = cend,
                    })
                elseif seg.type == "group" then
                    local group_text = process_segments(seg.segments)
                    if group_text then
                        has_text = true
                        text = text .. group_text
                    end
                end
            end
            if has_text then
                return text
            end
        end

        if type(line) == "string" then
            table.insert(lines, line)
        elseif type(line) == "table" and line.lazy then
            local last_lazy = lazy[#lazy]
            -- If the function is the same function as before
            -- and our position is just after the last line
            -- then we grow our lazy range instead of appending
            if last_lazy and last_lazy.f == line.hl and last_lazy.end_ == line_idx then
                last_lazy.end_ = line_idx + 1
                if line.global == true and not last_lazy.global then
                    last_lazy.global = true
                end
            else
                table.insert(lazy, {
                    start = line_idx,
                    end_ = line_idx + 1,
                    global = line.global or false,
                    f = line.hl,
                })
            end

            table.insert(lines, line.text)
        elseif type(line) == "table" and not vim.tbl_isempty(line) then
            local text = process_segments(line)
            if text then
                table.insert(lines, text)
            end
        end
    end

    -- Append all of the line contents
    vim.api.nvim_buf_set_lines(bufnr, start, -1, false, lines)

    -- Apply all highlights
    for _, hl in ipairs(highlights) do
        vim.api.nvim_buf_add_highlight(self.__bufnr, self.__namespace, hl.group, hl.line, hl.cstart, hl.cend)
    end

    -- Extract out global lazy functions so we don't call them
    -- for individual local ranges and instead for all ranges
    ---@type org-roam.core.ui.LazyHighlightFunction[]
    local global_lazy_hl = {}
    for _, hl in ipairs(lazy) do
        if hl.global then
            table.insert(global_lazy_hl, hl.f)
            hl.f = nil
        end
    end

    -- Apply all lazy highlights that are not global and build up
    -- our list of ranges for global highlighting
    local ranges = {}
    for _, hl in ipairs(lazy) do
        local f = hl.f
        if f then
            f(self.__bufnr, self.__namespace, { { hl.start, hl.end_ } })
        end
        table.insert(ranges, { hl.start, hl.end_ })
    end

    -- Apply all global lazy highlights
    for _, f in ipairs(global_lazy_hl) do
        f(self.__bufnr, self.__namespace, ranges)
    end

    -- Clear out old callbacks in favor of new set so lines rendered
    -- in new positions don't conflict
    self.__keybindings.callbacks = {}

    -- Set keybindings for rendered lines
    for _, kb in ipairs(keybindings) do
        -- If we have not stored a keybinding for the line (or -1 for global),
        -- create the mapping instance
        if not self.__keybindings.callbacks[kb.line] then
            self.__keybindings.callbacks[kb.line] = {}
        end

        -- Store our callback for this keybinding
        if not self.__keybindings.callbacks[kb.line][kb.lhs] then
            self.__keybindings.callbacks[kb.line][kb.lhs] = {}
        end
        table.insert(self.__keybindings.callbacks[kb.line][kb.lhs], kb.rhs)

        if not self.__keybindings.registered then
            self.__keybindings.registered = {}
        end

        -- If we have not registered this keybinding before, do so
        if not self.__keybindings.registered[kb.lhs] then
            self.__keybindings.registered[kb.lhs] = true
            vim.keymap.set("n", kb.lhs, function()
                -- Get position within buffer as zero-indexed line number
                local line = vim.api.nvim_win_get_cursor(0)[1] - 1

                -- Special handling for mouse events
                if vim.tbl_contains(MOUSE_EVENTS, string.lower(vim.trim(kb.lhs))) then
                    local pos = vim.fn.getmousepos()
                    local win = pos.winid

                    -- Check that we are within the right buffer
                    local buf = vim.api.nvim_win_get_buf(win)
                    if buf ~= self.__bufnr then
                        return
                    end

                    line = pos.line - 1 -- position within window
                end

                local lhs = kb.lhs

                -- Trigger all callbacks for the line
                local line_cbs = (self.__keybindings.callbacks[line] and self.__keybindings.callbacks[line][lhs]) or {}
                for _, cb in ipairs(line_cbs) do
                    vim.schedule(cb)
                end

                -- Trigger all global callbacks (line == -1)
                local global_cbs = (self.__keybindings.callbacks[-1] and self.__keybindings.callbacks[-1][lhs]) or {}
                for _, cb in ipairs(global_cbs) do
                    vim.schedule(cb)
                end
            end, {
                buffer = self.__bufnr,
                nowait = true,
                silent = true,
            })
        end
    end

    if force then
        vim.api.nvim_buf_set_option(bufnr, "modifiable", modifiable)
    end
end

---@private
---Clears the buffer's contents.
---@param opts? {force?:boolean}
---@return boolean
function M:__clear(opts)
    opts = opts or {}
    local force = opts.force or false

    local modifiable = self:is_modifiable()
    if force then
        vim.api.nvim_buf_set_option(self.__bufnr, "modifiable", true)
    end

    -- Clear highlights and contents of the buffer
    --
    -- NOTE: It appears in our tests, specifically api-completion for
    --       exactly one match, we hit an internal error:
    --       "Vim:E315: ml_get: invalid lnum: 2" for the call to
    --       nvim_buf_set_lines.
    --
    --       I tried to add a check earlier to see if the buffer was loaded,
    --       but it didn't do anything to help. So for now we're ignoring
    --       this as this seems to happen in the test only and does not stop
    --       the test from completing successfull.
    vim.api.nvim_buf_clear_namespace(self.__bufnr, self.__namespace, self.__offset, -1)

    -- NOTE: This fails with "E315: ml_get: invalid lnum: 2" in our CI (sometimes); so,
    --       we are wrapping it in a pcall to catch the error. If we really did get in
    --       a bad state as a user, it'd be better to just stop processing, which is
    --       what we do when this reports false.
    local ok = pcall(vim.api.nvim_buf_set_lines, self.__bufnr, self.__offset, -1, true, {})

    if force then
        vim.api.nvim_buf_set_option(self.__bufnr, "modifiable", modifiable)
    end

    return ok
end

return M
