-------------------------------------------------------------------------------
-- MOUSE.LUA
--
-- Contains functionality tied to mouse usage.
-------------------------------------------------------------------------------

---@class org-roam.MouseApi
local M = {}

local NAMESPACE = vim.api.nvim_create_namespace("org-roam.nvim.mouse")
local link_extmark_buf = nil
local link_extmark_id = nil

local function clear_link_hl()
    if link_extmark_id and link_extmark_buf then
        vim.api.nvim_buf_del_extmark(
            link_extmark_buf,
            NAMESPACE,
            link_extmark_id
        )
        link_extmark_buf = nil
        link_extmark_id = nil
    end
end

---@param win integer #window whose line to examine
---@param linenum integer #one-based line number within window
local function is_line_concealed(win, linenum)
    local mode = vim.api.nvim_get_mode().mode
    local level = vim.opt.conceallevel:get()

    -- Level 0 means to show always
    if level == 0 then return false end

    -- Check if our cursor is not on the line we're checking,
    -- and if not then it should be concealed
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
    if cursor_line ~= linenum then return true end

    -- Otherwise, concealcursor most contain our current mode
    -- for the line to be concealed
    local ccursor = vim.opt.concealcursor:get()
    local mode_concealed = string.find(ccursor, mode) ~= nil
    return mode_concealed
end

---@param opts {concealed:boolean, path:string, desc:string|nil}
---@return string
local function get_visual_link_text(opts)
    local level = vim.opt.conceallevel:get()

    -- If not concealed, reconstruct regular link to show
    --
    -- NOTE: We also aren't going to support level 1 since it
    --       replaces conceal with another character; hopefully,
    --       this ends up being the same length as the normal link.
    if not opts.concealed or level < 2 then
        local text = "[[" .. opts.path
        if opts.desc then
            text = text .. "][" .. opts.desc .. "]]"
        else
            text = text .. "]]"
        end

        return text
    end

    -- Otherwise, assume that regular concealment happens and only
    -- show the part that would be displayed by orgmode
    return opts.desc or opts.path
end

---Finds the position of the link on the line at `pos`.
---@param line string
---@param column integer #one-based column position
---@para opts {concealed:boolean}
---@return {from:integer, to:integer}|nil #one-based start/end columns
local function find_link_on_line(line, column, opts)
    local LINK_PATTERN = "%[%[([^%]]+.-)%]%]"

    ---@type {from:integer, to:integer, shift:integer, shrink:integer}[]
    local positions = {}

    ---@type {from:integer, to:integer}|nil
    local found_pos = nil

    for link in line:gmatch(LINK_PATTERN) do
        local last_pos = positions[#positions]
        ---@type integer|nil
        local start_from = last_pos and last_pos.to or nil
        local from, to = string.find(line, LINK_PATTERN, start_from)

        -- Figure out the path and description, which will be
        -- in the form from our pattern match of path][desc if
        -- there is a description.
        local i, j = string.find(link, "][", 1, true)
        local path, desc = link, nil
        if i and j then
            path = string.sub(link, 1, i - 1)
            desc = string.sub(link, j + 1)
        end

        -- Get the visual representation of our link, which
        -- we use to figure out a difference in positioning
        -- of the line itself
        local visual_link = get_visual_link_text({
            concealed = opts.concealed,
            path = path,
            desc = desc,
        })

        -- Full, non-concealed link includes "[[" and "]]"
        local full_link_len = string.len(link) + 4

        -- Calculate our raw link position, an offset (going left)
        -- to indicate the visual start of the link on the line,
        -- and a shrink indicator on how much smaller the link
        -- visually appears
        --
        -- <<EXAMPLE>>
        --
        -- This [[link][a]] is [[here-and][maybe]] and [[there][b]]
        -- This a is maybe and b
        --
        -- link (start = 6, visual = 6)
        -- * shift = 0
        -- * shrink = 10
        --
        -- here-and (start = 21, visual = 11)
        -- * shift = 10
        -- * shrink = 14
        --
        -- there (start = 45, visual = 21)
        -- * shift = 24
        -- * shrink = 11
        local shrink = full_link_len - string.len(visual_link)
        local pos = {
            from = from,
            to = to,
            shift = last_pos and (last_pos.shift + last_pos.shrink) or 0,
            shrink = shrink,
        }

        -- Calculate our visual link position
        local visual_pos = {
            from = pos.from - pos.shift,
            to = pos.to - pos.shift - shrink,
        }

        -- Check if our column is within the link visually
        if column >= visual_pos.from and column <= visual_pos.to then
            -- Return the position of the raw link (non-visual)
            found_pos = { from = pos.from, to = pos.to }
            break
        end
        table.insert(positions, pos)
    end

    return found_pos
end

---Highlights the link under the mouse cursor.
---If any other link was highlighted by this function, it is cleared.
---@param hl_group string
function M.highlight_link(hl_group)
    local pos = vim.fn.getmousepos()
    local win = pos.winid

    -- One-based row,col position
    local row = pos.line
    local col = pos.column

    -- When not over a window, we do nothing
    if win == 0 or row == 0 or col == 0 then
        clear_link_hl()
        return
    end

    -- If mouse somehow not in buffer range, we do nothing
    local buf = vim.api.nvim_win_get_buf(win)
    local line_cnt = vim.api.nvim_buf_line_count(buf)
    if row > line_cnt then
        clear_link_hl()
        return
    end

    -- Get the line our mouse is over
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, true)[1]
    local found_pos = find_link_on_line(line, col, {
        concealed = is_line_concealed(win, row)
    })

    -- Get the link at the position, doing nothing if not a link
    if not found_pos then
        clear_link_hl()
        return
    end

    -- Finally, apply a highlight over the link
    local id = vim.api.nvim_buf_set_extmark(
        buf, NAMESPACE, row - 1, found_pos.from - 1,
        {
            id = link_extmark_id,
            end_row = row - 1,
            end_col = found_pos.to - 1,
            hl_group = hl_group,
        }
    )

    link_extmark_buf = buf
    link_extmark_id = id
end

return M
