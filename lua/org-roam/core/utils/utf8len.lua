-------------------------------------------------------------------------------
-- UTF8.LUA
--
-- Provides UTF-8 aware string length function implemented in pure lua.
-- Taken from https://github.com/Stepets/utf8.lua.
-------------------------------------------------------------------------------

--[[
Copyright (c) 2006-2007, Kyle Smith
All rights reserved.

Contributors:
Alimov Stepan

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
* Neither the name of the author nor the names of its contributors may be
used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]

local byte = string.byte
local len = string.len

---Returns the number of bytes used by the UTF-8 character at byte i in s
---also doubles as a UTF-8 character validator.
---@param s string
---@param i integer|nil
---@return integer
local function utf8charbytes(s, i)
    -- argument defaults
    i = i or 1

    -- argument checking
    if type(s) ~= "string" then
        error("bad argument #1 to 'utf8charbytes' (string expected, got " .. type(s) .. ")")
    end
    if type(i) ~= "number" then
        error("bad argument #2 to 'utf8charbytes' (number expected, got " .. type(i) .. ")")
    end

    local c = byte(s, i)

    -- determine bytes needed for character, based on RFC 3629
    -- validate byte 1
    if c > 0 and c <= 127 then
        -- UTF8-1
        return 1
    elseif c >= 194 and c <= 223 then
        -- UTF8-2
        local c2 = byte(s, i + 1)

        if not c2 then
            error("UTF-8 string terminated early")
        end

        -- validate byte 2
        if c2 < 128 or c2 > 191 then
            error("Invalid UTF-8 character")
        end

        return 2
    elseif c >= 224 and c <= 239 then
        -- UTF8-3
        local c2 = byte(s, i + 1)
        local c3 = byte(s, i + 2)

        if not c2 or not c3 then
            error("UTF-8 string terminated early")
        end

        -- validate byte 2
        if c == 224 and (c2 < 160 or c2 > 191) then
            error("Invalid UTF-8 character")
        elseif c == 237 and (c2 < 128 or c2 > 159) then
            error("Invalid UTF-8 character")
        elseif c2 < 128 or c2 > 191 then
            error("Invalid UTF-8 character")
        end

        -- validate byte 3
        if c3 < 128 or c3 > 191 then
            error("Invalid UTF-8 character")
        end

        return 3
    elseif c >= 240 and c <= 244 then
        -- UTF8-4
        local c2 = byte(s, i + 1)
        local c3 = byte(s, i + 2)
        local c4 = byte(s, i + 3)

        if not c2 or not c3 or not c4 then
            error("UTF-8 string terminated early")
        end

        -- validate byte 2
        if c == 240 and (c2 < 144 or c2 > 191) then
            error("Invalid UTF-8 character")
        elseif c == 244 and (c2 < 128 or c2 > 143) then
            error("Invalid UTF-8 character")
        elseif c2 < 128 or c2 > 191 then
            error("Invalid UTF-8 character")
        end

        -- validate byte 3
        if c3 < 128 or c3 > 191 then
            error("Invalid UTF-8 character")
        end

        -- validate byte 4
        if c4 < 128 or c4 > 191 then
            error("Invalid UTF-8 character")
        end

        return 4
    else
        error("Invalid UTF-8 character")
    end
end

---Returns the number of characters in a UTF-8 string.
---@param s string
---@return integer
return function(s)
    -- argument checking
    if type(s) ~= "string" then
        for k, v in pairs(s) do
            print('"', tostring(k), '"', tostring(v), '"')
        end
        error("bad argument #1 to 'utf8len' (string expected, got " .. type(s) .. ")")
    end

    local pos = 1
    local bytes = len(s)
    local length = 0

    while pos <= bytes do
        length = length + 1
        pos = pos + utf8charbytes(s, pos)
    end

    return length
end
