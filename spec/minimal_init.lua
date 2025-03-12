local cwd = vim.fn.getcwd()

-- NOTE: Hack because cwd seems to be within the lua
--       directory, and this results in us cloning
--       the repositories into the lua directory
--       instead of the vendor directory.
if vim.endswith(cwd, "lua") or vim.endswith(cwd, "lua/") or vim.endswith(cwd, "lua\\") then
    cwd = vim.fs.dirname(cwd)
end

---@param name string
---@return string|nil
local function getenv(name)
    local value = vim.fn.getenv(name)
    if value ~= vim.NIL then
        return value
    end
end

local report_enabled = getenv("ROAM_TEST_REPORT") or false
if not report_enabled or vim.trim(report_enabled):lower() == "false" then
    report_enabled = false
end
local function report(...)
    if report_enabled then
        print(...)
    end
end

---@class Plugin
---@field name string
---@field path string
---@field repo string
---@field branch? string|vim.NIL
---@field config? fun()

-- List of plugins to process. Order matters!
---@type Plugin[]
local plugins = {
    -- Used for testing
    {
        name = "plenary",
        path = cwd .. "/vendor/plenary.nvim",
        repo = "https://github.com/nvim-lua/plenary.nvim",
    },

    -- Primary plugin we work with
    {
        name = "orgmode",
        path = cwd .. "/vendor/orgmode.nvim",
        repo = "https://github.com/nvim-orgmode/orgmode",
        branch = getenv("ROAM_TEST_ORGMODE_BRANCH"),
        config = function()
            -- Setup orgmode
            report("Running orgmode setup")
            require("orgmode").setup({
                org_agenda_files = "~/orgfiles/**/*",
                org_default_notes_file = "~/orgfiles/refile.org",
            })
        end,
    },
}

-- Load all of our plugins
for _, plugin in ipairs(plugins) do
    -- If plugin not yet downloaded, do that now
    if vim.fn.isdirectory(plugin.path) == 0 then
        report("Downloading "
            .. plugin.name
            .. (plugin.branch and (" @ " .. plugin.branch) or "")
            .. " into: " .. plugin.path)
        local cmd = { "git", "clone", "--depth=1" }

        -- If given a specific branch, clone that
        if plugin.branch then
            table.insert(cmd, "--branch")
            table.insert(cmd, plugin.branch)
            table.insert(cmd, "--single-branch")
        end

        table.insert(cmd, plugin.repo)
        table.insert(cmd, plugin.path)

        vim.fn.system(cmd)
    end

    -- Add plugin to our runtime path
    report("Adding plugin to runtime path: " .. plugin.path)
    vim.opt.rtp:prepend(plugin.path)

    -- If we have a config function, execute it
    if type(plugin.config) == "function" then
        report("Configuring " .. plugin.name)
        local ok, msg = pcall(plugin.config)
        if not ok then
            error("Failed to configure plugin " .. plugin.name .. ": " .. vim.inspect(msg))
        end
    end
end

-- Configure ourself as a plugin on the runtime path
vim.opt.rtp:prepend(cwd)
