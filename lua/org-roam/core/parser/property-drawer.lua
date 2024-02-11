-------------------------------------------------------------------------------
-- PROPERTY-DRAWER.LUA
--
-- Abstraction for an org property drawer.
-------------------------------------------------------------------------------

---@class org-roam.core.parser.PropertyDrawer
---@field range org-roam.core.parser.Range
---@field properties org-roam.core.parser.Property[]
local M = {}
M.__index = M

---@class org-roam.core.parser.PropertyDrawer.NewOpts
---@field range org-roam.core.parser.Range
---@field properties org-roam.core.parser.Property[]

---Creates a new property drawer.
---@param opts org-roam.core.parser.PropertyDrawer.NewOpts
---@return org-roam.core.parser.PropertyDrawer
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)

    instance.range = opts.range
    instance.properties = opts.properties

    return instance
end

---Finds the property with the specified name, returning its value.
---@param name string
---@param opts? {case_insensitive?:boolean}
---@return string|nil
function M:find(name, opts)
    opts = opts or {}

    if opts.case_insensitive then
        name = string.lower(name)
    end

    for _, property in ipairs(self.properties) do
        local prop_name = vim.trim(property.name:text())
        if opts.case_insensitive then
            prop_name = string.lower(prop_name)
        end

        if name == prop_name then
            return vim.trim(property.value:text())
        end
    end
end

return M
