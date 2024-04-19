local OrgFile = require("orgmode.files.file")
local io = require("org-roam.core.utils.io")
local path = require("org-roam.core.utils.path")
local Select = require("org-roam.core.ui.select")
local unpack = require("org-roam.core.utils.table").unpack
local uuid_v4 = require("org-roam.core.utils.random").uuid_v4

local ORG_FILES_DIR = (function()
    local str = debug.getinfo(2, "S").source:sub(2)
    return path.join(vim.fs.dirname(str:match("(.*/)")), "files")
end)()

local VIM_CMD = vim.cmd
local VIM_FN_GETCHAR = vim.fn.getchar
local VIM_FN_CONFIRM = vim.fn.confirm
local VIM_FN_ORGMODE_INPUT = vim.fn.OrgmodeInput
local SELECT_NEW = Select.new

---@class spec.utils
local M = {}

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

    return table.concat(vim.tbl_map(function(line)
        return string.sub(line, indent + 1)
    end, lines), "\n")
end

---Creates a new orgfile, stripping common indentation.
---@param content string
---@return OrgFile
function M.org_file(content)
    local lines = vim.split(M.indent(content), "\n")
    local filename = vim.fn.tempname() .. ".org"

    ---@type OrgFile
    local file = OrgFile:new({
        filename = filename,
        lines = lines,
    })
    file:parse()

    return file
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
---@param f fun(choices:{item:any, label:string, idx:integer}[], this:org-roam.core.ui.Select):({item:any, label:string, idx:integer}|string|nil)
function M.mock_select_pick(f)
    M.mock_select(function(opts, new)
        local instance = new(opts)

        -- When ready, get choices to make a decision
        instance:on_ready(function()
            local choice = f(instance:filtered_choices(), instance)
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
            tbl[key] = function() return value end
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
