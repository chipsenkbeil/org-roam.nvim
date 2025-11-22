-------------------------------------------------------------------------------
-- DAILIES.LUA
--
-- Implementation of org-roam-dailies extension.
--
-- See https://www.orgroam.com/manual.html#org_002droam_002ddailies
-------------------------------------------------------------------------------

local io = require("org-roam.core.utils.io")
local notify = require("org-roam.core.ui.notify")
local random = require("org-roam.core.utils.random")

local Date = require("orgmode.objects.date")
local Calendar = require("orgmode.objects.calendar")
local Promise = require("orgmode.utils.promise")

---Returns the full path to the roam dailies directory.
---@param roam OrgRoam
---@return string
local function roam_dailies_dir(roam)
    return vim.fs.normalize(vim.fs.joinpath(roam.config.directory, roam.config.extensions.dailies.directory))
end

---Converts date to YYYY-MM-DD format.
---@param date OrgDate
---@return string
local function date_string(date)
    ---@diagnostic disable-next-line:return-type-mismatch
    return os.date("%Y-%m-%d", date.timestamp)
end

---Converts a date into a full file path.
---@param roam OrgRoam
---@param date OrgDate
---@return string
local function date_to_path(roam, date)
    -- Should produce YYYY-MM-DD.org
    local filename = date_string(date) .. ".org"
    return vim.fs.joinpath(roam_dailies_dir(roam), filename)
end

---Converts a path into a date.
---@param path string
---@return OrgDate|nil
local function path_to_date(path)
    local filename = vim.fn.fnamemodify(path, ":t:r")
    return Date.from_string(filename)
end

---Converts buffer's name into a date.
---@param buf integer
---@return OrgDate|nil
local function buf_to_date(buf)
    local bufname = vim.api.nvim_buf_get_name(buf)
    return path_to_date(bufname)
end

---Returns list of file paths representing org files within dailies
---that meet the date format of `YYYY-MM-DD`.
---@param roam OrgRoam
---@return string[]
local function roam_dailies_files(roam)
    return io.walk(roam_dailies_dir(roam))
        :filter(function(entry)
            ---@cast entry org-roam.core.utils.io.WalkEntry
            local filename = vim.fn.fnamemodify(entry.filename, ":t:r")
            local ext = vim.fn.fnamemodify(entry.filename, ":e")
            local is_org = ext == "org" or ext == "org_archive"
            local is_date = Date.is_valid_date_string(filename) ~= nil
            return entry.type == "file" and is_org and is_date
        end)
        :map(function(entry)
            ---@cast entry org-roam.core.utils.io.WalkEntry
            return entry.path
        end)
        :collect()
end

---Returns list of file paths representing org files within dailies
---that meet the date format of `YYYY-MM-DD`, sorted alphabetically.
---@param roam OrgRoam
---@return string[]
local function roam_dailies_files_sorted(roam)
    local files = roam_dailies_files(roam)
    table.sort(files)
    return files
end

---Returns list of pre-existing dates based on dailies filenames.
---@return OrgDate[]
local function roam_dailies_dates(roam)
    return vim.tbl_filter(
        function(d)
            ---@cast d OrgDate|nil
            return d ~= nil
        end,
        vim.tbl_map(function(path)
            local filename = vim.fn.fnamemodify(path, ":t:r")
            return Date.from_string(filename)
        end, roam_dailies_files(roam))
    )
end

---Creates a new buffer representing an org roam daily note.
---@param roam OrgRoam
---@param date OrgDate
---@param title? string
---@return integer buf
local function make_daily_buffer(roam, date, title)
    local buf = vim.api.nvim_create_buf(true, false)
    assert(buf ~= 0, "failed to create daily buffer")

    -- Update the filename of the buffer to be `path/to/{DATE}.org`
    vim.api.nvim_buf_set_name(buf, vim.fs.joinpath(roam_dailies_dir(roam), date_string(date) .. ".org"))

    -- Set filetype to org
    vim.api.nvim_buf_set_option(buf, "filetype", "org")

    -- Populate the buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, true, {
        ":PROPERTIES:",
        ":ID: " .. random.id(),
        ":END:",
        "#+TITLE: " .. (title or date_string(date)),
        "",
    })

    return buf
end

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
            content = string.gsub(content, vim.pesc(exp), os.date(exp:sub(3, -2), date and date.timestamp))
        end
        return content
    end

    for _, tmpl in pairs(templates) do
        ---@cast tmpl OrgCaptureTemplateOpts

        -- Update each target to be within the dailies directory
        -- and be populated with the specified date
        local target = tmpl.target
        if target then
            tmpl.target = vim.fs.joinpath(roam.config.extensions.dailies.directory, format_date(target))
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
---@return OrgCalendarOnRenderDay
local function make_render_on_day(roam)
    ---@param date OrgDate
    ---@return string
    local function key(date)
        return string.format("%s-%s-%s", date.year, date.month, date.day)
    end

    ---@type table<string, boolean>
    local dates = {}
    for _, date in ipairs(roam_dailies_dates(roam)) do
        dates[key(date)] = true
    end

    ---@param day OrgDate
    ---@param opts OrgCalendarOnRenderDayOpts
    return function(day, opts)
        if dates[key(day)] then
            vim.api.nvim_buf_add_highlight(
                opts.buf,
                opts.namespace,
                roam.config.extensions.dailies.ui.calendar.hl_date_exists,
                opts.line - 1,
                opts.from - 1,
                opts.to
            )
        end
    end
end

---@param roam OrgRoam
---@return org-roam.extensions.Dailies
return function(roam)
    ---@class org-roam.extensions.Dailies
    ---@field private __dates table<string, {date:OrgDate, file:string}>|nil
    local M = {}

    ---Opens the capture dialog for a specific date.
    ---If no `date` is specified, will open a calendar to select a date.
    ---@param opts? {date?:OrgDate|string, title?:string}
    ---@return OrgPromise<string|nil>
    function M.capture_date(opts)
        opts = opts or {}

        local date = opts.date
        if type(date) == "string" then
            date = Date.from_string(date)
            if not date then
                return Promise.reject("invalid date string")
            end
        end

        return (date and Promise.resolve(date) or Calendar.new({
            date = date,
            title = opts.title,
            on_day = make_render_on_day(roam),
        }):open()):next(function(date)
            if date then
                return roam.api.capture_node({
                    origin = false,
                    title = opts.title or date_string(date),
                    templates = make_dailies_templates(roam, date),
                })
            else
                return nil
            end
        end)
    end

    ---Opens the capture dialog for today's date.
    ---@return OrgPromise<string|nil>
    function M.capture_today()
        return M.capture_date({ date = Date.today() })
    end

    ---Opens the capture dialog for tomorrow's date.
    ---@return OrgPromise<string|nil>
    function M.capture_tomorrow()
        return M.capture_date({ date = Date.tomorrow() })
    end

    ---Opens the capture dialog for yesterday's date.
    ---@return OrgPromise<string|nil>
    function M.capture_yesterday()
        local yesterday = Date.today():subtract({ day = 1 })
        return M.capture_date({ date = yesterday })
    end

    ---Opens the roam dailies directory in the current window.
    function M.find_directory()
        vim.cmd.edit(roam_dailies_dir(roam))
    end

    ---Navigates to the note with the specified date.
    ---If no `date` is specified, opens up the calendar.
    ---@param opts? {date?:string|OrgDate, win?:integer}
    ---@return OrgPromise<OrgDate|nil>
    function M.goto_date(opts)
        opts = opts or {}
        local win = opts.win or vim.api.nvim_get_current_win()

        ---@type OrgPromise<OrgDate|nil>
        local date_promise

        local date = opts.date
        if type(date) == "string" then
            date = Date.from_string(date)
            if not date then
                return Promise.reject("invalid date string")
            end
        end

        if type(date) == "table" then
            date_promise = Promise.resolve(date)
        else
            date_promise = Calendar.new({ date = Date.today(), on_day = make_render_on_day(roam) }):open()
        end

        return date_promise:next(function(date)
            -- If the date is valid, then we want to either open
            -- the file or create a buffer with some basic contents
            -- WITHOUT saving it
            if date then
                local path = date_to_path(roam, date)
                return Promise.new(function(resolve)
                    io.stat(path)
                        :next(function(stat)
                            pcall(vim.api.nvim_set_current_win, win)
                            vim.cmd.edit(path)
                            resolve(date)
                            return stat
                        end)
                        :catch(function()
                            local buf = make_daily_buffer(roam, date)
                            pcall(vim.api.nvim_win_set_buf, win, buf)

                            -- NOTE: Must perform detection when buffer
                            --       is first created in order for folding
                            --       and other functionality to work!
                            vim.api.nvim_buf_call(buf, function()
                                vim.cmd("filetype detect")
                            end)

                            return resolve(date)
                        end)
                end)
            else
                return date
            end
        end)
    end

    ---Navigates to today's note.
    ---@return OrgPromise<OrgDate|nil>
    function M.goto_today()
        return M.goto_date({ date = Date.today() })
    end

    ---Navigates to tomorrow's note.
    ---@return OrgPromise<OrgDate|nil>
    function M.goto_tomorrow()
        return M.goto_date({ date = Date.tomorrow() })
    end

    ---Navigates to yesterday's note.
    ---@return OrgPromise<OrgDate|nil>
    function M.goto_yesterday()
        local yesterday = Date.today():subtract({ day = 1 })
        return M.goto_date({ date = yesterday })
    end

    ---Navigates to the next date based on the node under cursor.
    ---
    ---If `n` specified, will go `n` days in the future.
    ---If `n` is negative, find note `n` days in the past.
    ---
    ---If there is no existing note within range that exists,
    ---nil is returned from the promise, and nothing happens.
    ---@param opts? {n?:integer, suppress?:boolean, win?:integer}
    ---@return OrgPromise<OrgDate|nil>
    function M.goto_next_date(opts)
        opts = opts or {}
        local n = opts.n or 1

        local win = opts.win or vim.api.nvim_get_current_win()
        local date = buf_to_date(vim.api.nvim_win_get_buf(win))
        if not date then
            return Promise.resolve(nil)
        end

        -- Figure out our position among the files, adjust
        -- position using our offset, and resolve as a date
        local files = roam_dailies_files_sorted(roam)
        for i, file in ipairs(files) do
            local file_date = path_to_date(file)

            -- Use a diff check by day to ensure same date
            if file_date and date:diff(file_date) == 0 then
                -- Update our index to the new file
                local idx = i + n

                if idx < 1 then
                    if not opts.suppress then
                        notify.echo_info("Cannot go further back")
                    end
                    return Promise.resolve(nil)
                end

                if idx > #files then
                    if not opts.suppress then
                        notify.echo_info("Cannot go further forward")
                    end
                    return Promise.resolve(nil)
                end

                local target_date = path_to_date(files[idx])
                if not target_date then
                    return Promise.reject("invalid file: " .. vim.inspect(files[idx]))
                end
                return M.goto_date({ date = target_date, win = win })
            end
        end

        return Promise.resolve(nil)
    end

    ---Navigates to the previous date based on the node under cursor.
    ---
    ---If `n` specified, will go `n` days in the past.
    ---If `n` is negative, find note `n` days in the future.
    ---@param opts? {n?:integer, suppress?:boolean}
    ---@return OrgPromise<OrgDate|nil>
    function M.goto_prev_date(opts)
        opts = opts or {}
        local n = opts.n or 1
        return M.goto_next_date({
            n = -n,
            suppress = opts.suppress,
        })
    end

    return M
end
