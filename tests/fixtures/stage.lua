
local M = {}

M.name = "lua:stage"

local RATIO = 16 / 9

local weights = {}

M.stage_of = {}

local function weight(target)
    local w = target.window
    return w and weights[w.address] or 1
end

local function stack(column, x, y, w, h)
    local total = 0
    for _, t in ipairs(column) do
        total = total + weight(t)
    end
    local top = y
    for i, t in ipairs(column) do
        local th = i == #column and (y + h - top) or math.floor(h * weight(t) / total)
        t:place({ x = x, y = top, w = w, h = th })
        top = top + th
    end
end

local function recalculate(ctx)
    local a, targets = ctx.area, ctx.targets
    if #targets == 0 then return end

    local first = targets[1].window
    if first and first.workspace then
        M.stage_of[first.workspace.id] = first.address
    end

    local sw = math.min(math.floor(a.h * RATIO), math.floor(a.w))
    local side = math.floor((a.w - sw) / 2)

    if side < 1 then
        stack(targets, a.x, a.y, a.w, a.h)
        return
    end

    targets[1]:place({ x = a.x + side, y = a.y, w = sw, h = a.h })

    local right, left = {}, {}
    for i = 2, #targets do
        table.insert(i % 2 == 0 and right or left, targets[i])
    end
    stack(left, a.x, a.y, side, a.h)
    stack(right, a.x + side + sw, a.y, a.w - side - sw, a.h)
end

local steps = { taller = 1.25, shorter = 0.8 }

local function layout_msg(ctx, msg)
    local step = steps[msg]
    local active = hl.get_active_window()
    if not step or not active then return end

    for i, t in ipairs(ctx.targets) do
        local w = t.window
        if w and w.address == active.address then
            if i > 1 then
                weights[w.address] = math.max(0.25, math.min((weights[w.address] or 1) * step, 4))
            end
            return
        end
    end
end

hl.layout.register("stage", { recalculate = recalculate, layout_msg = layout_msg })

function M.window()
    local w = hl.get_active_window()
    if not w or not w.workspace or not w.layout or w.layout.name ~= M.name then return nil end
    return w
end

function M.put_on_stage()
    local w = M.window()
    if not w then return end
    local current = M.stage_of[w.workspace.id]
    if current and current ~= w.address then
        hl.dispatch(hl.dsp.window.swap({ target = "address:" .. current }))
    end
end

function M.resize(msg)
    return function()
        if M.window() then
            hl.dispatch(hl.dsp.layout(msg))
        end
    end
end

return M
