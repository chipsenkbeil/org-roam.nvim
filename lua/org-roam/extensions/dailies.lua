-------------------------------------------------------------------------------
-- DAILIES.LUA
--
-- Implementation of org-roam-dailies extension.
--
-- See https://www.orgroam.com/manual.html#org_002droam_002ddailies
-------------------------------------------------------------------------------

---@param roam OrgRoam
---@return org-roam.extensions.Dailies
return function(roam)
    ---@class org-roam.extensions.Dailies
    local M = {}

    function M.capture_today()
    end

    function M.goto_today()
    end

    function M.capture_tomorrow()
    end

    function M.goto_tomorrow()
    end

    function M.capture_yesterday()
    end

    function M.goto_yesterday()
    end

    function M.capture_date()
    end

    function M.goto_date()
    end

    function M.goto_next_date()
    end

    function M.goto_prev_date()
    end

    function M.find_directory()
    end

    ---@private
    function M.__list_files()
    end

    ---@private
    function M.__is_daily_file()
    end

    return M
end
