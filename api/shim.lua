-- banditshell shim, format 1. Written by banditshell; never edit by hand.
local home = os.getenv("HOME") or ""
local state = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")

local function first_line(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local line = file:read("l")
    file:close()
    return line
end

local candidates = {}
for _, root in ipairs({ os.getenv("BANDITSHELL_DIR") or "", first_line(state .. "/banditshell/root") or "", home .. "/Projects/banditshell", home .. "/banditshell" }) do
    if root ~= "" then
        candidates[#candidates + 1] = root
    end
end

for _, root in ipairs(candidates) do
    local chunk = loadfile(root .. "/lua/banditshell.lua")
    if chunk then
        local ok, api = pcall(chunk, root)
        if ok and type(api) == "table" then
            return api
        end
    end
end

local function tell()
    pcall(function()
        hl.notification.create({ text = "banditshell: not found; run: banditshell doctor api", timeout = 9000, color = "rgb(e06c75)" })
    end)
end

local hollow = {}
hollow.__index = function()
    return setmetatable({}, hollow)
end
hollow.__call = tell

if type(hl) == "table" and type(hl.bind) == "function" then
    local original = hl.bind
    hl.bind = function(keys, dispatcher, ...)
        if getmetatable(dispatcher) == hollow then
            dispatcher = tell
        end
        return original(keys, dispatcher, ...)
    end
end

local absent = setmetatable({ api = 0 }, hollow)
rawset(absent, "need", function() end)
rawset(absent, "cli", function() return "banditshell" end)
rawset(absent, "has", function() return false end)
rawset(absent, "describe", function() return nil end)
rawset(absent, "action", function() return tell end)
rawset(absent, "run", tell)
rawset(absent, "bind", function(keys, _, opts)
    pcall(hl.bind, keys, tell, opts)
end)
tell()
return absent
