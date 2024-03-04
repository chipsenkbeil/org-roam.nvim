-------------------------------------------------------------------------------
-- HIGHLIGHT.LUA
--
-- Provides logic to do highlighting.
-------------------------------------------------------------------------------

local api = vim.api

-- CONSTANTS ------------------------------------------------------------------

-- Namespace used for org-roam buffers.
local NAMESPACE = api.nvim_create_namespace("org-roam.nvim")

-- API ------------------------------------------------------------------------

---@class org-roam.buffer.HighlightOpts
---@field buffer? integer #buffer to highlight, defaulting to current buffer
---@field [integer] string #line (one-based) to highlight group

---@param opts? org-roam.buffer.HighlightOpts
return function(opts)
    opts = opts or {}

    local buffer = opts.buffer or 0

    -- Clear the highlights across the entire buffer
    api.nvim_buf_clear_namespace(buffer, NAMESPACE, 0, -1)

    -- Populate highlights by {line -> hlgroup}
    for line, hl_group in pairs(opts) do
        if type(line) == "number" and type(hl_group) == "string" then
            api.nvim_buf_add_highlight(buffer, NAMESPACE, hl_group, line - 1, 0, -1)
        end
    end
end
