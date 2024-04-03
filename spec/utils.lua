local OrgFile = require("orgmode.files.file")
local OrgFiles = require("orgmode.files")
local io = require("org-roam.core.utils.io")
local path = require("org-roam.core.utils.path")
local unpack = require("org-roam.core.utils.table").unpack

local ORG_FILES_DIR = (function()
    local str = debug.getinfo(2, "S").source:sub(2)
    return path.join(vim.fs.dirname(str:match("(.*/)")), "files")
end)()

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

---@param ... OrgFile|OrgFile[]
---@return OrgFiles
function M.org_files(...)
    local root_dir = vim.fn.tempname()
    assert(vim.fn.mkdir(root_dir, "p") == 1, "failed to create org directory")

    -- Store org files into directory
    ---@type OrgFile[]
    local files = vim.tbl_flatten({ ... })
    for _, file in ipairs(files) do
        local handle = assert(
            io.open(file.filename, "w"),
            "failed to create " .. file.filename
        )
        assert(
            handle:write(file.content),
            "failed to write to " .. file.filename
        )
        handle:close()
    end

    return OrgFiles
        :new({ paths = path.join(root_dir, "**", "*.org") })
        :load()
        :wait()
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

---@param ... string
---@return string
function M.join_path(...)
    return path.join(...)
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

return M
