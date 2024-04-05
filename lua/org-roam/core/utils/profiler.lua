-------------------------------------------------------------------------------
-- PROFILER.LUA
--
-- Implementation of basic profiling for functions.
-------------------------------------------------------------------------------

---@class org-roam.core.utils.Profiler
---@field private __label string
---@field private __records {[1]:integer, [2]:integer}[]
local M = {}
M.__index = M

---Creates a new profiler.
---@param opts? {label?:string}
---@return org-roam.core.utils.Profiler
function M:new(opts)
    opts = opts or {}
    local instance = {}
    setmetatable(instance, M)

    instance.__label = opts.label or debug.getinfo(2, "n").name
    instance.__records = {}

    return instance
end

---Starts a new recording, returning the id.
---@return integer
function M:start()
    local now = os.time()
    table.insert(self.__records, { now, 0 })
    local id = #self.__records
    return id
end

---Stops the specified recording, or if none specified the latest recording.
---If the recording has already been stopped, nothing is done.
---@param id? integer
---@return org-roam.core.utils.Profiler
function M:stop(id)
    local now = os.time()
    id = id or #self.__records
    if id > 0 then
        local recording = self.__records[id]
        if recording and recording[2] == 0 then
            recording[2] = now
        end
    end
    return self
end

---Returns the specified recording, or if none speified the latest recording
---If the recording id is invalid, returns nil.
---@param id? integer
---@return {[1]:integer, [2]:integer}|nil
function M:recording(id)
    id = id or #self.__records
    return vim.deepcopy(self.__records[id])
end

---Returns total recordings, including those in progress.
---If `completed_only` is true, will return count of only completed recordings.
---@param opts? {completed_only?:boolean}
---@return integer
function M:recording_cnt(opts)
    opts = opts or {}
    if opts.completed_only then
        return #vim.tbl_filter(function(recording)
            return recording[2] > 0
        end, self.__records)
    else
        return #self.__records
    end
end

---Prints information about time taken and when started/ended.
function M:print()
    print(self:print_as_string())
end

---Returns the message that would be printed with `self:print()` as a string.
---@param opts? {average?:boolean, recording?:integer}
---@return string
function M:print_as_string(opts)
    opts = opts or {}
    if opts.average then
        return string.format(
            "[%s] Took %s (average over %s recordings)",
            self.__label,
            self:time_taken_as_string({ average = true }),
            self:recording_cnt({ completed_only = true })
        )
    else
        local recording = self:recording(opts.recording)
        if recording then
            return string.format(
                "[%s] Took %s (started: %s, ended: %s)",
                self.__label,
                self:time_taken_as_string({ recording = opts.recording }),
                os.date("%T", recording[1]),
                os.date("%T", recording[2])
            )
        elseif self:recording_cnt() == 0 then
            return string.format(
                "[%s] No recording available",
                self.__label
            )
        else
            return string.format(
                "[%s] Invalid recording (%s)",
                self.__label,
                opts.recording
            )
        end
    end
end

---Returns time taken as hours, minutes, and seconds.
---
---If `average` is true, will provide this an an average of all recordings.
---
---If `recording` is specified, will provide the specific recording's time taken;
---otherwise will use the latest recording.
---@param opts? {average?:boolean, recording?:integer}
---@return {hours:integer, minutes:integer, seconds:integer}
function M:time_taken(opts)
    opts = opts or {}

    ---@integer
    local total_in_secs = 0
    if opts.average then
        local cnt = 0

        -- Build up a sum of completed recordings
        for _, recording in ipairs(self.__records) do
            if recording[2] > 0 then
                total_in_secs = total_in_secs + (recording[2] - recording[1])
                cnt = cnt + 1
            end
        end

        -- Take the average
        if cnt > 0 then total_in_secs = math.floor(total_in_secs / cnt) end
    else
        assert(self:recording_cnt() > 0, "no recording available")
        local recording = assert(self:recording(opts.recording), "invalid recording")
        total_in_secs = recording[2] - recording[1]
    end

    assert(total_in_secs >= 0, "Profiler end is earlier than start")

    local secs = math.fmod(total_in_secs, 60)

    local total_in_mins = (total_in_secs - secs) / 60
    local mins = math.fmod(total_in_mins, 60)

    local total_in_hours = (total_in_mins - mins) / 24

    return { hours = total_in_hours, minutes = mins, seconds = secs }
end

---Same as `self:time_taken()`, but as a string.
---@param opts? {average?:boolean, recording?:integer}
---@return string
function M:time_taken_as_string(opts)
    local taken = self:time_taken(opts)
    if taken.hours > 0 then
        return string.format("%dh%dm%ds", taken.hours, taken.minutes, taken.seconds)
    elseif taken.minutes > 0 then
        return string.format("%dm%ds", taken.minutes, taken.seconds)
    else
        return string.format("%ds", taken.seconds)
    end
end

return M
