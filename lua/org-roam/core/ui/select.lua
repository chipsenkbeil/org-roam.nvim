-------------------------------------------------------------------------------
-- SELECT.LUA
--
-- Fancy alternative to `vim.ui.select` for us to use.
-------------------------------------------------------------------------------

local Window = require("org-roam.core.ui.window")
local utils = require("org-roam.core.utils")

local NAMESPACE = vim.api.nvim_create_namespace("org-roam.core.ui.select")

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
---@field private __max_height integer
---@field private __format_item fun(item:any):string
---@field private __selection integer
---@field private __prompt_id integer|nil
---@field private __filtered {text:string, items:{[1]:integer, [2]:any}[]}
---@field private __emitter org-roam.core.utils.Emitter
---@field private __window org-roam.core.ui.Window|nil
local M = {}
M.__index = M

---Creates a new org-roam select dialog.
---@param opts? {items?:table, max_height?:integer, prompt?:string, format_item?:fun(item:any):string}
---@return org-roam.core.ui.Select
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    instance.__items = opts.items or {}
    instance.__prompt = opts.prompt or ""
    instance.__max_height = opts.max_height or 9
    instance.__format_item = opts.format_item or function(item)
        return tostring(item)
    end
    instance.__selection = 1
    instance.__prompt_id = nil
    instance.__filtered = { text = "", items = {} }
    instance.__emitter = utils.emitter:new()
    instance.__window = nil

    return instance
end

---Register callback when the selection dialog is canceled.
---@param f fun()
---@return org-roam.core.ui.Select
function M:on_cancel(f)
    self.__emitter:on(EVENTS.CANCEL, f)
    return self
end

---Register callback when the text to filter selection is changed.
---@param f fun(text:string)
---@return org-roam.core.ui.Select
function M:on_text_change(f)
    self.__emitter:on(EVENTS.TEXT_CHANGE, f)
    return self
end

---Register callback when the selection is changed.
---
---This can be triggered if nothing is selected.
---In this case, idx will be 0.
---@param f fun(item:any|nil, idx:integer)
---@return org-roam.core.ui.Select
function M:on_select_change(f)
    self.__emitter:on(EVENTS.SELECT_CHANGE, f)
    return self
end

---Register callback when a selection is made.
---This is not triggered if the selection is canceled.
---@param f fun(item:any, idx:integer)
---@return org-roam.core.ui.Select
function M:on_choice(f)
    self.__emitter:on(EVENTS.CHOICE, f)
    return self
end

---Opens the selection dialog.
function M:open()
    if not self.__window then
        local window = Window:new({
            open = string.format("botright split | resize %s", self.__max_height),
            close_on_bufleave = true,
            focus_on_open = true,
            bufopts = {
                offset = 1,
                modifiable = true,
            },
            widgets = {
                function() return self:__render_widget() end,
                function() return self:__reset_cursor_and_mode() end,
            },
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
        window:on_close(function()
            -- Emit a cancellation, which will only count if we have
            -- not selected first
            self.__emitter:emit(EVENTS.INTERNAL_CHOICE_OR_CANCEL)
            self.__window = nil
        end)

        -- When new text is inserted, mark as needing a refresh
        vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = window:bufnr(),
            callback = function()
                if self.__filtered.text ~= self:__get_filter_text() then
                    self:__render()
                end
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
    self:__render()
end

---Closes the selection dialog, canceling the choice.
function M:close()
    if self.__window then
        self.__window:close()
    end
    self.__window = nil
end

---Returns true if the selection dialog is open.
---@return boolean
function M:is_open()
    return self.__window ~= nil and self.__window:is_open()
end

---Updates the items shown by the selection dialog.
---@param items table
function M:update_items(items)
    -- Update our items
    self.__items = items

    -- Reset selection position to the first item
    -- NOTE: This is the same way that telescope and emacs do things.
    self.__selection = 1

    -- Update the filtered items
    self:__get_or_update_filtered_items()

    -- Schedule an update of the view
    self:__render()
end

---@private
function M:__select_move_down()
    local cnt = #self.__filtered.items
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
    local item = self.__items[utils.table.get(self.__filtered.items, idx, 1)]
    self.__emitter:emit(EVENTS.SELECT_CHANGE, item, idx)

    -- Schedule an update of the view
    self:__render()
end

---@private
function M:__select_move_up()
    local cnt = #self.__filtered.items
    local idx = self.__selection

    -- Rules:
    --
    -- 1. If we have not selected (0), place us at last item
    -- 2. If we are less than first choice, decrement
    -- 3. Otherwise, we are moving past first choice, place us at last item
    if idx <= 1 then
        idx = cnt
    else
        idx = idx - 1
    end
    if cnt < 1 then
        idx = 0
    end
    self.__selection = idx

    -- Notify of a selection change
    local item = self.__items[utils.table.get(self.__filtered.items, idx, 1)]
    self.__emitter:emit(EVENTS.SELECT_CHANGE, item, idx)

    -- Schedule an update of the view
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
    local item = self.__filtered.items[idx]
    if item then
        idx = item[1]
        item = self.__items[idx]
        if item then
            self.__emitter:emit(EVENTS.INTERNAL_CHOICE_OR_CANCEL, item, idx)
            self:close()
        end
    end
end

---@private
function M:__refresh_filter()
    local text = self:__get_filter_text()

    -- Only do a refresh if the text has changed
    if self.__filtered.text ~= text then
        self.__emitter:emit(EVENTS.TEXT_CHANGE, text)

        -- Update our cache of filtered items
        self:__get_or_update_filtered_items()
    end
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
    -- return string.sub(line or "", string.len(self.__prompt) + 1)
    return line or ""
end

---@private
---@return {[1]:integer, [2]:any}
function M:__get_or_update_filtered_items()
    local filter_text = self:__get_filter_text()

    -- If we haven't changed our filtered text, return the cache
    if self.__filtered.text == filter_text then
        return self.__filtered.items
    end

    -- Reset selection position to the first item
    -- NOTE: This is the same way that telescope and emacs do things.
    self.__selection = 1

    local filtered = {}

    -- TODO: Do we want to support the ability to rank matches?
    for i, item in ipairs(self.__items) do
        local text = self.__format_item(item)
        if string.find(text, filter_text, 1, true) then
            table.insert(filtered, { i, item })
        end
    end

    -- Update our cache
    self.__filtered = {
        text = filter_text,
        items = filtered,
    }

    return filtered
end

---@private
function M:__update_prompt()
    local window = self.__window
    if not window or not window:is_open() then
        return
    end

    -- Create or update the mark
    self.__prompt_id = vim.api.nvim_buf_set_extmark(
        window:bufnr(),
        NAMESPACE,
        0,
        0,
        {
            id = self.__prompt_id,
            virt_text = {
                { string.format("%s/%s",
                    self.__selection,
                    #self.__filtered.items
                ), "Comment" },
                { self.__prompt, "Comment" },
            },
            hl_mode = "combine",
            right_gravity = false,
        }
    )
end

---@private
function M:__render()
    if self.__window and self.__window:is_open() then
        vim.schedule(function()
            self:__refresh_filter()
            self:__update_prompt()
            self.__window:render()
        end)
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

    -- Figure out the maximum items we can show
    local size = window:size()
    local cnt = size[1] - 1

    for i, x in ipairs(self:__get_or_update_filtered_items()) do
        -- Stop once we exceed our max supported item to display
        if i > cnt then
            break
        end

        local text = self.__format_item(x[2])

        if i == self.__selection then
            text = string.format("* %s", text)
        else
            text = string.format("  %s", text)
        end

        table.insert(lines, text)
    end

    return lines
end

---@private
---@return string[]
function M:__reset_cursor_and_mode()
    local window = self.__window
    if not window or not window:is_open() then
        return {}
    end

    local winnr = assert(window:winnr(), "missing window handle")

    -- Point our cursor to the prompt line (at the beginning)
    vim.api.nvim_win_set_cursor(winnr, { 1, 0 })

    -- Reset to insert mode again, and start insert with ! to place at end
    -- of the prompt line while within insert mode
    vim.cmd("startinsert!")

    return {}
end

return M
