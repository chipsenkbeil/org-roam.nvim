-------------------------------------------------------------------------------
-- LOG.LUA
--
-- Logging API to console and files.
-- Modified from plenary.nvim's log.lua.
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
-------------------------------------------------------------------------------

---@type string|false
local p_debug = vim.fn.getenv("DEBUG_ORG_ROAM")
if p_debug == vim.NIL then
    p_debug = false
end

-- User configuration section
---@class org-roam.core.log.Config
local default_config = {
    -- Name of the plugin. Prepended to log messages.
    ---@type string
    plugin = "org-roam",

    -- Should print the output to neovim while running.
    ---@type '"sync"'|'"async"'|false
    use_console = "async",

    -- Should highlighting be used in console (using echohl).
    ---@type boolean
    highlights = true,

    -- Should write to a file.
    -- Default output for logging file is `stdpath("cache")/plugin`.
    ---@type boolean
    use_file = true,

    -- Output file has precedence over plugin, if not nil.
    -- Used for the logging file, if not nil and use_file == true.
    ---@type string|nil
    outfile = nil,

    -- Should write to the quickfix list.
    ---@type boolean
    use_quickfix = false,

    ---Should only include path after `lua` directory.
    ---@type boolean
    use_short_src_path = true,

    -- Any messages above this level will be logged.
    ---@type org-roam.core.log.Level
    level = p_debug and "debug" or "info",

    -- Level configuration.
    ---@alias org-roam.core.log.Level
    ---| '"trace"'
    ---| '"debug"'
    ---| '"info"'
    ---| '"warn"'
    ---| '"error"'
    ---| '"fatal"'
    ---@type {name:org-roam.core.log.Level, hl:string}[]
    modes = {
        { name = "trace", hl = "Comment" },
        { name = "debug", hl = "Comment" },
        { name = "info",  hl = "None" },
        { name = "warn",  hl = "WarningMsg" },
        { name = "error", hl = "ErrorMsg" },
        { name = "fatal", hl = "ErrorMsg" },
    },

    -- Can limit the number of decimals displayed for floats.
    ---@type number
    float_precision = 0.01,

    -- Adjust content as needed, but must keep function parameters to be filled
    -- by library code.
    ---@param is_console boolean If output is for console or log file.
    ---@param mode_name string Level configuration 'modes' field 'name'
    ---@param src_path string Path to source file given by debug.info.source
    ---@param src_line integer Line into source file given by debug.info.currentline
    ---@param msg string Message, which is later on escaped, if needed.
    fmt_msg = function(is_console, mode_name, src_path, src_line, msg)
        local nameupper = mode_name:upper()
        local lineinfo = src_path .. ":" .. src_line
        if is_console then
            return string.format("[%-6s%s] %s: %s", nameupper, os.date "%H:%M:%S", lineinfo, msg)
        else
            return string.format("[%-6s%s] %s: %s\n", nameupper, os.date(), lineinfo, msg)
        end
    end,

    ---@type integer|nil
    info_level = nil,
}


---Makes internal functions for logging that we'll use at a higher level.
---@param config org-roam.core.log.Config
local function make_internal_logger(config)
    config = vim.tbl_deep_extend("force", default_config, config)

    local join_path = require("org-roam.core.utils.path").join

    ---@type string|nil
    local outfile = vim.F.if_nil(
        config.outfile,
        join_path(vim.api.nvim_call_function("stdpath", { "cache" }), config.plugin .. ".log")
    )

    local obj = { config = config }

    ---@type {[org-roam.core.log.Level]: integer}
    obj.levels = {}
    for i, v in ipairs(config.modes) do
        obj.levels[v.name] = i
    end

    ---@param x number
    ---@param increment number
    local round = function(x, increment)
        increment = increment or 1
        x = x / increment
        return (x > 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)) * increment
    end

    ---@param ...any
    ---@return string
    function obj.make_string(...)
        local t = {}
        for i = 1, select("#", ...) do
            local x = select(i, ...)

            if type(x) == "number" and obj.config.float_precision then
                x = tostring(round(x, obj.config.float_precision))
            elseif type(x) == "table" then
                x = vim.inspect(x)
            else
                x = tostring(x)
            end

            t[#t + 1] = x
        end
        return table.concat(t, " ")
    end

    ---@param level integer
    ---@param level_config {name:org-roam.core.log.Level, hl:string}
    ---@param message_maker fun(...):string
    ---@param ...any
    function obj.log_at_level(level, level_config, message_maker, ...)
        -- Return early if we're below the config.level
        if level < obj.levels[obj.config.level] then
            return
        end
        local msg = message_maker(...)
        local info = debug.getinfo(obj.config.info_level or 2, "Sl")
        local src_path = info.source:sub(2)
        if obj.config.use_short_src_path then
            local _, end_ = string.find(src_path, "lua")
            if end_ then
                -- Start after the / or \ of the lua directory
                src_path = string.sub(src_path, end_ + 2)
            end
        end
        local src_line = info.currentline
        -- Output to console
        if obj.config.use_console then
            local log_to_console = function()
                local console_string = obj.config.fmt_msg(true, level_config.name, src_path, src_line, msg)

                if obj.config.highlights and level_config.hl then
                    vim.cmd(string.format("echohl %s", level_config.hl))
                end

                local split_console = vim.split(console_string, "\n")
                for _, v in ipairs(split_console) do
                    local formatted_msg = string.format("[%s] %s", obj.config.plugin, vim.fn.escape(v, [["\]]))

                    ---@diagnostic disable-next-line:param-type-mismatch
                    local ok = pcall(vim.cmd, string.format([[echom "%s"]], formatted_msg))
                    if not ok then
                        vim.api.nvim_out_write(msg .. "\n")
                    end
                end

                if obj.config.highlights and level_config.hl then
                    vim.cmd "echohl NONE"
                end
            end
            if obj.config.use_console == "sync" and not vim.in_fast_event() then
                log_to_console()
            else
                vim.schedule(log_to_console)
            end
        end

        -- Output to log file
        if obj.config.use_file and outfile then
            local outfile_parent_path = vim.fs.dirname(outfile)
            -- Returns 0 if does not exist, or 1 if does exist
            if vim.fn.isdirectory(outfile_parent_path) == 0 then
                -- Create directory and any intermediate pieces
                vim.fn.mkdir(outfile_parent_path, "p")
            end
            local fp = assert(io.open(outfile, "a"))
            local str = obj.config.fmt_msg(false, level_config.name, src_path, src_line, msg)
            fp:write(str)
            fp:close()
        end

        -- Output to quickfix
        if obj.config.use_quickfix then
            local nameupper = level_config.name:upper()
            local formatted_msg = string.format("[%s] %s", nameupper, msg)
            local qf_entry = {
                -- remove the @ getinfo adds to the file path
                filename = info.source:sub(2),
                lnum = info.currentline,
                col = 1,
                text = formatted_msg,
            }
            vim.fn.setqflist({ qf_entry }, "a")
        end
    end

    return obj
end

local __logger = make_internal_logger(default_config)

---@class org-roam.core.Logger
---
---@field trace fun(...) #general verbatim logger
---@field fmt_trace fun(...) #log using string formatting against the first argument
---@field lazy_trace fun(f:fun():string) #log by invoking the function and logging the results
---@field file_trace fun(...) #log only to file, not console
---
---@field debug fun(...) #general verbatim logger
---@field fmt_debug fun(...) #log using string formatting against the first argument
---@field lazy_debug fun(f:fun():string) #log by invoking the function and logging the results
---@field file_debug fun(...) #log only to file, not console
---
---@field info fun(...) #general verbatim logger
---@field fmt_info fun(...) #log using string formatting against the first argument
---@field lazy_info fun(f:fun():string) #log by invoking the function and logging the results
---@field file_info fun(...) #log only to file, not console
---
---@field warn fun(...) #general verbatim logger
---@field fmt_warn fun(...) #log using string formatting against the first argument
---@field lazy_warn fun(f:fun():string) #log by invoking the function and logging the results
---@field file_warn fun(...) #log only to file, not console
---
---@field error fun(...) #general verbatim logger
---@field fmt_error fun(...) #log using string formatting against the first argument
---@field lazy_error fun(f:fun():string) #log by invoking the function and logging the results
---@field file_error fun(...) #log only to file, not console
---
---@field fatal fun(...) #general verbatim logger
---@field fmt_fatal fun(...) #log using string formatting against the first argument
---@field lazy_fatal fun(f:fun():string) #log by invoking the function and logging the results
---@field file_fatal fun(...) #log only to file, not console
local M = {}

for i, x in ipairs(__logger.config.modes) do
    local unpack = require("org-roam.core.utils.table").unpack

    -- log.info("these", "are", "separated")
    M[x.name] = function(...)
        return __logger.log_at_level(i, x, __logger.make_string, ...)
    end

    -- log.fmt_info("These are %s strings", "formatted")
    M[("fmt_%s"):format(x.name)] = function(...)
        return __logger.log_at_level(i, x, function(...)
            local passed = { ... }
            local fmt = table.remove(passed, 1)
            local inspected = {}
            for _, v in ipairs(passed) do
                table.insert(inspected, vim.inspect(v))
            end
            return string.format(fmt, unpack(inspected))
        end, ...)
    end

    -- log.lazy_info(expensive_to_calculate)
    M[("lazy_%s"):format(x.name)] = function(f)
        return __logger.log_at_level(i, x, function(f)
            return f()
        end, f)
    end

    -- log.file_info("do not print")
    M[("file_%s"):format(x.name)] = function(vals, override)
        local original_console = __logger.config.use_console

        ---@diagnostic disable-next-line:inject-field
        __logger.config.use_console = false
        ---@diagnostic disable-next-line:inject-field
        __logger.config.info_level = override.info_level

        __logger.log_at_level(i, x, __logger.make_string, unpack(vals))

        ---@diagnostic disable-next-line:inject-field
        __logger.config.use_console = original_console
        ---@diagnostic disable-next-line:inject-field
        __logger.config.info_level = nil
    end
end

return M
