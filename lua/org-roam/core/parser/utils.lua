local Link     = require("org-roam.core.parser.link")
local Property = require("org-roam.core.parser.property")
local Range    = require("org-roam.core.parser.range")
local Slice    = require("org-roam.core.parser.slice")

-------------------------------------------------------------------------------
-- UTILS.LUA
--
-- Utility functions to help streamline parsing orgmode contents.
-------------------------------------------------------------------------------

local M        = {}

---@param match table<integer, TSNode>
---@return org-roam.core.parser.Range
function M.get_pattern_range(match)
    ---@type org-roam.core.parser.Position
    local start = { row = 0, column = 0, offset = math.huge }
    ---@type org-roam.core.parser.Position
    local end_ = { row = 0, column = 0, offset = -1 }

    -- Find start and end of match
    for _, node in pairs(match) do
        local start_row, start_col, offset_start = node:start()
        local end_row, end_col, offset_end = node:end_()

        -- NOTE: End column & offset are exclusive, but we want inclusive, so adjust accordingly
        end_col = end_col - 1
        offset_end = offset_end - 1

        local cur_start_offset = start.offset
        local cur_end_offset = end_.offset

        start.offset = math.min(start.offset, offset_start)
        end_.offset = math.max(end_.offset, offset_end)

        -- Start changed, so adjust row/col
        if start.offset ~= cur_start_offset then
            start.row = start_row
            start.column = start_col
        end

        -- End changed, so adjust row/col
        if end_.offset ~= cur_end_offset then
            end_.row = end_row
            end_.column = end_col
        end
    end

    return Range:new(start, end_)
end

---@param contents string
---@return integer[]
local function scan_for_newlines(contents)
    local _newlines = {}
    local pos = 1
    while true do
        local i, j = string.find(contents, "\n", pos, true)
        if not i or not j then
            break
        end
        table.insert(_newlines, i - 1)
        pos = j + 1
    end
    return _newlines
end

---For a given range within a ref, figures out the column position (zero-based)
---of the starting line.
---@param range org-roam.core.parser.Range
---@param ref org-roam.core.parser.Ref<string>
---@return integer
local function determine_column_of_starting_line(range, ref)
    -- One-based index of a character, used to work backwards
    -- beginning with the character immediately before the
    -- start of the range
    local idx = range.start.offset
    while idx > 0 do
        local c = string.sub(ref.value, idx, idx)
        if c == "\n" then
            return range.start.offset - idx
        end
        idx = idx - 1
    end

    -- If we get to this point, everything proceeding the
    -- range is part of the same line, so we just return the
    -- offset as the column position (zero-based)
    return range.start.offset
end

---@param range org-roam.core.parser.Range
---@param ref org-roam.core.parser.Ref<string>
---@return org-roam.core.parser.Link[]
function M.scan_for_links(range, ref)
    local contents = string.sub(ref.value, range.start.offset + 1, range.end_.offset + 1)
    local starting_offset = range.start.offset
    local starting_line = range.start.row

    -- Because the contents can start not at the beginning of a line, we need to figure
    -- out the column position within the current line that the range represents
    local starting_column = determine_column_of_starting_line(range, ref)

    -- Because Lua does not support modifiers on group patterns, we have
    -- to perform multiple different pattern searches in parallel. Each
    -- will advance on its own throughout the range of the string.
    --
    -- In addition to that tracking, we need to recalculate the row and column
    -- position for each link discovered, which means keeping track of newline
    -- characters so we know where the start of a line is located.

    ---Zero-based positions of newline characters within contents.
    ---@type integer[]
    local newlines = scan_for_newlines(contents)

    ---Finds the line and offset from the start of that line, both zero-based.
    ---
    ---Must be called in order as it maintains state to know where the most
    ---recent line from the previous call would be.
    local function make_find_offset_from_line_fn()
        local next_line = 1

        ---Returns line (zero-based) and offset from line (zero-based).
        ---@param i integer
        ---@return integer,integer
        return function(i)
            -- Advance our offset until we start at the line containing offset
            while true do
                -- Get offset position of next line
                local line_offset = newlines[next_line]

                -- If we have gone past the last line available (nil)
                -- or we have advanced past our offset, stop the
                -- advancement without modification
                if not line_offset or line_offset > i then
                    break
                end

                -- Otherwise, advance to the next line and continue
                next_line = next_line + 1
            end

            return next_line - 1, (newlines[next_line - 1] or -1) + 1
        end
    end

    ---@return org-roam.core.parser.Link[]
    local function scan_for_regular_links_with_descriptions()
        local find_offset_from_line = make_find_offset_from_line_fn()

        ---List keeping track of start and end of a link, the kind of link, the path, and the description.
        ---@type {[1]:integer, [2]:integer, [3]:string, [4]:string}[]
        local raw_links = {}

        local pos = 1
        while true do
            local i, j, path, description = string.find(
                contents,
                "%[%[([^%c%z%]]*)%]%[([^%c%z%]]*)%]%]",
                pos
            )
            if not i or not j or not path or not description then
                break
            end

            -- Search continues immediately after the link
            pos = j + 1

            table.insert(raw_links, { i - 1, j - 1, path, description })
        end

        -- Build links that also calculates the row and column
        local links = {}
        for _, l in ipairs(raw_links) do
            local line, line_offset = find_offset_from_line(l[1])
            local column_offset = line == 0 and starting_column or 0
            local r = Range:new({
                row = line + starting_line,
                column = l[1] - line_offset + column_offset,
                offset = l[1] + starting_offset,
            }, {
                row = line + starting_line,
                column = l[2] - line_offset + column_offset,
                offset = l[2] + starting_offset,
            })
            table.insert(links, Link:new({
                kind = "regular",
                range = r,
                path = l[3],
                description = l[4],
            }))
        end
        return links
    end

    ---@return org-roam.core.parser.Link[]
    local function scan_for_regular_links_without_descriptions()
        local find_offset_from_line = make_find_offset_from_line_fn()

        ---List keeping track of start and end of a link and the path.
        ---@type {[1]:integer, [2]:integer, [3]:string}[]
        local raw_links = {}

        local pos = 1
        while true do
            local i, j, path = string.find(contents, "%[%[([^%c%z%]]*)%]%]", pos)
            if not i or not j or not path then
                break
            end

            -- Search continues immediately after the link
            pos = j + 1

            table.insert(raw_links, { i - 1, j - 1, path })
        end

        -- Build links that also calculates the row and column
        local links = {}
        for _, l in ipairs(raw_links) do
            local line, line_offset = find_offset_from_line(l[1])
            local column_offset = line == 0 and starting_column or 0
            local r = Range:new({
                row = line + starting_line,
                column = l[1] - line_offset + column_offset,
                offset = l[1] + starting_offset,
            }, {
                row = line + starting_line,
                column = l[2] - line_offset + column_offset,
                offset = l[2] + starting_offset,
            })
            table.insert(links, Link:new({
                kind = "regular",
                range = r,
                path = l[3],
            }))
        end
        return links
    end

    ---@type org-roam.core.parser.Link[]
    local links = {}
    vim.list_extend(links, scan_for_regular_links_with_descriptions())
    vim.list_extend(links, scan_for_regular_links_without_descriptions())

    -- Sort by range starting offset
    table.sort(links, function(a, b)
        return a.range.start.offset < b.range.start.offset
    end)

    return links
end

---@param properties org-roam.core.parser.Property[] #where to place new properties
---@param ref org-roam.core.parser.Ref<string> #reference to overall contents
---@param lines string[] #lines to parse
---@param start_row integer
---@param start_offset integer
function M.parse_lines_as_properties(properties, ref, lines, start_row, start_offset)
    local row = start_row
    local offset = start_offset

    for _, line in ipairs(lines) do
        local i, _, name, space, value = string.find(line, ":([^%c%z]+):(%s+)([^%c%z]+)$")
        if name and value then
            -- Record where the property starts (could have whitespace in front of it)
            local property_offset = offset + i - 1
            local property_column_offset = property_offset - offset
            local property_len = string.len(name) + string.len(space) + string.len(value) + 2

            -- We parsed a name and value, so now we need to build up the ranges for the
            -- entire property, which looks like this:
            --
            --     range
            -- |          |
            -- :NAME: VALUE
            --  |  |  |   |
            --  range range
            --
            --  To do this, we need to build up the position from an initial offset
            --  representing the beginning of the line, the length of the name, and
            --  the length of the value.
            local property_range = Range:new({
                row = row,
                column = property_column_offset,
                offset = property_offset,
            }, {
                row = row,
                -- NOTE: Subtracting 1 to remove newline from consideration and
                --       not stretch beyond the total text of the line itself.
                column = property_column_offset + property_len - 1,
                offset = property_offset + property_len - 1,
            })

            -- Name range is within the colons
            local name_range = Range:new({
                row = property_range.start.row,
                column = property_range.start.column + 1,
                offset = property_range.start.offset + 1,
            }, {
                row = property_range.end_.row,
                column = property_range.start.column + string.len(name),
                offset = property_range.start.offset + string.len(name),
            })

            local value_range = Range:new({
                row = property_range.start.row,
                column = (name_range.end_.column + 1) + string.len(space) + 1,
                offset = (name_range.end_.offset + 1) + string.len(space) + 1,
            }, {
                row = property_range.end_.row,
                column = (name_range.end_.column + 1) + string.len(space) + string.len(value),
                offset = (name_range.end_.offset + 1) + string.len(space) + string.len(value),
            })

            local property = Property:new({
                range = property_range,
                name = Slice:new(ref, name_range, { cache = name }),
                value = Slice:new(ref, value_range, { cache = value }),
            })
            table.insert(properties, property)
        end

        -- Next line means next row
        row = row + 1

        -- Advance the offset by the line (including the newline)
        offset = offset + string.len(line) + 1
    end
end

return M
