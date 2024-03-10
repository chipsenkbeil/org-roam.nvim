-------------------------------------------------------------------------------
-- CONFIG.LUA
--
-- Contains global config logic used by the plugin.
-------------------------------------------------------------------------------

local Config = require("org-roam.core.config")
local INSTANCE = Config:new({ org_roam_directory = "" })

return INSTANCE
