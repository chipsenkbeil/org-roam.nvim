-------------------------------------------------------------------------------
-- URI.LUA
--
-- Utilities for working with URIs.
-------------------------------------------------------------------------------

local DEFAULT_QUERY_DELIMITER = "&"

---@class org-roam.core.utils.uri.Authority
---@field userinfo? org-roam.core.utils.uri.UserInfo
---@field host string

---@class org-roam.core.utils.uri.UserInfo
---@field username string
---@field password? string

---@alias org-roam.core.utils.uri.Query { [string]: string }

---@alias org-roam.core.utils.uri.Fragment string

---@class org-roam.core.utils.Uri
---@field scheme string
---@field authority? org-roam.core.utils.uri.Authority
---@field path string
---@field query? org-roam.core.utils.uri.Query
---@field fragment? org-roam.core.utils.uri.Fragment
local M = {}
M.__index = M

---@class org-roam.core.utils.Uri.NewOpts
---@field scheme string
---@field authority? org-roam.core.utils.uri.Authority
---@field path string
---@field query? org-roam.core.utils.uri.Query
---@field fragment? org-roam.core.utils.uri.Fragment

---Creates a new URI from its components.
---@param opts org-roam.core.utils.Uri.NewOpts
---@return org-roam.core.utils.Uri
function M:new(opts)
    local instance = {}
    setmetatable(instance, M)
    instance.scheme = opts.scheme
    instance.authority = opts.authority
    instance.path = opts.path
    instance.query = opts.query
    instance.fragment = opts.fragment

    return instance
end

---Parses some `text` as a URI. If failing to parse, returns nil.
---@param text string
---@param opts? {query_delimiter?:string}
---@return org-roam.core.utils.Uri|nil
function M:parse(text, opts)
    opts = opts or {}

    local query_delimiter = opts.query_delimiter or DEFAULT_QUERY_DELIMITER

    -- A non-empty scheme component followed by a colon (:), consisting of a
    -- sequence of characters beginning with a letter and followed by any
    -- combination of letters, digits, plus (+), period (.), or hyphen (-).
    ---@type string|nil, string|nil
    local scheme, rest = string.match(text, "^(%a[%w%+%.%-]*):(.*)$")
    if not scheme or not rest then
        return
    end

    ---@type string|nil, string, string|nil, string|nil
    local authority_section, path, query, fragment

    -- Check if we have an authority and parse into raw text
    authority_section, path = string.match(rest, "^//([^/]*)(.*)$")
    if not authority_section then
        path = rest
    end

    -- Split path from query and fragment
    path, query = string.match(path, "^([^?#]*)(.*)$")
    if query and query ~= "" then
        query, fragment = query:match("^%??([^#]*)(.*)$")
    end

    -- Extract fragment, if present
    fragment = fragment and string.match(fragment, "^#(.*)$")

    -- Parse authority into username, password, and host, if authority is present
    local authority
    if authority_section and authority_section ~= "" then
        local username, password = string.match(authority_section, "^([^:@]+):?([^:@]*)@")
        local host = string.match(authority_section, "@?(.+)$")

        authority = { host = host }
        if username then
            authority.userinfo = {
                username = username,
                password = password and password ~= "" and password or nil,
            }
        end
    end

    -- Parse query into a table
    local query_table = nil
    if query and query ~= "" then
        query_table = {}

        local PATTERN = string.format(
            "([^%s=]+)=([^%s=]*)",
            query_delimiter,
            query_delimiter
        )
        for key, value in string.gmatch(query, PATTERN) do
            query_table[key] = value
        end
    end

    return M:new({
        scheme = scheme,
        authority = authority,
        path = path or "",
        query = query_table,
        fragment = fragment,
    })
end

return M
