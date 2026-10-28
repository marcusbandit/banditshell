local root = ...
local API = 1

local home = os.getenv("HOME") or ""
local state = os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")
local pointer = state .. "/banditshell/root"

local function first_line(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local line = file:read("l")
    file:close()
    return line
end

local function readable(path)
    local file = io.open(path, "r")
    if not file then
        return false
    end
    file:close()
    return true
end

local function quote(text)
    return "'" .. (tostring(text):gsub("'", "'\\''")) .. "'"
end

if not root or root == "" then
    root = os.getenv("BANDITSHELL_DIR")
end
if not root or root == "" then
    root = first_line(pointer) or ""
end

local told = {}

local function notify(text, phase)
    local key = (phase or "load") .. "\0" .. text
    if told[key] then
        return
    end
    told[key] = true
    local shown = pcall(function()
        hl.notification.create({ text = "banditshell: " .. text, timeout = 9000, color = "rgb(e5c07b)" })
    end)
    if not shown then
        pcall(function()
            hl.exec_cmd("hyprctl notify -1 9000 'rgb(e5c07b)' " .. quote("banditshell: " .. text))
        end)
    end
end

local rows = {}
local trie = { child = {} }
local loaded = false

local function insert(id, row)
    local node = trie
    for segment in id:gmatch("[^.]+") do
        node.child = node.child or {}
        node.child[segment] = node.child[segment] or {}
        node = node.child[segment]
    end
    node.row = row
end

local function load_table()
    local file = io.open(root .. "/api/actions.tsv", "r")
    if not file then
        return
    end
    for line in file:lines() do
        if line:sub(1, 1) == "#" then
            local number = line:match("^# api (%d+)")
            if number and tonumber(number) ~= API then
                notify("the action table is api " .. number .. " but this module is api " .. API .. "; run: banditshell doctor api")
            end
        elseif line ~= "" then
            local id, status, since, argv, description = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?(.*)$")
            if id and id ~= "" then
                local row = { id = id, status = status, since = tonumber(since) or 1, head = table.concat({ id, status, since, argv }, "\t"), description = description }
                rows[id] = row
                insert(id, row)
            end
        end
    end
    file:close()
    loaded = true
end

local function command_for(id, args, row)
    local parts = {
        "cli=" .. quote(root .. "/cli/banditshell") .. ";",
        '[ -x "$cli" ] || cli="$(head -n 1 ' .. quote(pointer) .. ' 2>/dev/null)/cli/banditshell";',
        '[ -x "$cli" ] || cli=banditshell;',
    }
    if row and not row.status:match("^deprecated") and not row.status:match("^removed") then
        parts[#parts + 1] = "BANDITSHELL_ROW=" .. quote(row.head)
    end
    parts[#parts + 1] = 'exec "$cli" action ' .. quote(id)
    for i = 1, #args do
        parts[#parts + 1] = quote(args[i])
    end
    return table.concat(parts, " ")
end

local function fire(command)
    local ok = pcall(hl.exec_cmd, command)
    if not ok then
        notify("could not run an action: hl.exec_cmd failed", "press")
    end
end

local VERBS = { toggle = true, open = true, close = true }
local SERVED = {}
for name in ("launcher session clipboard media calculator quickcontrols keyboard notifications island hotkeys files wallpaper audio network bluetooth battery calendar clock update"):gmatch("%S+") do
    SERVED[name] = true
end

local function shortcut_for(id)
    if id == "panel.close" then
        return "panel.close"
    end
    local name, verb = id:match("^panel%.([a-z0-9_]+)%.([a-z]+)$")
    if not name then
        name, verb = id:match("^(launcher)%.([a-z]+)$")
    end
    if not name or not VERBS[verb] or not SERVED[name] then
        return nil
    end
    if name == "launcher" then
        return verb == "toggle" and "launcher" or ("launcher." .. verb)
    end
    return "panel." .. name .. "." .. verb
end

local function shell_up()
    if type(hl.get_layers) ~= "function" then
        return false
    end
    local ok, layers = pcall(hl.get_layers, { namespace = "banditshell" })
    return ok and type(layers) == "table" and #layers > 0
end

local function press(id, command)
    local name = shortcut_for(id)
    if name and hl.dsp and hl.dsp.global and hl.dispatch and shell_up() then
        local made, dispatcher = pcall(hl.dsp.global, "banditshell:" .. name)
        if made and pcall(hl.dispatch, dispatcher) then
            return
        end
    end
    fire(command)
end

local function advance(entries, segment)
    local out = {}
    if segment == "*" then
        return out
    end
    for _, entry in ipairs(entries) do
        local child = entry.node.child
        if child then
            if child[segment] then
                out[#out + 1] = { node = child[segment], wild = entry.wild }
            end
            if child["*"] then
                out[#out + 1] = { node = child["*"], wild = entry.wild + 1 }
            end
        end
    end
    return out
end

local function cheapest(entries)
    local best
    for _, entry in ipairs(entries) do
        if entry.node.row and (not best or entry.wild < best.wild) then
            best = entry
        end
    end
    return best
end

local function split_id(id)
    local segments = {}
    for segment in tostring(id):gmatch("[^.]+") do
        segments[#segments + 1] = segment
    end
    return segments
end

local function row_of(id)
    if type(id) ~= "string" or not loaded or not id:match("^[a-z0-9_.]+$") then
        return nil
    end
    if id:find("..", 1, true) or id:sub(1, 1) == "." or id:sub(-1) == "." then
        return nil
    end
    local entries = { { node = trie, wild = 0 } }
    for _, segment in ipairs(split_id(id)) do
        entries = advance(entries, segment)
        if #entries == 0 then
            return nil
        end
    end
    local best = cheapest(entries)
    return best and best.node.row or nil
end

local function judge(id, row)
    local newer = row.status:match("^deprecated=(.+)$")
    if newer then
        notify("bs." .. id .. " is deprecated, use bs." .. newer .. " instead; it still works")
    elseif row.status:sub(1, 7) == "removed" then
        local into = row.status:match("^removed=(.+)$")
        notify("bs." .. id .. " is gone" .. (into and (", use bs." .. into .. " instead") or "") .. "; it still runs the closest replacement")
    end
end

local ids = setmetatable({}, { __mode = "k" })
local fakes = setmetatable({}, { __mode = "k" })

local function missing(id, phase)
    if loaded then
        notify("bs." .. id .. " is not an action in api " .. API .. "; run: banditshell api list", phase)
    else
        notify("the action table is missing from " .. root .. "; run: banditshell doctor api", phase)
    end
end

local function absent(id)
    local function nothing()
        missing(id, "press")
    end
    return nothing
end

local function bound(id, args, row)
    local command = command_for(id, args, row)
    return function()
        fire(command)
    end
end

local function plain(args)
    for i = 1, #args do
        local kind = type(args[i])
        if kind ~= "string" and kind ~= "number" then
            return false
        end
    end
    return true
end

local function leaf(id, row)
    judge(id, row)
    local command = command_for(id, {}, row)
    local function action(...)
        local count = select("#", ...)
        if count == 0 then
            press(id, command)
            return nil
        end
        local args = { ... }
        if not plain(args) then
            press(id, command)
            return nil
        end
        return bound(id, args, row)
    end
    ids[action] = id
    return action
end

local function ghost(id)
    local object = setmetatable({}, {
        __index = function(self, key)
            local value = ghost(id .. "." .. tostring(key))
            rawset(self, key, value)
            return value
        end,
        __call = function()
            missing(id, "press")
        end,
    })
    fakes[object] = id
    return object
end

local function branch(path, entries)
    local object = setmetatable({}, {
        __index = function(self, key)
            if type(key) ~= "string" then
                return nil
            end
            local id = path == "" and key or (path .. "." .. key)
            local next_entries = advance(entries, key)
            local best = cheapest(next_entries)
            local value
            if best then
                value = leaf(id, best.node.row)
            elseif #next_entries > 0 then
                value = branch(id, next_entries)
            else
                value = ghost(id)
            end
            rawset(self, key, value)
            return value
        end,
    })
    if path ~= "" then
        fakes[object] = path
        getmetatable(object).__call = function()
            notify("bs." .. path .. " is a group of actions, not one; run: banditshell api list '" .. path .. ".*'", "press")
        end
    end
    return object
end

local M = branch("", { { node = trie, wild = 0 } })

local function target_of(spec)
    if type(spec) == "table" and not fakes[spec] then
        local args = {}
        for i = 2, #spec do
            args[#args + 1] = spec[i]
        end
        return spec[1], args
    end
    return spec, {}
end

local function resolve(spec, ...)
    local id, args = target_of(spec)
    local extra = { ... }
    for i = 1, #extra do
        args[#args + 1] = extra[i]
    end
    if type(id) == "function" then
        return id, ids[id]
    end
    if type(id) == "table" and fakes[id] then
        missing(fakes[id])
        return absent(fakes[id]), nil
    end
    if type(id) ~= "string" then
        missing(tostring(id))
        return absent(tostring(id)), nil
    end
    local row = row_of(id)
    if not row or not plain(args) then
        missing(id)
        return absent(id), nil
    end
    judge(id, row)
    local callable
    if #args == 0 then
        local command = command_for(id, {}, row)
        callable = function()
            press(id, command)
        end
    else
        callable = bound(id, args, row)
    end
    ids[callable] = id
    return callable, id
end

function M.action(spec, ...)
    local callable = resolve(spec, ...)
    return callable
end

function M.run(spec, ...)
    local callable = resolve(spec, ...)
    callable()
end

function M.describe(spec)
    local id = spec
    if type(spec) == "function" then
        id = ids[spec]
    elseif type(spec) == "table" and not fakes[spec] then
        id = spec[1]
    end
    local row = row_of(id)
    return row and row.description or nil
end

function M.has(id)
    return row_of(id) ~= nil
end

function M.need(number)
    if type(number) == "number" and number > API then
        notify("this config wants api " .. number .. " but banditshell has api " .. API .. "; update banditshell")
    end
end

function M.cli()
    local path = root .. "/cli/banditshell"
    if readable(path) then
        return path
    end
    local moved = first_line(pointer)
    if moved and moved ~= "" and readable(moved .. "/cli/banditshell") then
        return moved .. "/cli/banditshell"
    end
    return "banditshell"
end

function M.bind(keys, spec, opts)
    local callable = resolve(spec)
    local merged = {}
    for key, value in pairs(opts or {}) do
        merged[key] = value
    end
    if merged.description == nil and merged.desc == nil then
        local text = M.describe(callable)
        if text then
            merged.description = text
        end
    end
    local ok, err = pcall(hl.bind, keys, callable, merged)
    if not ok then
        notify("could not bind " .. tostring(keys) .. ": " .. tostring(err))
    end
end

rawset(M, "api", API)
rawset(M, "root", root)

load_table()

if not loaded then
    notify("the action table is missing from " .. root .. "; run: banditshell doctor api")
elseif not readable(root .. "/cli/banditshell") then
    notify("the checkout moved or is gone (" .. root .. "); run: banditshell doctor api")
end

if type(hl) == "table" and type(hl.bind) == "function" then
    local original = hl.bind
    hl.bind = function(keys, dispatcher, ...)
        if type(dispatcher) == "table" and fakes[dispatcher] then
            local id = fakes[dispatcher]
            missing(id)
            dispatcher = absent(id)
        end
        return original(keys, dispatcher, ...)
    end
end

return M
