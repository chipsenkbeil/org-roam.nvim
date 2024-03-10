-------------------------------------------------------------------------------
-- SELECT.LUA
--
-- Fancy alternative to `vim.ui.select` for us to use.
-------------------------------------------------------------------------------

local Window = require("org-roam.core.ui.window")
local utils = require("org-roam.core.utils")

local EVENTS = {
    CANCEL = "select:cancel",
    CHOICE = "select:choice",
    INTERNAL_CHOICE_OR_CANCEL = "internal:select:choice_or_cancel",
    SELECT_CHANGE = "select:select_change",
    TEXT_CHANGE = "select:text_change",
}

---@class org-roam.core.ui.Select
---@field private __items table
---@field private __prompt string
---@field private __format_item fun(item:any):string
---@field private __selection integer
---@field private __emitter org-roam.core.utils.Emitter
---@field private __window org-roam.core.ui.Window|nil
local M = {}
M.__index = M

---Creates a new org-roam select dialog.
---@param opts? {items?:table, prompt?:string, format_item?:fun(item:any):string}
---@return org-roam.core.ui.Select
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    instance.__items = opts.items or {}
    instance.__prompt = opts.prompt or ""
    instance.__format_item = opts.format_item or function(item)
        return tostring(item)
    end
    instance.__selection = 0
    instance.__emitter = utils.emitter:new()
    instance.__window = nil

    return instance
end

---Register callback when the selection dialog is canceled.
---@param f fun()
function M:on_cancel(f)
    self.__emitter:emit(EVENTS.CANCEL, f)
end

---Register callback when the text to filter selection is changed.
---@param f fun(text:string)
function M:on_text_change(f)
    self.__emitter:emit(EVENTS.TEXT_CHANGE, f)
end

---Register callback when the selection is changed.
---
---This can be triggered if nothing is selected.
---In this case, idx will be 0.
---@param f fun(item:any|nil, idx:integer)
function M:on_select_change(f)
    self.__emitter:emit(EVENTS.SELECT_CHANGE, f)
end

---Register callback when a selection is made.
---This is not triggered if the selection is canceled.
---@param f fun(item:any, idx:integer)
function M:on_choice(f)
    self.__emitter:emit(EVENTS.CHOICE, f)
end

---Opens the selection dialog.
function M:open()
    if not self.__window then
        local window = Window:new({
            open = Window.OPEN.BOTTOM,
            close_on_bufleave = true,
            focus_on_open = true,
            widgets = { function() return self:__render_widget() end },
        })

        -- Register a one-time emitter for selecting or canceling
        -- so we can ensure only one is triggered.
        ---@param item any|nil
        ---@param idx integer|nil
        self.__emitter:once(EVENTS.INTERNAL_CHOICE_OR_CANCEL, function(item, idx)
            if type(idx) == "number" then
                self.__emitter:emit(EVENTS.CHOICE, item, idx)
            else
                self.__emitter:emit(EVENTS.CANCEL)
            end
        end)

        -- When the window closes, we trigger our callback
        -- only if it hasn't been triggered earlier as this
        -- situation is when someone cancels the selection.
        window:on_close(function(id)
            -- Emit a cancellation, which will only count if we have
            -- not selected first
            self.__emitter:emit(EVENTS.INTERNAL_CHOICE_OR_CANCEL)
            self.__window = nil
        end)

        -- Register callback when adding characters
        vim.api.nvim_create_autocmd("InsertCharPre", {
            desc = "Filter text change",
            buffer = window:bufnr(),
            callback = function()
                self:__refresh_filter()
            end,
        })

        -- Register callback when exiting insert mode as that indicates cancel
        vim.api.nvim_create_autocmd("InsertLeave", {
            desc = "Exit selection dialog",
            buffer = window:bufnr(),
            callback = function()
                self:close()
            end,
        })

        -- Changing selection (down)
        vim.keymap.set("i", "<C-n>", function() self:__select_move_down() end)
        vim.keymap.set("i", "<Down>", function() self:__select_move_down() end)

        -- Changing selection (up)
        vim.keymap.set("i", "<C-p>", function() self:__select_move_up() end)
        vim.keymap.set("i", "<Up>", function() self:__select_move_up() end)

        -- Register callback when <Enter> is hit as that indicates a selection
        vim.keymap.set("i", "<Enter>", function() self:__trigger_selection() end, {
            buffer = window:bufnr(),
            noremap = true,
        })

        self.__window = window
    end

    self.__window:open()
end

---Closes the selection dialog, canceling the choice.
function M:close()
    if self.__window then
        self.__window:close()
    end
    self.__window = nil
end

---Returns true if the selection dialog is open.
function M:is_open()
    return self.__window ~= nil and self.__window:is_open()
end

---Updates the items shown by the selection dialog.
---@param items table
---@param selected? integer
function M:update_items(items, selected)
    -- Update our items
    self.__items = items

    -- Clear our old selection
    self.__selection = 0

    -- If provided, update selection item
    if type(selected) == "number" then
        self.__selection = selected
    end

    -- If out of bounds, clear selection
    if self.__selection < 1 or self.__selection > #self.__items then
        self.__selection = 0
    end

    -- Re-render with the new items
    self:__render()
end

---Returns items displayed by selection dialog.
---@return table
function M:items()
    return self.__items
end

---Returns index of selected item, or 0 if none selected.
---@return integer
function M:selected()
    return self.__selection
end

---@private
function M:__select_move_down()
    local cnt = #self.__items
    local idx = self.__selection

    -- Rules:
    --
    -- 1. If we have not selected (0), place us at first item
    -- 2. If we are less than max choices, increment
    -- 3. Otherwise, we are moving past max choices, so place back at top
    if idx < 1 or idx >= cnt then
        idx = 1
    else
        idx = idx + 1
    end
    if cnt < 1 then
        idx = 0
    end
    self.__selection = idx

    -- Notify of a selection change
    local item = self.__items[idx]
    self.__emitter:emit(EVENTS.SELECT_CHANGE, item, idx)

    -- Trigger re-render
    self:__render()
end

---@private
function M:__select_move_up()
    local cnt = #self.__items
    local idx = self.__selection

    -- Rules:
    --
    -- 1. If we have not selected (0), place us at last item
    -- 2. If we are less than first choice, decrement
    -- 3. Otherwise, we are moving past first choice, place us at last item
    if idx < 1 then
        idx = cnt
    else
        idx = idx - 1
    end
    if cnt < 1 then
        idx = 0
    end
    self.__selection = idx

    -- Notify of a selection change
    local item = self.__items[idx]
    self.__emitter:emit(EVENTS.SELECT_CHANGE, item, idx)

    -- Trigger re-render
    self:__render()
end

---@private
function M:__trigger_selection()
    -- If there is nothing to select, ignore enter
    local idx = self.__selection
    if idx < 1 then
        return
    end

    -- Otherwise, we have an item, which we pick out
    local item = self.__items[idx]
    if item then
        self.__emitter:emit(EVENTS.INTERNAL_CHOICE_OR_CANCEL, item, idx)
        self:close()
    end
end

---@private
function M:__refresh_filter()
    local text = self:__get_filter_text()
    self.__emitter:emit(EVENTS.TEXT_CHANGE, text)
end

---@private
---@return string
function M:__get_filter_text()
    local window = self.__window
    if not window then
        return ""
    end

    -- Get the first line of our buffer, where the prompt and text go
    ---@type string|nil
    local line = vim.api.nvim_buf_get_lines(window:bufnr(), 0, 1, false)[1]

    -- Get everything past the prompt
    return string.sub(line or "", string.len(self.__prompt) + 1)
end

---@private
function M:__render()
    if self.__window then
        self.__window:render()
    end
end

---@private
---@return string[]
function M:__render_widget()
    local window = self.__window
    if not window then
        return {}
    end

    local lines = {}

    -- Figure out the maximum items we can show, leaving room for
    -- the prompt and a divider
    local size = window:size()
    local cnt = size[1] - 2

    -- Prompt + text as entered
    table.insert(lines, string.format(
        "%s%s",
        self.__prompt,
        self:__get_filter_text()
    ))

    -- Divider the length of the buffer
    table.insert(lines, string.rep("-", size[2]))

    -- TODO: We need to keep a subset of items in view,
    --       and that view can be different than
    --       where the selection is, although the selection
    --       must be somewhere within the view.
    for i, item in ipairs(self.__items) do
        local text = self.__format_item(item)

        if i == self.__selection then
            text = string.format("* %s", text)
        else
            text = string.format("  %s", text)
        end

        table.insert(lines, text)
    end

    return lines
end

return M
