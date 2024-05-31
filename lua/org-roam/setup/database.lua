-------------------------------------------------------------------------------
-- DATABASE.LUA
--
-- Setup logic for roam database.
-------------------------------------------------------------------------------

local notify = require("org-roam.core.ui.notify")

---@param roam OrgRoam
---@return OrgPromise<{database:org-roam.core.Database, files:OrgFiles}>
return function(roam)
    local Promise = require("orgmode.utils.promise")

    -- Swap out the database for one configured properly
    roam.database = roam.database:new({
        db_path = roam.config.database.path,
        directory = roam.config.directory,
    })

    -- Load the database asynchronously, forcing a full sweep of directory
    return roam.database
        :load({ force = "scan" })
        :next(function()
            -- If we are persisting to disk, do so now as the database may
            -- have changed post-load
            if roam.config.database.persist then
                return roam.database:save()
            else
                return Promise.resolve(nil)
            end
        end)
        :catch(notify.error)
end
