-------------------------------------------------------------------------------
-- SELECT.LUA
--
-- Fancy alternative to `vim.ui.select` for us to use.
-- Modelled after Emacs' vertico completion (https://github.com/minad/vertico).
-------------------------------------------------------------------------------

local C = require("org-roam.core.ui.component")
local Emitter = require("org-roam.core.utils.emitter")
local tbl_utils = require("org-roam.core.utils.table")
local Window = require("org-roam.core.ui.window")

---Collection of events that can be fired.
local EVENTS = {
    ---Selection dialog is canceled.
    CANCEL = "select:cancel",

    ---A specific choice from items has been made.
    CHOICE = "select:choice",

    ---No item was available, so non-existent item has been selected.
    CHOICE_INPUT = "select:choice-input",

    ---Internal, mapping between choices and cancellation.
    INTERNAL_MULTIPLEX = "internal:select:multiplex",

    ---Selection has been changed.
    SELECT_CHANGE = "select:select_change",

    ---Input text has been changed.
    TEXT_CHANGE = "select:text_change",
}

local HIGHLIGHTS = {
    ---Highlight group for unselected text
    NORMAL = "Normal",
    ---Highlight group for selected text
    SELECTED = "PmenuSel",
    ---Highlight group whose foreground color is used for matches
    MATCHED_FG = "WarningMsg",
    ---Highlight group for unselected, matched text
    MATCHED = "@org-roam.core.ui.select.matched",
    ---Highlight group for selected, matched text
    SELECTED_MATCHED = "@org-roam.core.ui.select.selected-matched",
}

---Initializes highlights globally for the select ui.
local init_highlights = (function()
    local initialized = false
    return function()
        if initialized then
            return
        end

        local function define_colors()
            -- Define custom highlight group for matching
            local normal_hl = vim.api.nvim_get_hl(0, { name = HIGHLIGHTS.NORMAL })
            local selected_hl = vim.api.nvim_get_hl(0, { name = HIGHLIGHTS.SELECTED })
            local fg = vim.api.nvim_get_hl(0, { name = HIGHLIGHTS.MATCHED_FG }).fg
            vim.api.nvim_set_hl(
                0,
                HIGHLIGHTS.MATCHED,
                vim.tbl_extend("keep", { fg = string.format("#%x", fg) }, normal_hl)
            )
            vim.api.nvim_set_hl(
                0,
                HIGHLIGHTS.SELECTED_MATCHED,
                vim.tbl_extend("keep", { fg = string.format("#%x", fg) }, selected_hl)
            )
        end

        -- Listen for changes in color scheme and re-apply our highlights
        local group = vim.api.nvim_create_augroup("org-roam.core.ui.select", {})
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = group,
            pattern = "*",
            callback = function()
                define_colors()
            end,
        })

        -- Define our colors once and mark initialized
        define_colors()
        initialized = true
    end
end)()

---@class (exact) org-roam.core.ui.select.View
---@field filtered_items {[1]:integer, [2]:string}[] #list of tuples representing indexes of items and labels to display
---@field start integer #position within filtered items where items will be collected to show (up to max)
---@field selected integer #position of selected item within viewed items
---@field max_rows integer #maximum rows of viewed items to display
---@field prompt string #prompt that appears on same line as input
---@field input string #user-provided input

---@class (exact) org-roam.core.ui.select.State
---@field prompt_id integer|nil #id of the virtual text prompt
---@field emitter org-roam.core.utils.Emitter #event manager
---@field window org-roam.core.ui.Window|nil #internal window

---@class (exact) org-roam.core.ui.select.Params
---@field items table #raw items available for selection (non-filtered)
---@field init_input string #initial text to supply at the beginning
---@field auto_select boolean #if true, will select automatically if only one item (filtered) based on init_input
---@field allow_select_missing boolean #if true, enables selecting non-existent items
---@field bindings org-roam.core.ui.select.Bindings #bindings associated with the window
---@field format fun(item:any):string #converts item into displayed text
---@field match fun(item:any, input:string):{[1]:integer, [2]:integer}[] #returns ranges (start/end col) of matches (one-indexed, inclusive)
---@field rank fun(item:any, input:string):number #ranks items based on some input, higher number means shown earlier

---@class (exact) org-roam.core.ui.select.Bindings
---@field down string[] #one or more bindings to move selection down
---@field up string[] #one or more bindings to move selection up
---@field select string[] #one or more bindings to trigger selection
---@field select_missing string[] #one or more bindings to directly trigger selection as a missing item

---@class org-roam.core.ui.Select
---@field private __params org-roam.core.ui.select.Params
---@field private __state org-roam.core.ui.select.State
---@field private __view org-roam.core.ui.select.View
local M = {}
M.__index = M

---@class org-roam.core.ui.select.Opts
---@field items table
---@field max_displayed_rows? integer
---@field prompt? string
---@field init_input? string
---@field auto_select? boolean
---@field allow_select_missing? boolean
---@field bindings? {down?:string|string[], up?:string|string[], select?:string|string[], select_missing?:string|string[]}
---@field format? fun(item:any):string
---@field match? fun(item:any, input:string):{[1]:integer, [2]:integer}[]
---@field rank? fun(item:any, text:string):number

---Creates a new org-roam select dialog.
---@param opts? org-roam.core.ui.select.Opts
---@return org-roam.core.ui.Select
function M:new(opts)
    opts = opts or {}

    local instance = {}
    setmetatable(instance, M)

    local allow_select_missing = opts.allow_select_missing or false
    local default_bindings = {
        down = { "<C-n>", "<Down>" },
        up = { "<C-p>", "<Up>" },
        select = { "<Enter>", "<S-Enter>", "<C-Enter>", "<C-S-Enter>" },
        select_missing = {},
    }

    -- If we allow selecting non-existent items, then update default bindings
    -- to support Shift+Enter or Control+Shift+Enter to force that binding
    if allow_select_missing then
        default_bindings.select = { "<Enter>", "<C-Enter>" }
        default_bindings.select_missing = { "<S-Enter>", "<C-S-Enter>" }
    end

    -- Generate bindings from user input
    ---@param tbl table<string, string|string[]>
    ---@return table<string, string[]>
    local function clean_bindings(tbl)
        local new = {}
        for key, value in pairs(tbl) do
            if type(value) == "string" then
                new[key] = { value }
            elseif type(value) == "table" then
                new[key] = value
            end
        end
        return new
    end
    local bindings = clean_bindings(opts.bindings or {})

    local format = opts.format or function(item) return tostring(item) end
    local match = opts.match or function(item, input)
        local text = string.lower(format(item))
        input = string.lower(input)

        -- Get inclusive start/end (one-indexed)
        local start, end_ = string.find(text, input, 1, true)
        if start and end_ then
            return { { start, end_ } }
        else
            return {}
        end
    end
    instance.__params = {
        items = opts.items or {},
        init_input = opts.init_input or "",
        auto_select = opts.auto_select or false,
        allow_select_missing = allow_select_missing,
        bindings = vim.tbl_deep_extend("keep", bindings, default_bindings),
        format = format,
        match = match,
        rank = opts.rank,
    }

    instance.__state = {
        emitter = Emitter:new(),
        prompt_id = nil,
        window = nil,
    }

    instance.__view = {
        filtered_items = {}, -- To be populated
        start = 1,
        selected = 1,
        max_rows = opts.max_displayed_rows or 8,
        prompt = opts.prompt or "",
        input = instance.__params.init_input .. "|", -- Force refresh
    }

    return instance
end

---Register callback when the selection dialog is canceled.
---@param f fun()
---@return org-roam.core.ui.Select
function M:on_cancel(f)
    self.__state.emitter:on(EVENTS.CANCEL, f)
    return self
end

---Register callback when the text to filter selection is changed.
---@param f fun(text:string)
---@return org-roam.core.ui.Select
function M:on_text_change(f)
    self.__state.emitter:on(EVENTS.TEXT_CHANGE, f)
    return self
end

---Register callback when the selection is changed.
---
---This can be triggered if nothing is selected.
---In this case, idx will be 0.
---@param f fun(item:any|nil, idx:integer)
---@return org-roam.core.ui.Select
function M:on_select_change(f)
    self.__state.emitter:on(EVENTS.SELECT_CHANGE, f)
    return self
end

---Register callback when a selection is made.
---This is not triggered if the selection is canceled.
---@param f fun(item:any, idx:integer)
---@return org-roam.core.ui.Select
function M:on_choice(f)
    self.__state.emitter:on(EVENTS.CHOICE, f)
    return self
end

---Register callback when a selection is made for a non-existent item.
---This will only be triggered when selection of missing items is enabled.
---This is not triggered if the selection is canceled.
---@param f fun(item:string)
---@return org-roam.core.ui.Select
function M:on_choice_missing(f)
    self.__state.emitter:on(EVENTS.CHOICE_INPUT, f)
    return self
end

---Opens the selection dialog.
function M:open()
    if not self.__state.window then
        init_highlights()

        local window = Window:new({
            name = "org-roam-select",
            open = Window.calc_open.bottom(self.__view.max_rows + 1),
            close_on_bufleave = true,
            destroy_on_close = true,
            focus_on_open = true,
            bufopts = {
                offset = 1,
                modifiable = true,
            },
            winopts = {
                cursorline = false,
            },
            components = { function() return self:__render_component() end },
        })

        -- If we have some initial filter text, set it on the buffer
        if string.len(self.__params.init_input) > 0 then
            vim.api.nvim_buf_set_lines(window:bufnr(), 0, -1, true, {
                self.__params.init_input,
            })
        end

        local ready = false
        window:buffer():on_post_render(function()
            local winnr = window:winnr()
            if not ready and winnr then
                -- Point our cursor to the prompt line (at the beginning)
                vim.api.nvim_win_set_cursor(winnr, { 1, 0 })

                -- Reset to insert mode again, and start insert with ! to place at end
                -- of the prompt line while within insert mode
                vim.api.nvim_buf_call(window:bufnr(), function()
                    vim.cmd("startinsert!")
                end)

                -- Mark ready so we don't reset the cursor again
                ready = true
            end
        end)

        -- Register a one-time emitter for selecting or cancelling
        -- so we can ensure only one is triggered.
        ---@param tbl {type:string}
        self.__state.emitter:once(EVENTS.INTERNAL_MULTIPLEX, function(tbl)
            if tbl.type == EVENTS.CHOICE then
                ---@cast tbl {type:string, item:any, idx:integer}
                self.__state.emitter:emit(EVENTS.CHOICE, tbl.item, tbl.idx)
            elseif tbl.type == EVENTS.CHOICE_INPUT then
                ---@cast tbl {type:string, text:string}
                self.__state.emitter:emit(EVENTS.CHOICE_INPUT, tbl.text)
            elseif tbl.type == EVENTS.CANCEL then
                self.__state.emitter:emit(EVENTS.CANCEL)
            end

            -- NOTE: We schedule to avoid triggering more than one event
            --       during the closing of the window. For instance, a
            --       choice is selected, we close, and that causes cancel
            --       to also fire for some reason.
            vim.schedule(function() self:close() end)
        end)

        -- When the window closes, we trigger our callback
        -- only if it hasn't been triggered earlier as this
        -- situation is when someone cancels the selection.
        window:on_close(function()
            -- Emit a cancellation, which will only count if we have
            -- not selected first
            self.__state.emitter:emit(EVENTS.INTERNAL_MULTIPLEX, {
                type = EVENTS.CANCEL,
            })
            self.__state.window = nil
        end)

        -- When new text is inserted, mark as needing a refresh
        vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = window:bufnr(),
            callback = function()
                if self.__view.input ~= self:__get_input() then
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

        local kopts = {
            buffer = window:bufnr(),
            noremap = true,
        }

        -- Changing selection (down)
        for _, lhs in ipairs(self.__params.bindings.down) do
            vim.keymap.set("i", lhs, function() self:__select_move_down() end, kopts)
        end

        -- Changing selection (up)
        for _, lhs in ipairs(self.__params.bindings.up) do
            vim.keymap.set("i", lhs, function() self:__select_move_up() end, kopts)
        end

        -- Register callback when selecting a choice that exists
        for _, lhs in ipairs(self.__params.bindings.select) do
            vim.keymap.set("i", lhs, function() self:__trigger_selection() end, kopts)
        end

        -- Register callback when selecting a choice that does not exist
        for _, lhs in ipairs(self.__params.bindings.select_missing) do
            vim.keymap.set("i", lhs, function() self:__trigger_input_selection() end, kopts)
        end

        self.__state.window = window
    end

    self.__state.window:open()
    self:__render()
end

---Closes the selection dialog, canceling the choice.
function M:close()
    local window = self.__state.window
    self.__state.window = nil

    if window then
        window:close()
    end
end

---Returns true if the selection dialog is open.
---@return boolean
function M:is_open()
    return self.__state.window ~= nil and self.__state.window:is_open()
end

---Updates the items shown by the selection dialog.
---@param items table
function M:update_items(items)
    -- Update our items
    self.__params.items = items

    -- Reset selection position and visible items to the first item
    -- NOTE: This is the same way that telescope and emacs do things.
    self.__view.selected = 1
    self.__view.start = 1

    -- Update the filtered items
    self:__update_filtered_items()

    -- Schedule an update of the view
    self:__render()
end

---@private
function M:__select_move_down()
    local cnt = #self.__view.filtered_items
    local idx = self.__view.selected
    local start = self.__view.start

    -- Rules:
    --
    -- 1. If we have not selected (0), place us at first item
    -- 2. If we are less than max choices, increment
    -- 3. Otherwise, we are moving past max choices, so place back at top
    if idx < 1 or idx >= cnt then
        idx = 1
        start = 1
    else
        idx = idx + 1

        -- If we are going out of view, update the start
        if idx >= start + self.__view.max_rows then
            start = start + 1
        end
    end
    if cnt < 1 then
        idx = 0
        start = 1
    end
    self.__view.selected = idx
    self.__view.start = start

    -- Notify of a selection change
    local item = self.__params.items[tbl_utils.get(self.__view.filtered_items, idx, 1)]
    self.__state.emitter:emit(EVENTS.SELECT_CHANGE, item, idx)

    -- Schedule an update of the view
    self:__render()
end

---@private
function M:__select_move_up()
    local cnt = #self.__view.filtered_items
    local idx = self.__view.selected
    local start = self.__view.start

    -- Rules:
    --
    -- 1. If we have not selected (0), place us at last item
    -- 2. If we are less than first choice, decrement
    -- 3. Otherwise, we are moving past first choice, place us at last item
    if idx <= 1 then
        idx = cnt
        start = cnt - math.min(self.__view.max_rows, cnt) + 1
    else
        idx = idx - 1

        -- If we are going out of view, update the start
        if idx < start then
            start = idx
        end
    end
    if cnt < 1 then
        idx = 0
        start = 1
    end
    self.__view.selected = idx
    self.__view.start = start

    -- Notify of a selection change
    local item = self.__params.items[tbl_utils.get(self.__view.filtered_items, idx, 1)]
    self.__state.emitter:emit(EVENTS.SELECT_CHANGE, item, idx)

    -- Schedule an update of the view
    self:__render()
end

---@private
function M:__trigger_selection()
    -- If there is nothing to select, ignore enter; otherwise,
    -- we have an item, which we pick out
    local idx = self.__view.selected
    local item = self.__view.filtered_items[idx]
    if not item then
        if self.__params.allow_select_missing then
            self.__state.emitter:emit(EVENTS.INTERNAL_MULTIPLEX, {
                type = EVENTS.CHOICE_INPUT,
                text = self:__get_input(),
            })
        end

        return
    end

    ---@type integer
    idx = item[1]

    ---@type any
    item = self.__params.items[idx]

    if item then
        self.__state.emitter:emit(EVENTS.INTERNAL_MULTIPLEX, {
            type = EVENTS.CHOICE,
            item = item,
            idx = idx,
        })
    end
end

---@private
function M:__trigger_input_selection()
    local text = self:__get_input()
    if text ~= "" then
        self.__state.emitter:emit(EVENTS.INTERNAL_MULTIPLEX, {
            type = EVENTS.CHOICE_INPUT,
            text = text,
        })
    end
end

---@private
function M:__refresh_filter()
    local text = self:__get_input()

    -- Only do a refresh if the text has changed
    if self.__view.input ~= text then
        self.__state.emitter:emit(EVENTS.TEXT_CHANGE, text)

        -- Update our cache of filtered items
        self:__update_filtered_items()
    end

    -- If we got exactly one item with our initial filter and we have
    -- enabled auto-select, or we support allowing missing selection
    -- and have no items with auto-select enabled, we're done and we
    -- should return it
    if self.__params.auto_select then
        local is_initial_input = text == self.__params.init_input
        local is_nonempty = vim.trim(text) ~= ""
        local has_one_item = #self.__view.filtered_items == 1
        local use_missing = self.__params.allow_select_missing
            and #self.__view.filtered_items == 0
        if is_nonempty and is_initial_input and (has_one_item or use_missing) then
            self:__trigger_selection()
        end
    end
end

---@private
---@return string
function M:__get_input()
    local window = self.__state.window
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
function M:__update_filtered_items()
    local input = self:__get_input()

    -- If we haven't changed our filtered text, return the cache
    if self.__view.input == input then
        return self.__view.filtered_items
    end

    -- Reset selection and start position to the first item
    -- NOTE: This is the same way that telescope and emacs do things.
    self.__view.selected = 1
    self.__view.start = 1

    ---@type {[1]:integer, [2]:any, [3]:number|nil}
    local filtered = {}
    local rank = self.__params.rank

    for i, item in ipairs(self.__params.items) do
        local keep = input == ""

        -- If input not empty, check if we match anything, which means keep it
        if not keep then
            local matches = self.__params.match(item, input)
            keep = not vim.tbl_isempty(matches)
        end

        if keep then
            local x = { i, item }
            if rank then
                x[3] = rank(item, input)
            end
            table.insert(filtered, x)
        end
    end

    -- If rank function provided, sort filtered from highest rank to lowest
    if rank then
        table.sort(filtered, function(a, b)
            return a[3] > b[3]
        end)
    end

    -- Update our cache
    self.__view.input = input
    self.__view.filtered_items = filtered

    return filtered
end

---@private
function M:__update_prompt()
    local window = self.__state.window
    if not window or not window:is_open() then
        return
    end

    -- Build our prompt text
    local text = self.__view.prompt
    text = string.gsub(text, "{sel}", self.__view.selected)
    text = string.gsub(text, "{cnt}", #self.__view.filtered_items)

    local opts = {
        id = self.__state.prompt_id,
        virt_text = { { text, "Comment" } },
        hl_mode = "combine",
        right_gravity = false,
    }

    -- TODO: Once neovim 0.10 is fully released and we drop support
    --       for neovim 0.9, this can be moved into the options above.
    if vim.fn.has("nvim-0.10") == 1 then
        opts.virt_text_pos = "inline"
    end

    -- Create or update the mark
    self.__state.prompt_id = vim.api.nvim_buf_set_extmark(
        window:bufnr(), window:buffer():namespace(), 0, 0, opts)
end

---@private
function M:__render()
    local window = self.__state.window
    if window and window:is_open() then
        vim.schedule(function()
            self:__refresh_filter()
            self:__update_prompt()

            -- Double-check we still have a window, and re-render
            window = self.__state.window
            if window then
                window:render()
            end
        end)
    end
end

---@private
---@return org-roam.core.ui.Line[]
function M:__render_component()
    local window = self.__state.window
    if not window then
        return {}
    end

    local winnr = assert(window:winnr(), "missing window handle")
    local width = vim.api.nvim_win_get_width(winnr)

    ---@return org-roam.core.ui.Line[]
    local lines = {}

    -- Refresh the filtered items
    self:__update_filtered_items()

    local input = self:__get_input()
    local start = self.__view.start
    local end_ = math.min(
        self.__view.start + self.__view.max_rows - 1,
        #self.__view.filtered_items
    )

    -- Loop through filtered items, beginning at the start position
    -- and continuing through max rows
    for i = start, end_ do
        local selected = i == self.__view.selected
        local item = self.__view.filtered_items[i]
        local text = self.__params.format(item[2])
        local highlight = HIGHLIGHTS.NORMAL
        local matched_highlight = HIGHLIGHTS.MATCHED

        -- Pad our text to fill the length of the window such that
        -- highlighting smoothly covers the entire line
        local padding = width - string.len(text)
        if padding > 0 then
            text = text .. string.rep(" ", padding)
        end

        -- For our selected item, adjust the highlight
        if selected then
            highlight = HIGHLIGHTS.SELECTED
            matched_highlight = HIGHLIGHTS.SELECTED_MATCHED
        end

        local raw_item = self.__params.items[item[1]]
        local matches = self.__params.match(raw_item, input)
        table.sort(matches, function(a, b) return a[1] < b[1] end)

        -- Build up our line segments (start, end, highlight) (one-indexed, end-inclusive)
        ---@type {[1]:integer, [2]:integer, [3]:string}
        local segments = {}
        for _, match in ipairs(matches) do
            local last_segment = segments[#segments] or { 0, 0, "" }
            local mstart, mend = match[1], match[2]

            -- If there is a gap between the last segment and our match,
            -- we need to add in a segment first leading up to our match
            if last_segment[1] + 1 < mstart then
                table.insert(segments, { last_segment[1] + 1, mstart - 1, highlight })
            end

            table.insert(segments, { mstart, mend, matched_highlight })
        end

        -- Last segment is anything remaining
        local last_segment = segments[#segments] or { 0, 0, "" }
        if last_segment[2] < string.len(text) then
            table.insert(segments, { last_segment[2] + 1, string.len(text), highlight })
        end

        -- Build our line as a single segment with highlight
        table.insert(lines, vim.tbl_map(function(segment)
            return C.hl(string.sub(text, segment[1], segment[2]), segment[3])
        end, segments))
    end

    return lines
end

return M
