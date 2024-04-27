-------------------------------------------------------------------------------
-- DAILIES.LUA
--
-- Implementation of org-roam-dailies extension.
--
-- See https://www.orgroam.com/manual.html#org_002droam_002ddailies
-------------------------------------------------------------------------------


local join_path = require("org-roam.core.utils.path").join
local walk = require("org-roam.core.utils.io").walk

---Creates a copy of the template options for dailies and pre-fills the
---target and content date expansions with the specified date, or current
---date if none is provided.
---@param roam OrgRoam
---@param date? OrgDate
---@return org-roam.config.extensions.dailies.Templates
local function make_dailies_templates(roam, date)
    ---@type org-roam.config.extensions.dailies.Templates
    local templates = vim.deepcopy(roam.config.extensions.dailies.templates)

    ---Formats all date strings within %<{FORMAT}> using the configured date.
    ---@param content string
    ---@return string
    local function format_date(content)
        for exp in string.gmatch(content, "%%<[^>]*>") do
            content = string.gsub(
                content,
                vim.pesc(exp),
                os.date(exp:sub(3, -2), date and date.timestamp)
            )
        end
        return content
    end

    for _, tmpl in pairs(templates) do
        ---@cast tmpl OrgCaptureTemplateOpts

        -- Update each target to be within the dailies directory
        -- and be populated with the specified date
        local target = tmpl.target
        if target then
            tmpl.target = join_path(
                roam.config.extensions.dailies.directory,
                format_date(target)
            )
        end

        local template = tmpl.template
        if type(template) == "string" then
            tmpl.template = format_date(template)
        elseif type(template) == "table" then
            tmpl.template = vim.tbl_map(format_date, template)
        end
    end

    return templates
end

---@param roam OrgRoam
---@return org-roam.extensions.Dailies
return function(roam)
    local Calendar = require("orgmode.objects.calendar")
    local Date = require("orgmode.objects.date")
    local Promise = require("orgmode.utils.promise")

    local ROAM_DAILIES_DIR = join_path(
        roam.config.directory,
        roam.config.extensions.dailies.directory
    )

    ---@class org-roam.extensions.Dailies
    ---@field private __dates table<string, {date:OrgDate, file:string}>|nil
    local M = {}

    ---Opens the capture dialog for a specific date.
    ---If no `date` is specified, will open a calendar to select a date.
    ---@param opts? {date?:OrgDate, title?:string}
    ---@param cb? fun(id:string|nil)
    function M.capture_date(opts, cb)
        opts = opts or {}
        local p = opts.date
            and Promise.resolve(opts.date)
            or Calendar.new({ date = opts.date, title = opts.title }):open()

        p:next(function(date)
            if date then
                roam.api.capture_node({
                    title = opts.title or date:to_date_string(),
                    templates = make_dailies_templates(roam, date),
                }, cb)
            end
        end)
    end

    ---Opens the capture dialog for today's date.
    ---@param cb? fun(id:string|nil)
    function M.capture_today(cb)
        M.capture_date({ date = Date.today() }, cb)
    end

    ---Opens the capture dialog for tomorrow's date.
    ---@param cb? fun(id:string|nil)
    function M.capture_tomorrow(cb)
        M.capture_date({ date = Date.tomorrow() }, cb)
    end

    ---Opens the capture dialog for yesterday's date.
    ---@param cb? fun(id:string|nil)
    function M.capture_yesterday(cb)
        local yesterday = Date.today():subtract({ day = 1 })
        M.capture_date({ date = yesterday }, cb)
    end

    ---Opens the roam dailies directory in the current window.
    function M.find_directory()
        vim.cmd.edit(ROAM_DAILIES_DIR)
    end

    ---Navigates to the note with the specified date.
    ---@param date string|OrgDate|nil
    ---@return OrgPromise<OrgDate>
    function M.goto_date(date)
        return nil
    end

    ---Navigates to today's note.
    ---@return OrgPromise<OrgDate>
    function M.goto_today()
        return M.goto_date(Date.today())
    end

    ---Navigates to tomorrow's note.
    ---@return OrgPromise<OrgDate>
    function M.goto_tomorrow()
        return M.goto_date(Date.tomorrow())
    end

    ---Navigates to yesterday's note.
    ---@return OrgPromise<OrgDate>
    function M.goto_yesterday()
        local yesterday = Date.today():subtract({ day = 1 })
        return M.goto_date(yesterday)
    end

    ---Navigates to the next date based on the node under cursor.
    ---
    ---If `n` specified, will go `n days in the future.
    ---If `n` is negative, find note `n` days in the past.
    ---@param n? integer
    ---@return OrgPromise<OrgDate>
    function M.goto_next_date(n)
        local date = Date.today():add({ day = n or 1 })
        return M.goto_date(date)
    end

    ---Navigates to the previous date based on the node under cursor.
    ---
    ---If `n` specified, will go `n days in the past.
    ---If `n` is negative, find note `n` days in the future.
    ---@param n? integer
    ---@return OrgPromise<OrgDate>
    function M.goto_prev_date(n)
        return M.goto_next_date(n and -n or -1)
    end

    ---@private
    ---Returns a table of dates and files where the keys are in the form
    ---`YYYY-MM-DD` and the values are a table containing the date and path.
    ---@param opts? {force?:boolean}
    ---@return table<string, {date:OrgDate, file:string}>
    function M.__list_dates(opts)
        opts = opts or {}

        -- If forcing or not yet cached, retrieve files
        if opts.force or not M.__dates then
            ---@type {date:OrgDate, file:string}[]
            local files = walk(ROAM_DAILIES_DIR)
                :filter(function(entry)
                    ---@cast entry org-roam.core.utils.io.WalkEntry
                    local ext = vim.fn.fnamemodify(entry.filename, ":e")
                    local is_org = ext == "org" or ext == "org_archive"
                    return entry.type == "file" and is_org
                end)
                :map(function(entry)
                    local filename = vim.fn.fnamemodify(entry.filename, ":t:r")

                    ---@type OrgDate|nil
                    local date = Date.from_string(filename)

                    return date and { date = date, file = entry.filename }
                end)
                :filter(function(x) return x ~= nil end)
                :collect()

            -- Build our mapping using date string as key
            local dates = {}
            for _, file in ipairs(files) do
                dates[file.date:to_date_string()] = file
            end

            M.__dates = dates
        end

        return M.__dates
    end

    return M
end
