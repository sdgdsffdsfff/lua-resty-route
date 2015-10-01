local setmetatable = setmetatable
local getmetatable = getmetatable
local select = select
local ipairs = ipairs
local pairs = pairs
local type = type
local unpack = table.unpack or unpack
local pack = table.pack
if not pack then
    pack = function(...)
        return { n = select("#", ...), ...}
    end
end
local function tofunction(f, m)
    local t = type(f)
    if t == "function" then
        return f
    elseif t == "table" then
        if m then
            return tofunction(t[m])
        else
            local mt = getmetatable(f) or {}
            if mt.__call then
                return f
            end
        end
    elseif t == "string" then
        return tofunction(require(f), m)
    end
    return nil
end
local function filter(route, location, pattern, self)
    if pattern then
        return (function(...)
            if select(1, ...) then
                return true, self(...)
            end
        end)(route:match(location, pattern))
    else
        return true, self(route:match(location, pattern))
    end
end
local function router(route, location, pattern, self)
    return (function(...)
        if select(1, ...) then
            return true, self(...)
        end
    end)(route:match(location, pattern))
end
local route = {}
route.__index = route
function route.new(opts)
    local m, t = "string", type(opts)
    if t == "table" then
        if opts.matcher then m = opts.matcher end
    end
    return setmetatable({
        matcher = require("resty.route.matchers." .. m),
        filters = {
            before = {},
            after  = {}
        },
        routes = {
            get     = {},
            head    = {},
            post    = {},
            put     = {},
            patch   = {},
            delete  = {},
            options = {},
            link    = {},
            unlink  = {},
            trace   = {}
        }
    }, route)
end
function route:match(location, pattern)
    return self.matcher(location, pattern)
end
function route:filter(pattern, phase)
    local c = self.filters[phase]
    local t = type(pattern)
    if t == "string" then
        return function(filters)
            if type(filters) == "table" then
                for _, func in ipairs(filters) do
                    local f = tofunction(func)
                    c[#c+1] = function(location)
                        return filter(self, location, pattern, f)
                    end
                end
            else
                local f = tofunction(filters)
                c[#c+1] = function(location)
                    return filter(self, location, pattern, f)
                end
            end
        end
    elseif t == "table" then
        for _, func in ipairs(pattern) do
            local f = tofunction(func)
            c[#c+1] = function(location)
                return filter(self, location, nil, f)
            end
        end
    else
        local f = tofunction(pattern)
        c[#c+1] = function(location)
            return filter(self, location, pattern, f)
        end
    end
    return self
end
function route:before(pattern)
    return self:filter(pattern, "before")
end
function route:after(pattern)
    return self:filter(pattern, "after")
end
function route:__call(pattern, method, func)
    local c = self.routes
    if func then
        local c = c[method]
        local f = tofunction(func)
        c[#c+1] = function(location)
            return router(self, location, pattern, f)
        end
        return self
    else
        return function(routes)
            if type(routes) == "table" then
                for method, func in pairs(routes) do
                    local c = c[method]
                    local f = tofunction(func)
                    c[#c+1] = function(location)
                        return router(self, location, pattern, f)
                    end
                end
            else
                local c = c[method]
                local f = tofunction(routes)
                c[#c+1] = function(location)
                    return router(self, location, pattern, f)
                end
            end
            return self
        end
    end
end
function route:get(pattern, func)
    return self(pattern, "get", func)
end
function route:head(pattern, func)
    return self(pattern, "head", func)
end
function route:post(pattern, func)
    return self(pattern, "post", func)
end
function route:put(pattern, func)
    return self(pattern, "put", func)
end
function route:patch(pattern, func)
    return self(pattern, "patch", func)
end
function route:delete(pattern, func)
    return self(pattern, "delete", func)
end
function route:options(pattern, func)
    return self(pattern, "options", func)
end
function route:link(pattern, func)
    return self(pattern, "link", func)
end
function route:unlink(pattern, func)
    return self(pattern, "unlink", func)
end
function route:trace(pattern, func)
    return self(pattern, "trace", func)
end
function route:ws()
end
function route:error()
end
function route:notfound()
end
function route:to(location, method)
    local results
    local before = self.filters.before
    for _, filter in ipairs(before) do
        filter(location)
    end
    local routes = self.routes[method]
    for _, route in ipairs(routes) do
        results = pack(route(location))
        if results.n > 0 then break end
    end
    local after = self.filters.after
    for _, filter in ipairs(after) do
        filter(location)
    end
    return unpack(results, 1, results.n)
end

return route