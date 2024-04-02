local join_path = require("org-roam.core.utils.path").join
local OrgFile = require("orgmode.files.file")
local OrgFiles = require("orgmode.files")
local unpack = require("org-roam.core.utils.table").unpack

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
        :new({ paths = join_path(root_dir, "**", "*.org") })
        :load()
        :wait()
end

return M
