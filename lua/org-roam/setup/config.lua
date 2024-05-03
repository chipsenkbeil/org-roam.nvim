-------------------------------------------------------------------------------
-- CONFIG.LUA
--
-- Setup logic for roam config.
-------------------------------------------------------------------------------

---@param roam OrgRoam
---@param config org-roam.Config
return function(roam, config)
    assert(config.directory, "missing org-roam directory")

    -- Normalize the roam directory before storing it
    ---@diagnostic disable-next-line:inject-field
    config.directory = vim.fs.normalize(config.directory)

    -- Merge our configuration options into our global config
    roam.config:replace(config)
end
