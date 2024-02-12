-------------------------------------------------------------------------------
-- URI.LUA
--
-- Utilities for working with URIs.
-------------------------------------------------------------------------------

local DEFAULT_QUERY_DELIMITER = "&"

---@class org-roam.core.utils.uri.Authority
---@field userinfo? org-roam.core.utils.uri.UserInfo
---@field host string
---@field port? integer

---@class org-roam.core.utils.uri.UserInfo
---@field username string
---@field password? string

---@alias org-roam.core.utils.uri.Query string
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
---@return org-roam.core.utils.Uri|nil
function M:parse(text, opts)
    opts = opts or {}

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
    ---@type string|nil, string
    authority_section, path = string.match(rest, "^//([^/]*)(.*)$")
    if not authority_section then
        path = rest
    end

    -- Split path from query and fragment
    ---@type string, string
    path, query = string.match(path, "^([^?#]*)(.*)$")
    if query and query ~= "" then
        query, fragment = query:match("^%??([^#]*)(.*)$")
    end

    -- Extract fragment, if present
    fragment = fragment and string.match(fragment, "^#(.*)$")

    -- Parse authority into username, password, and host, if authority is present
    local authority
    if authority_section and authority_section ~= "" then
        ---@type string|nil, string|nil
        local userinfo, hostport = string.match(authority_section, "^([^@]*)@(.*)$")
        if not userinfo then
            hostport = authority_section
        end

        ---@type string|nil, string|nil
        local username, password
        if userinfo then
            username, password = string.match(userinfo, "^([^:@]+):?([^:@]*)$")
        end

        ---@type string|nil, string|nil
        local host, port
        if hostport then
            if string.sub(hostport, 1, 1) == "[" then
                -- IPv6 address, possibly with port
                ---@type string|nil, string|nil
                host, port = hostport:match("^(%[[^%]]+%]):?(%d*)$")
            else
                -- Regular hostname or IPv4, with optional port
                ---@type string|nil, string|nil
                host, port = hostport:match("^([^:]+):?(%d*)$")
            end
        end

        if port then
            ---@diagnostic disable-next-line:cast-local-type
            port = tonumber(port)
        end

        authority = { host = host, port = port }
        if username then
            authority.userinfo = {
                username = username,
                password = password and password ~= "" and password or nil,
            }
        end
    end

    return M:new({
        scheme = scheme,
        authority = authority,
        path = path or "",
        query = query and query ~= "" and query or nil,
        fragment = fragment,
    })
end

---Returns a table of query parameters by parsing the query into standardized parameters.
---@param opts? {delimiter?:string}
---@return {[string]: string}
function M:query_params(opts)
    opts = opts or {}
    local delimiter = opts.delimiter or DEFAULT_QUERY_DELIMITER

    -- Parse query into a table
    local query_table = nil
    if self.query and self.query ~= "" then
        query_table = {}

        local PATTERN = string.format(
            "([^%s=]+)=([^%s=]*)",
            delimiter,
            delimiter
        )
        for key, value in string.gmatch(self.query, PATTERN) do
            query_table[key] = value
        end
    end

    return query_table
end

return M
