local cwd = vim.fn.getcwd()

-- NOTE: Hack because cwd seems to be within the lua
--       directory, and this results in us cloning
--       the repositories into the lua directory
--       instead of the vendor directory.
if vim.endswith(cwd, "lua") or vim.endswith(cwd, "lua/") or vim.endswith(cwd, "lua\\") then
    cwd = vim.fs.dirname(cwd)
end

---@class Plugin
---@field name string
---@field path string
---@field repo string
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
        config = function()
            -- Setup orgmode
            print("Running orgmode setup")
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
        print("Downloading " .. plugin.name .. " into: " .. plugin.path)
        vim.fn.system {
            "git",
            "clone",
            "--depth=1",
            plugin.repo,
            plugin.path,
        }
    end

    -- Add plugin to our runtime path
    print("Adding plugin to runtime path: " .. plugin.path)
    vim.opt.rtp:prepend(plugin.path)

    -- If we have a config function, execute it
    if type(plugin.config) == "function" then
        print("Configuring " .. plugin.name)
        local ok, msg = pcall(plugin.config)
        if not ok then
            error("Failed to configure plugin " .. plugin.name .. ": " .. vim.inspect(msg))
        end
    end
end

-- Configure ourself as a plugin on the runtime path
vim.opt.rtp:prepend(cwd)
