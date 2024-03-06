-------------------------------------------------------------------------------
-- BUFFER.LUA
--
-- Buffer interface for org-roam.
-------------------------------------------------------------------------------

local buffer = require("org-roam.core.buffer")
local notify = require("org-roam.core.ui.notify")
local utils = require("org-roam.core.utils")

---@class org-roam.core.ui.Buffer
---@field private __bufnr integer
---@field private __db org-roam.core.database.Database
---@field private __emitter org-roam.core.utils.Emitter
---@field private __node org-roam.core.database.Id|nil
---@field private __rendering boolean
---@field private __scheduled boolean
---@field private __widgets org-roam.core.ui.Widget[]
local M = {}
M.__index = M

---@enum org-roam.core.ui.buffer.Events
local EVENTS = {
    BUFFER_CHANGED = "buffer:changed",
}
M.EVENTS = EVENTS

---@class org-roam.core.ui.buffer.NewOpts
---@field db org-roam.core.database.Database
---@field buffer? integer #if specified, will replace this buffer's contents
---@field node? org-roam.core.database.Id #if specified, will render using this id, otherwise renders node under cursor

---Creates a new org-roam buffer.
---@param opts org-roam.core.ui.buffer.NewOpts
---@return org-roam.core.ui.Buffer
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    local emitter        = utils.emitter:new()
    instance.__bufnr     = opts.buffer
    instance.__db        = opts.db
    instance.__emitter   = emitter
    instance.__node      = opts.node
    instance.__rendering = false
    instance.__scheduled = false
    instance.__widgets   = {}

    -- Register event when buffer receives a changed event
    -- to force it to re-render.
    emitter:on(EVENTS.BUFFER_CHANGED, function()
        instance:__render()
    end)

    return instance
end

---Configure a widget to be used with this buffer.
---@param widget org-roam.core.ui.Widget
---@return org-roam.core.ui.Buffer
function M:widget(widget)
    table.insert(self.__widgets, widget)
    return self
end

---@param opts? {window?:integer|(fun(bufnr:integer):integer)}
function M:open(opts)
    opts = opts or {}

    self:__configure_buffer()

    -- Begin refreshing the buffer before showing it
    self:__render()

    -- Show it in the user-specified window, or the current window
    local window = opts.window or 0
    if type(window) == "function" then
        window = window(self.__bufnr)
    end
    if vim.api.nvim_win_get_buf(window) ~= self.__bufnr then
        vim.api.nvim_win_set_buf(window, self.__bufnr)
    end
end

---@private
---@param cb? fun()
function M:__render(cb)
    local function report_done()
        if cb then
            vim.schedule(cb)
        end

        self.__rendering = false
    end

    -- If we were already rendering, schedule for later and exit
    if self.__rendering then
        -- We only schedule a render once as subsequent requests
        -- all get merged together for the next successful render
        if not self.__scheduled then
            self.__scheduled = true
            vim.schedule(function()
                self.__scheduled = false
                self:__render(cb)
            end)
        end

        return
    end

    -- Mark ourselves as now rendering to avoid spam
    self.__rendering = true

    local bufnr = self.__bufnr

    -- Load the node to render
    self:__get_node(function(node)
        -- Set buffer to contain the buffer's name first
        self:__clear()
        self:__append_lines({
            string.format("# %s", vim.api.nvim_buf_get_name(bufnr)),
        })

        -- If we have no node available, then we're done
        if not node then
            report_done()
            return
        end

        -- Append the name of the node
        self:__append_lines({ "", string.format("# %s", node.title) })

        ---@param lines string[]
        local function append(lines)
            self:__append_lines(lines)
        end

        -- For each widget, generate content
        for _, widget in ipairs(self.__widgets) do
            local ok, err = widget:render({
                append  = append,
                db      = self.__db,
                emitter = self.__emitter,
                node    = node,
            })

            if not ok and not err then
                err = "unexpected error during rendering of widget"
            end

            if err then
                notify(err, vim.log.levels.ERROR)
            end
        end

        -- Rendering has finished!
        report_done()
    end)
end

---@private
---@return integer bufnr
function M:__configure_buffer()
    -- Set or create a buffer
    local bufnr = self.__bufnr or vim.api.nvim_create_buf(false, true)
    assert(bufnr ~= 0, "failed to create buffer")

    -- Set name to something random
    vim.api.nvim_buf_set_name(bufnr, "org-roam-" .. utils.random.uuid_v4())

    -- Set the filetype to org because we're all in, baby!
    vim.api.nvim_buf_set_option(bufnr, "filetype", "org")

    -- Update and return the buffer handle
    self.__bufnr = bufnr
    return bufnr
end

---@private
---@param cb fun(node:org-roam.core.database.Node|nil)
function M:__get_node(cb)
    local db = self.__db
    if self.__node then
        cb(db:get(self.__node))
    else
        buffer.node_under_cursor(function(id)
            cb(id and db:get(id))
        end)
    end
end

---@private
---@param lines string[]
function M:__append_lines(lines)
    vim.api.nvim_buf_set_lines(self.__bufnr, -1, -1, true, lines)
end

---@private
function M:__clear()
    vim.api.nvim_buf_set_lines(self.__bufnr, 0, -1, true, {})
end

return M
