-------------------------------------------------------------------------------
-- BUFFER.LUA
--
-- Provides interface to work with an org-roam buffer.
-------------------------------------------------------------------------------

local vim = vim
local api = vim.api
local utils = require("org-roam.core.utils")

---@class org-roam.buffer.Buffer
---@field bufnr integer #handle of buffer this wraps
---@field node org-roam.core.database.Id|nil #specific node being targeted
---@field private widgets org-roam.buffer.Widget[] #widgets to user for rendering
local M = {}
M.__index = M

---Creates a new org-roam buffer.
---@param opts? {buffer?:integer, node?:org-roam.core.database.Id, widgets?:org-roam.buffer.Widget[]}
---@return org-roam.buffer.Buffer
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    -- Set or create a buffer
    instance.bufnr = opts.buffer or api.nvim_create_buf(false, true)
    assert(instance.bufnr ~= 0, "failed to create buffer")

    -- Set the the node being tracked; or not set if this is dynamic
    -- based on cursor position in org buffer
    instance.node = opts.node or error("TODO: implement getting node under cursor")

    -- Set widgets that we will use
    instance.widgets = opts.widgets or {}

    -- Set name to something random
    api.nvim_buf_set_name(instance.bufnr, "org-roam-" .. utils.random.uuid_v4())

    -- Set the filetype to org because we're all in, baby!
    api.nvim_buf_set_option(instance.bufnr, "filetype", "org")

    return instance
end

---@param opts? {window?:integer}
function M:open(opts)
    opts = opts or {}

    -- Refresh the buffer before showing it
    self:__render()

    -- Show it in the user-specified window, or the current window
    local window = opts.window or 0
    api.nvim_win_set_buf(window, self.bufnr)
end

---@private
function M:__render()
    local bufnr = self.bufnr

    -- Clear the buffer
    api.nvim_buf_set_lines(bufnr, 0, -1, true, {})

    -- Load the node to render
    local node = self:__node()
    if not node then
        return
    end

    -- Append the name of the node
    api.nvim_buf_set_lines(bufnr, -1, -1, true, {
        string.format("# %s", api.nvim_buf_get_name(bufnr)),
        "",
        string.format("* %s", node.title),
    })

    -- Apply each widget in turn
    for _, widget in ipairs(self.widgets) do
        widget:apply({
            buffer = bufnr,
            database = nil,
            node = node,
        })
    end
end

---@private
---@return org-roam.core.database.Node|nil
function M:__node()
end

return M
