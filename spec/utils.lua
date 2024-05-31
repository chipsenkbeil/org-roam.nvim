local Calendar = require("orgmode.objects.calendar")
local OrgDate = require("orgmode.objects.date")
local OrgFile = require("orgmode.files.file")
local Promise = require("orgmode.utils.promise")

local io = require("org-roam.core.utils.io")
local Node = require("org-roam.core.file.node")
local path = require("org-roam.core.utils.path")
local Range = require("org-roam.core.file.range")
local Select = require("org-roam.core.ui.select")
local unpack = require("org-roam.core.utils.table").unpack
local uuid_v4 = require("org-roam.core.utils.random").uuid_v4

local ORG_FILES_DIR = (function()
    local str = debug.getinfo(2, "S").source:sub(2)
    return path.join(vim.fs.dirname(str:match("(.*/)")), "files")
end)()

local AUGROUP_NAME = "org-roam.nvim"
local VIM_CMD = vim.cmd
local VIM_FN_GETCHAR = vim.fn.getchar
local VIM_FN_CONFIRM = vim.fn.confirm
local VIM_FN_INPUT = vim.fn.input
local VIM_FN_ORGMODE_INPUT = vim.fn.OrgmodeInput
local SELECT_NEW = Select.new
local CALENDAR_NEW = Calendar.new

---@class spec.utils
local M = {}

---@return string
function M.autogroup_name()
    return AUGROUP_NAME
end

---@type boolean|nil
local __debug_enabled = nil

---Prints if debug environment variable `ROAM_DEBUG` is true.
function M.debug_print(...)
    if type(__debug_enabled) ~= "boolean" then
        local enabled = vim.env.ROAM_DEBUG
        __debug_enabled = type(enabled) == "string" and string.lower(vim.trim(enabled)) == "true" or false
    end

    if __debug_enabled then
        print(...)
    end
end

---Waits a standard amount of time for a test.
---This can be adjusted for CI usage.
---@param time? integer
function M.wait(time)
    vim.wait(time or M.wait_time())
end

---@type integer|nil
local __wait_time

---Returns the standard wait time used across tests.
---@return integer
function M.wait_time()
    -- Calculate our wait time the first time we are executed
    if not __wait_time then
        local stime = vim.env.ROAM_WAIT_TIME

        -- If we were given `ROAM_WAIT_TIME`, try to parse it as milliseconds
        if type(stime) == "string" then
            stime = tonumber(stime)
        end

        -- If no explicit time set, but we are in a CI, use bigger number
        if not stime and vim.env.CI == "true" then
            stime = 500
        end

        __wait_time = type(stime) == "number" and stime or 100
        M.debug_print("WAIT TIME", __wait_time)
    end

    return __wait_time
end

---Takes string, splits into lines, and removes common indentation.
---@param s string
---@return string
function M.indent(s)
    local lines = vim.split(s, "\n")
    local nonempty_lines = vim.tbl_filter(function(line)
        return vim.trim(line) ~= ""
    end, lines)

    ---@type integer
    local indent = 0
    if #nonempty_lines > 0 then
        ---@type integer
        indent = math.min(unpack(vim.tbl_map(function(line)
            local _, cnt = string.find(line, "^%s+")
            return cnt or 0
        end, nonempty_lines)))
    end

    return table.concat(
        vim.tbl_map(function(line)
            return string.sub(line, indent + 1)
        end, lines),
        "\n"
    )
end

---Creates a new orgfile, stripping common indentation.
---@param content string
---@param opts? {path?:string}
---@return OrgFile
function M.org_file(content, opts)
    opts = opts or {}
    local lines = vim.split(M.indent(content), "\n")
    local filename = opts.path or vim.fn.tempname()
    if not vim.endswith(filename, ".org") then
        filename = filename .. ".org"
    end

    ---@type OrgFile
    local file = OrgFile:new({
        filename = filename,
        lines = lines,
    })
    file:parse()

    return file
end

---@return {module:string, text:string, lnum:integer, col:integer}[]
function M.qflist_items()
    local qfdata = vim.fn.getqflist({ all = true })
    return vim.tbl_map(function(item)
        return {
            module = item.module,
            text = item.text,
            lnum = item.lnum,
            col = item.col,
        }
    end, qfdata.items)
end

---@param opts? org-roam.core.file.Node.NewOpts
---@return org-roam.core.file.Node
function M.fake_node(opts)
    return Node:new(vim.tbl_deep_extend("keep", opts or {}, {
        id = uuid_v4(),
        range = Range:new({
            row = 0,
            column = 0,
            offset = 0,
        }, {
            row = 0,
            column = 0,
            offset = 0,
        }),
        file = uuid_v4() .. ".org",
        mtime = 0,
    }))
end

---Creates a new temporary directory, copies the org files
---from `files/` into it, and returns the path.
---@return string
function M.make_temp_org_files_directory()
    local root_dir = vim.fn.tempname() .. "_test_org_dir"
    assert(vim.fn.mkdir(root_dir, "p") == 1, "failed to create org directory")

    for entry in io.walk(ORG_FILES_DIR, { depth = math.huge }) do
        ---@cast entry org-roam.core.utils.io.WalkEntry
        if entry.type == "file" then
            local err, data = io.read_file_sync(entry.path)
            assert(not err, err)

            ---@cast data -nil
            err = io.write_file_sync(path.join(root_dir, entry.name), data)
            assert(not err, err)
        end
    end

    return root_dir
end

---Creates a new temporary directory.
---@return string
function M.make_temp_directory()
    local root_dir = vim.fn.tempname() .. "_test_dir"
    assert(vim.fn.mkdir(root_dir, "p") == 1, "failed to create test directory")
    return root_dir
end

---@param opts? {dir?:string, ext?:string}
---@return string
function M.make_temp_filename(opts)
    opts = opts or {}
    local filename = uuid_v4()
    if opts.dir then
        filename = M.join_path(opts.dir, filename)
    end
    if opts.ext then
        filename = filename .. "." .. opts.ext
    end
    return filename
end

---@return string
function M.random_id()
    return uuid_v4()
end

---@param ... string
---@return string
function M.join_path(...)
    return path.join(...)
end

---@param path string
---@param ... string|string[]
function M.write_to(path, ...)
    local lines = vim.tbl_flatten({ ... })
    local content = table.concat(lines, "\n")

    local err = io.write_file_sync(path, content)
    assert(not err, err)
end

---@param path string
---@param ... string|string[]
function M.append_to(path, ...)
    local lines = vim.tbl_flatten({ ... })
    local content = table.concat(lines, "\n")

    local err, data = io.read_file_sync(path)
    assert(not err, err)

    ---@cast data -nil
    err = io.write_file_sync(path, data .. content)
    assert(not err, err)
end

---@param path string
---@return string[]
function M.read_from(path)
    local err, data = io.read_file_sync(path)
    assert(not err, err)

    ---@cast data -nil
    return vim.split(data, "\n", { plain = true })
end

---@param buf? integer
---@return string[]
function M.read_buffer(buf)
    return vim.api.nvim_buf_get_lines(buf or 0, 0, -1, true)
end

---@return {all_windows:table<integer, integer>, all_buffers:table<integer, string[]>, win:integer, buf:integer, lines:string[], pos:{[1]:integer, [2]:integer}, pos_line:string}
function M.get_current_status()
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    local lines = M.read_buffer(buf)
    local pos = vim.api.nvim_win_get_cursor(win)
    local pos_line = lines[pos[1]]

    local all_buffers = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        local lines = M.read_buffer(buf)
        all_buffers[buf] = lines
    end

    local all_windows = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        all_windows[win] = vim.api.nvim_win_get_buf(win)
    end

    return {
        all_windows = all_windows,
        all_buffers = all_buffers,
        win = win,
        buf = buf,
        lines = lines,
        pos = pos,
        pos_line = pos_line,
    }
end

---Creates N new windows containing the contents of the provided files.
---@param ... string
---@return integer ...
function M.edit_files(...)
    local windows = {}
    for _, file in ipairs({ ... }) do
        vim.cmd.new()
        vim.cmd.edit(file)

        local win = vim.api.nvim_get_current_win()
        table.insert(windows, win)
    end
    return unpack(windows)
end

---Triggers the specified mapping.
---
---If `buf` provided, triggers the buffer-local mapping.
---If `wait` provided, schedules mapping and waits N milliseconds.
---@param mode org-roam.config.NvimMode
---@param lhs string
---@param opts? {buf?:integer, wait?:integer}
function M.trigger_mapping(mode, lhs, opts)
    opts = opts or {}

    local exists, mapping
    if opts.buf then
        exists, mapping = M.buffer_local_mapping_exists(opts.buf, mode, lhs)
        assert(exists, "missing buffer-local mapping " .. lhs) --[[ @cast mapping -nil ]]
    else
        exists, mapping = M.global_mapping_exists(mode, lhs)
        assert(exists, "missing global mapping " .. lhs) --[[ @cast mapping -nil ]]
    end

    if opts.wait then
        vim.schedule(mapping.callback)
        vim.wait(opts.wait)
    else
        mapping.callback()
    end
end

---Jumps to the line within the window that matches the given function.
---If no window specified, jumps within the current window.
---@param win integer
---@param line integer|fun(buf:integer, lines:string[]):(integer|nil)
---@overload fun(line:integer|fun(buf:integer, lines:string[]):(integer|nil))
function M.jump_to_line(win, line)
    if not line then
        line = win
        win = 0
    end

    if type(line) == "function" then
        local buf = vim.api.nvim_win_get_buf(win)
        local lines = M.read_buffer(buf)

        ---@type integer
        line = assert(line(buf, lines), "no line selected to jump to")
    end
    assert(line > 0, "invalid line: " .. vim.inspect(line))
    vim.api.nvim_win_set_cursor(win, { line, 0 })
end

---Checks if a global mapping exists. Returns true/false and an array
---of `maparg()` dictionaries describing the mappings".
---@param mode org-roam.config.NvimMode
---@param lhs string
---@return boolean exists, table|nil mapping
function M.global_mapping_exists(mode, lhs)
    local mappings = vim.api.nvim_get_keymap(mode)
    local lhs_escaped = vim.api.nvim_replace_termcodes(lhs, true, false, true)
    for _, map in pairs(mappings) do
        if map.lhs == lhs or map.lhs == lhs_escaped then
            return true, map
        end
    end
    return false
end

---Checks if a buffer-mapping exists. Returns true/false and an array
---of `maparg()` dictionaries describing the mappings".
---@param buf integer
---@param mode org-roam.config.NvimMode
---@param lhs string
---@return boolean exists, table|nil mapping
function M.buffer_local_mapping_exists(buf, mode, lhs)
    local mappings = vim.api.nvim_buf_get_keymap(buf, mode)
    local lhs_escaped = vim.api.nvim_replace_termcodes(lhs, true, false, true)
    for _, map in pairs(mappings) do
        if map.lhs == lhs or map.lhs == lhs_escaped then
            return true, map
        end
    end
    return false
end

---@param opts? {setup?:boolean|org-roam.Config}
---@return OrgRoam
function M.init_plugin(opts)
    opts = opts or {}
    -- Initialize an entirely new plugin and set it up
    -- so extra features like cursor node tracking works
    local roam = require("org-roam"):new()
    if opts.setup then
        local test_dir = M.make_temp_directory()
        local config = {
            directory = test_dir,
            database = {
                path = M.join_path(test_dir, "db"),
            },
        }
        if type(opts.setup) == "table" then
            config = vim.tbl_deep_extend("force", config, opts.setup)
        end
        roam.setup(config):wait()
    end
    return roam
end

---Performs common setup tasks before a test.
function M.init_before_test()
    -- Patch `vim.cmd` to support `vim.cmd.FFF()` as plenary currently
    -- does not support it and fails within orgmode
    M.patch_vim_cmd()

    -- Clear any dangling windows/buffers that may be shared
    M.clear_windows()
    M.clear_buffers()

    -- Clear any created autocmds tied to our plugin
    M.clear_autocmds(AUGROUP_NAME)
end

---Performs common cleanup tasks after a test.
function M.cleanup_after_test()
    -- Clear any created autocmds tied to our plugin
    M.clear_autocmds(AUGROUP_NAME)

    -- Clear any dangling windows/buffers that may be shared
    M.clear_windows()
    M.clear_buffers()

    -- Ensure that tests can complete by restoring cmd
    -- otherwise our tests fail or hang or something
    M.unpatch_vim_cmd()

    -- If select was mocked, unmock it
    M.unmock_select()

    -- If calendar was mocked, unmock it
    M.unmock_calendar()

    -- If inputs were mocked, unmock them
    M.unmock_vim_inputs()
end

---Deletes all autocmds tied to the specified group.
---@param group integer|string|nil
function M.clear_autocmds(group)
    group = group or AUGROUP_NAME
    local success, cmds = pcall(vim.api.nvim_get_autocmds, {
        group = group,
    })
    if not success then
        return
    end
    for _, cmd in ipairs(cmds or {}) do
        local id = cmd.id
        if id then
            vim.api.nvim_del_autocmd(id)
        end
    end
end

---Clears all windows by closing them forcibly.
function M.clear_windows()
    local wins = vim.api.nvim_list_wins()

    -- Because we cannot close the last window, create an empty window that will persist
    vim.cmd.new()

    for _, win in ipairs(wins) do
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end
end

---Clears all buffers by deleting them forcibly.
function M.clear_buffers()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end
end

---@param s string
---@return OrgDate|nil
function M.date_from_string(s)
    return OrgDate.from_string(s)
end

---@alias spec.utils.MockCalendar
---| nil
---| string
---| OrgDate
---| fun(this:OrgCalendar, data?:{date?:OrgDate, clearable?:boolean, title?:string}):(OrgDate|nil)

---Mocks `Calendar.new` such that it returns a calendar whose `:open()` yields
---the mocked value.
---@param mock spec.utils.MockCalendar
function M.mock_calendar(mock)
    ---@diagnostic disable-next-line:duplicate-set-field
    Calendar.new = function(data)
        return {
            open = function(this)
                if type(mock) == "function" then
                    return Promise.resolve(mock(this, data))
                elseif type(mock) == "string" then
                    return Promise.resolve(OrgDate.from_string(mock))
                else
                    return Promise.resolve(mock)
                end
            end,
        }
    end
end

---Unmocks calendar creation.
function M.unmock_calendar()
    Calendar.new = CALENDAR_NEW
end

---@alias spec.utils.MockSelect
---| org-roam.core.ui.Select
---| fun(opts?:org-roam.core.ui.select.Opts, new:fun(opts?:org-roam.core.ui.select.Opts):org-roam.core.ui.Select):org-roam.core.ui.Select

---Mocks core.ui.Select such that future creations use return from `f`.
---@param mock? spec.utils.MockSelect
---@param opts? {stub?:boolean}
function M.mock_select(mock, opts)
    opts = opts or {}

    ---@diagnostic disable-next-line:duplicate-set-field
    Select.new = function(this, sopts)
        local instance = {}

        if type(mock) == "function" then
            instance = mock(sopts, function(...)
                return SELECT_NEW(this, ...)
            end)
        elseif type(mock) == "table" then
            instance = mock
        end

        -- Populate any missing methods with stubs that fail with an error
        for k, v in pairs(Select) do
            if type(v) == "function" and type(instance[k]) ~= "function" then
                instance[k] = function()
                    if not opts.stub then
                        error("unmocked: " .. tostring(k))
                    end
                end
            end
        end

        return instance
    end
end

---Mocks core.ui.Select to intercept the list of choices and pick a specific
---choice or cancel.
---@param f fun(choices:{item:any, label:string, idx:integer}[], this:org-roam.core.ui.Select, helpers:spec.utils.select.Helpers):({item:any, label:string, idx:integer}|string|nil)
function M.mock_select_pick(f)
    M.mock_select(function(opts, new)
        local instance = new(opts)

        -- When ready, get choices to make a decision
        instance:on_ready(function()
            local choices = instance:filtered_choices()

            ---@class spec.utils.select.Helpers
            local helpers = {}

            function helpers.pick_with_label(label)
                for _, choice in ipairs(choices) do
                    if choice.label == label then
                        return choice
                    end
                end
            end

            local choice = f(choices, instance, helpers)
            if type(choice) == "table" then
                instance:choose({ item = choice.item, idx = choice.idx })
            elseif type(choice) == "string" then
                instance:choose({ text = choice })
            else
                instance:cancel()
            end
        end)

        return instance
    end)
end

---Unmocks core.ui.Select such that future creations are real.
function M.unmock_select()
    Select.new = SELECT_NEW
end

---@class spec.utils.MockVimInputsOpts
---@field confirm number|nil|(fun(msg:any, choices?:any, default?:any, type?:any):number)
---@field getchar number|nil|(fun(expr?:any):number)
---@field input string|nil|(fun(opts:string|table<string, any>):string)
---@field OrgmodeInput string|nil|(fun(opts:string|table<string, any>):string)

---Mocks zero or more forms of neovim inputs.
---@param opts? spec.utils.MockVimInputsOpts
function M.mock_vim_inputs(opts)
    opts = opts or {}
    local function set_value(tbl, key, value)
        if type(value) == "function" then
            tbl[key] = value
        elseif type(value) ~= "nil" then
            tbl[key] = function()
                return value
            end
        end
    end

    set_value(vim.fn, "confirm", opts.confirm)
    set_value(vim.fn, "getchar", opts.getchar)
    set_value(vim.fn, "input", opts.input)
    set_value(vim.fn, "OrgmodeInput", opts.OrgmodeInput)
end

function M.unmock_vim_inputs()
    vim.fn.getchar = VIM_FN_GETCHAR
    vim.fn.confirm = VIM_FN_CONFIRM
    vim.fn.input = VIM_FN_INPUT
    vim.fn.OrgmodeInput = VIM_FN_ORGMODE_INPUT
end

---Applies a patch to `vim.cmd` to support `vim.cmd.XYZ()`.
---Taken from neovim 0.10 source code.
---
---Needed until the following is resolved:
---https://github.com/nvim-lua/plenary.nvim/issues/453
function M.patch_vim_cmd()
    local VIM_CMD_ARG_MAX = 20
    vim.cmd = setmetatable({}, {
        __call = function(_, command)
            if type(command) == "table" then
                return vim.api.nvim_cmd(command, {})
            else
                vim.api.nvim_exec2(command, {})
                return ""
            end
        end,
        __index = function(t, command)
            t[command] = function(...)
                local opts
                if select("#", ...) == 1 and type(select(1, ...)) == "table" then
                    opts = select(1, ...)

                    -- Move indexed positions in opts to opt.args
                    if opts[1] and not opts.args then
                        opts.args = {}
                        for i = 1, VIM_CMD_ARG_MAX do
                            if not opts[i] then
                                break
                            end
                            opts.args[i] = opts[i]
                            opts[i] = nil
                        end
                    end
                else
                    opts = { args = { ... } }
                end
                opts.cmd = command
                return vim.api.nvim_cmd(opts, {})
            end
            return t[command]
        end,
    })
end

---Removes patch from `vim.cmd`.
function M.unpatch_vim_cmd()
    vim.cmd = VIM_CMD
end

return M
