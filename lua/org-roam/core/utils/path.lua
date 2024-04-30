-------------------------------------------------------------------------------
-- PATH.LUA
--
-- Contains utility functions to assist path building.
-------------------------------------------------------------------------------

local M = {}

local uv = vim.uv or vim.loop

local ISWIN = uv.os_uname().sysname == "Windows_NT"
local SEP = ISWIN and "\\" or "/"

---Returns the path separator.
---@return string
function M.separator()
    return SEP
end

---Joins one or more paths together as one.
---If any path is absolute, it will replace the currently-constructed path.
---@param ...string
---@return string path
function M.join(...)
    local path = ""

    -- NOTE: We grab the separator using a function so we can
    --       overwrite it in tests to verify what we expect.
    local sep = M.separator()
    local iswin = sep == "\\"

    --- From plenary.nvim, determines if the path is absolute.
    ---@param filename string
    ---@return boolean
    local is_absolute = function(filename)
        if iswin then
            return string.match(filename, "^[%a]:[\\/].*$") ~= nil
        end
        return string.sub(filename, 1, 1) == sep
    end

    for _, p in ipairs({ ... }) do
        -- Convert \ into /
        p = M.normalize(p)

        if path == "" or is_absolute(p) then
            path = p
        else
            path = path .. sep .. p
        end
    end

    return M.normalize(path)
end

---Helper function taken from neovim 0.10 nightly.
---@param path string Path to split.
---@return string, string, boolean : prefix, body, whether path is invalid.
local function split_windows_path(path)
    local prefix = ""

    --- Match pattern. If there is a match, move the matched pattern from the path to the prefix.
    --- Returns the matched pattern.
    ---
    --- @param pattern string Pattern to match.
    --- @return string|nil Matched pattern
    local function match_to_prefix(pattern)
        local match = path:match(pattern)

        if match then
            prefix = prefix .. match --[[ @as string ]]
            path = path:sub(#match + 1)
        end

        return match
    end

    local function process_unc_path()
        return match_to_prefix("[^/]+/+[^/]+/+")
    end

    if match_to_prefix("^//[?.]/") then
        -- Device paths
        local device = match_to_prefix("[^/]+/+")

        -- Return early if device pattern doesn"t match, or if device is UNC and it"s not a valid path
        if not device or (device:match("^UNC/+$") and not process_unc_path()) then
            return prefix, path, false
        end
    elseif match_to_prefix("^//") then
        -- Process UNC path, return early if it"s invalid
        if not process_unc_path() then
            return prefix, path, false
        end
    elseif path:match("^%w:") then
        -- Drive paths
        prefix, path = path:sub(1, 2), path:sub(3)
    end

    -- If there are slashes at the end of the prefix, move them to the start of the body. This is to
    -- ensure that the body is treated as an absolute path. For paths like C:foo/bar, there are no
    -- slashes at the end of the prefix, so it will be treated as a relative path, as it should be.
    local trailing_slash = prefix:match("/+$")

    if trailing_slash then
        prefix = prefix:sub(1, -1 - #trailing_slash)
        path = trailing_slash .. path --[[ @as string ]]
    end

    return prefix, path, true
end

---Helper function taken from neovim 0.10 nightly.
---@param path string Path to resolve.
---@return string Resolved path.
local function path_resolve_dot(path)
    local is_path_absolute = vim.startswith(path, "/")
    -- Split the path into components and process them
    local path_components = vim.split(path, "/")
    local new_path_components = {}

    for _, component in ipairs(path_components) do
        if component == "." or component == "" then -- luacheck: ignore 542
            -- Skip `.` components and empty components
        elseif component == ".." then
            if #new_path_components > 0 and new_path_components[#new_path_components] ~= ".." then
                -- For `..`, remove the last component if we"re still inside the current directory, except
                -- when the last component is `..` itself
                table.remove(new_path_components)
            elseif is_path_absolute then -- luacheck: ignore 542
                -- Reached the root directory in absolute path, do nothing
            else
                -- Reached current directory in relative path, add `..` to the path
                table.insert(new_path_components, component)
            end
        else
            table.insert(new_path_components, component)
        end
    end

    return (is_path_absolute and "/" or "") .. table.concat(new_path_components, "/")
end

---Noramlizes a path. Taken from neovim 0.10 nightly.
---
---@param path (string) Path to normalize
---@param opts? {expand_env?:boolean, win?:boolean}
---@return (string) : Normalized path
function M.normalize(path, opts)
    opts = opts or {}

    vim.validate({
        path = { path, { "string" } },
        expand_env = { opts.expand_env, { "boolean" }, true },
        win = { opts.win, { "boolean" }, true },
    })

    local win = opts.win == nil and ISWIN or not not opts.win
    local os_sep_local = win and "\\" or "/"

    -- Empty path is already normalized
    if path == "" then
        return ""
    end

    -- Expand ~ to users home directory
    if vim.startswith(path, "~") then
        local home = uv.os_homedir() or "~"
        if home:sub(-1) == os_sep_local then
            home = home:sub(1, -2)
        end
        path = home .. path:sub(2)
    end

    -- Expand environment variables if `opts.expand_env` isn"t `false`
    if opts.expand_env == nil or opts.expand_env then
        path = path:gsub("%$([%w_]+)", uv.os_getenv)
    end

    -- Convert path separator to `/`
    path = path:gsub(os_sep_local, "/")

    -- Check for double slashes at the start of the path because they have special meaning
    local double_slash = vim.startswith(path, "//") and not vim.startswith(path, "///")
    local prefix = ""

    if win then
        local is_valid --- @type boolean
        -- Split Windows paths into prefix and body to make processing easier
        prefix, path, is_valid = split_windows_path(path)

        -- If path is not valid, return it as-is
        if not is_valid then
            return prefix .. path
        end

        -- Remove extraneous slashes from the prefix
        prefix = prefix:gsub("/+", "/")
    end

    -- Resolve `.` and `..` components and remove extraneous slashes from path, then recombine prefix
    -- and path. Preserve leading double slashes as they indicate UNC paths and DOS device paths in
    -- Windows and have implementation-defined behavior in POSIX.
    path = (double_slash and "/" or "") .. prefix .. path_resolve_dot(path)

    -- Change empty path to `.`
    if path == "" then
        path = "."
    end

    return path
end

return M
