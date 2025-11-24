-------------------------------------------------------------------------------
-- SETUP.LUA
--
-- Contains logic to initialize the plugin.
-------------------------------------------------------------------------------

local AUGROUP = vim.api.nvim_create_augroup("org-roam.setup", {})

---@param roam OrgRoam
---@return org-roam.Setup
return function(roam)
    ---@class org-roam.Setup
    ---@operator call(org-roam.Config):OrgPromise<OrgRoam>
    local M = setmetatable({}, {
        __call = function(this, config)
            return this.call(config)
        end,
    })

    ---Calls the setup function to initialize the plugin.
    ---@param config org-roam.Config|nil
    ---@return OrgRoam
    function M.call(config)
        M.__merge_config(config or {})
        M.__define_autocmds()
        M.__define_commands()
        M.__define_keybindings()

        -- Create the directories if they are missing
        vim.fn.mkdir(roam.config.directory, "p")
        vim.fn.mkdir(vim.fs.joinpath(roam.config.directory, roam.config.extensions.dailies.directory), "p")

        -- Loading the orgmode plugin, which is requried for our modifications,
        -- is expensive; so, we instead will do this modification when the
        -- filetype is set to org for the very first time
        vim.api.nvim_create_autocmd({ "FileType" }, {
            group = AUGROUP,
            pattern = { "org" },
            once = true,
            callback = function()
                M.__modify_orgmode_plugin()
            end,
            desc = "Apply org-roam modifications to orgmode plugin",
        })

        -- Loading the database can take some time, even with our cache,
        -- because of orgmode itself also needing to load the files. We kick
        -- this off to run in the background to avoid a delayed startup time
        vim.schedule(function()
            M.__initialize_database()
        end)

        return roam
    end

    ---@private
    function M.__merge_config(config)
        if not M.__merge_config_done then
            M.__merge_config_done = true
            require("org-roam.setup.config")(roam, config)
        end
    end

    ---@private
    function M.__define_autocmds()
        if not M.__define_autocmds_done then
            M.__define_autocmds_done = true
            require("org-roam.setup.autocmds")(roam)
        end
    end

    ---@private
    function M.__define_commands()
        if not M.__define_commands_done then
            M.__define_commands_done = true
            require("org-roam.setup.commands")(roam)
        end
    end

    ---@private
    function M.__define_keybindings()
        if not M.__define_keybindings_done then
            M.__define_keybindings_done = true
            require("org-roam.setup.keybindings")(roam)
        end
    end

    ---@private
    function M.__modify_orgmode_plugin()
        if not M.__modify_orgmode_plugin_done then
            M.__modify_orgmode_plugin_done = true
            require("org-roam.setup.plugin")(roam)
        end
    end

    ---@private
    ---@return OrgPromise<nil>
    function M.__initialize_database()
        if not M.__initialize_database_done then
            M.__initialize_database_done = true
            return require("org-roam.setup.database")(roam):next(function()
                return nil
            end)
        else
            local Promise = require("orgmode.utils.promise")
            return Promise.resolve(nil)
        end
    end

    return M
end
