local scenario = arg[1]
local root = os.getenv("BS_ROOT")
local via = os.getenv("BS_LOAD") or "module"

local events = { exec = {}, notifications = {}, binds = {}, press_errors = {} }

local function encode(value)
    local kind = type(value)
    if kind == "nil" then
        return "null"
    elseif kind == "boolean" or kind == "number" then
        return tostring(value)
    elseif kind == "string" then
        return string.format("%q", value):gsub("\\\n", "\\n"):gsub("\\(%d%d?%d?)", function(code)
            return string.format("\\u%04x", tonumber(code))
        end)
    elseif kind == "table" then
        if #value > 0 or next(value) == nil then
            local parts = {}
            for i = 1, #value do
                parts[i] = encode(value[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for key in pairs(value) do
            keys[#keys + 1] = tostring(key)
        end
        table.sort(keys)
        local parts = {}
        for _, key in ipairs(keys) do
            parts[#parts + 1] = encode(key) .. ":" .. encode(value[key])
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return encode(tostring(value))
end

hl = {
    exec_cmd = function(command)
        events.exec[#events.exec + 1] = command
    end,
    notification = {
        create = function(spec)
            events.notifications[#events.notifications + 1] = spec.text
        end,
    },
    bind = function(keys, dispatcher, opts)
        events.binds[#events.binds + 1] = { keys = keys, kind = type(dispatcher), opts = opts, fn = dispatcher }
        return { keys = keys }
    end,
}

local real_bind = hl.bind

local function press(index)
    local entry = events.binds[index]
    local ok, err = pcall(entry.fn)
    if not ok then
        events.press_errors[#events.press_errors + 1] = tostring(err)
    end
end

local function forbid_io()
    local function refuse()
        error("io at press time")
    end
    io.open = refuse
    io.popen = refuse
    os.execute = refuse
end

local function load_api()
    local path = via == "shim" and (os.getenv("BS_SHIM") or (root .. "/api/shim.lua")) or (root .. "/lua/banditshell.lua")
    local chunk = assert(loadfile(path))
    return chunk(root)
end

local env = setmetatable({ hl = hl, press = press, forbid_io = forbid_io, events = events, load_api = load_api }, { __index = _G })
local chunk = assert(loadfile(scenario, "t", env))
local ok, result = pcall(chunk)

local out = { ok = ok, result = ok and result or nil, error = (not ok) and tostring(result) or nil, exec = events.exec, notifications = events.notifications, press_errors = events.press_errors, binds = {} }
for i, entry in ipairs(events.binds) do
    out.binds[i] = { keys = entry.keys, kind = entry.kind, opts = entry.opts }
end
io.write(encode(out))
