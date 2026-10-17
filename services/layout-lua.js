.pragma library

var SNAKE = {
    minWindows: "min_windows",
    maxWindows: "max_windows",
    minWidth: "min_width",
    maxWidth: "max_width"
};

var LUA_WORDS = ["and", "break", "do", "else", "elseif", "end", "false", "for", "function", "global", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"];

var ENGINE = [
    "local function clamp(value, low, high)",
    "    return math.max(low, math.min(value, high))",
    "end",
    "",
    "local function leaves(region, out)",
    "    if region.kind == \"split\" then",
    "        for _, child in ipairs(region.children) do",
    "            leaves(child, out)",
    "        end",
    "    else",
    "        out[#out + 1] = region",
    "    end",
    "    return out",
    "end",
    "",
    "local function holders(arrangement)",
    "    local out = {}",
    "    for _, region in ipairs(leaves(arrangement.root, {})) do",
    "        if region.kind == \"slot\" or region.kind == \"stack\" then",
    "            out[#out + 1] = region",
    "        end",
    "    end",
    "    return out",
    "end",
    "",
    "local function deal(arrangement, count)",
    "    local kinds, members, assigned = {}, {}, {}",
    "    local list = holders(arrangement)",
    "    for _, region in ipairs(list) do",
    "        kinds[region.id] = region.kind",
    "    end",
    "    local first, again = arrangement.order.first, arrangement.order[\"repeat\"]",
    "    local fallback = list[1] and list[1].id",
    "    local function room(id)",
    "        return kinds[id] == \"stack\" or not members[id]",
    "    end",
    "    local turn = 0",
    "    for i = 1, count do",
    "        local chosen = i <= #first and room(first[i]) and first[i] or nil",
    "        local start = turn",
    "        while not chosen and turn - start < #again do",
    "            local tried = again[turn % #again + 1]",
    "            turn = turn + 1",
    "            if room(tried) then",
    "                chosen = tried",
    "            end",
    "        end",
    "        if not chosen and #again > 0 then",
    "            chosen = again[start % #again + 1]",
    "            turn = start + 1",
    "        end",
    "        chosen = chosen or first[math.min(i, #first)] or fallback",
    "        members[chosen] = members[chosen] or {}",
    "        table.insert(members[chosen], i)",
    "        assigned[i] = chosen",
    "    end",
    "    return members, assigned",
    "end",
    "",
    "local function held(region, members)",
    "    if region.kind == \"split\" then",
    "        local total = 0",
    "        for _, child in ipairs(region.children) do",
    "            total = total + held(child, members)",
    "        end",
    "        return total",
    "    end",
    "    return members[region.id] and #members[region.id] or 0",
    "end",
    "",
    "local function sizes_along(children, length, cross, axis, scales)",
    "    local sizes, fixed, total_weight, last_share = {}, 0, 0, 0",
    "    for i, child in ipairs(children) do",
    "        local size, scale = child.size, scales[child.id] or 1",
    "        if size.rule == \"share\" then",
    "            total_weight = total_weight + size.value * scale",
    "            last_share = i",
    "            sizes[i] = 0",
    "        else",
    "            local want",
    "            if size.rule == \"aspect\" then",
    "                want = math.floor(axis == \"row\" and cross * (size.width / size.height) or cross * (size.height / size.width))",
    "            elseif size.rule == \"fraction\" then",
    "                want = math.floor(length * clamp(size.value * scale, 0.05, 0.95))",
    "            else",
    "                want = math.floor(size.value)",
    "            end",
    "            local got = math.max(0, math.min(want, math.floor(length - fixed)))",
    "            sizes[i] = got",
    "            fixed = fixed + got",
    "        end",
    "    end",
    "    local free = math.max(0, length - fixed)",
    "    if last_share == 0 and #children > 0 then",
    "        sizes[#children] = sizes[#children] + free",
    "    end",
    "    local given = 0",
    "    for i, child in ipairs(children) do",
    "        if child.size.rule == \"share\" then",
    "            if i == last_share then",
    "                sizes[i] = free - given",
    "            else",
    "                sizes[i] = math.floor(free * (child.size.value * (scales[child.id] or 1)) / total_weight)",
    "                given = given + sizes[i]",
    "            end",
    "        end",
    "    end",
    "    return sizes",
    "end",
    "",
    "local function place_stack(box, axis, windows, weight, out)",
    "    local total = 0",
    "    for _, index in ipairs(windows) do",
    "        total = total + weight(index)",
    "    end",
    "    local row = axis == \"row\"",
    "    local start = row and box.x or box.y",
    "    local length = row and box.w or box.h",
    "    local position = start",
    "    for k, index in ipairs(windows) do",
    "        local part = k == #windows and (start + length - position) or math.floor(length * weight(index) / total)",
    "        if row then",
    "            out[index] = { x = position, y = box.y, w = part, h = box.h }",
    "        else",
    "            out[index] = { x = box.x, y = position, w = box.w, h = part }",
    "        end",
    "        position = position + part",
    "    end",
    "end",
    "",
    "local function layout_region(region, box, members, weight, parent, regions, out)",
    "    local record = {",
    "        id = region.id,",
    "        kind = region.kind,",
    "        axis = region.axis,",
    "        rule = region.size.rule,",
    "        parent = parent and parent.id or \"\",",
    "        parent_axis = parent and parent.axis or \"\",",
    "        x = box.x,",
    "        y = box.y,",
    "        w = box.w,",
    "        h = box.h,",
    "        windows = region.kind ~= \"split\" and members[region.id] or {},",
    "    }",
    "    regions[#regions + 1] = record",
    "    regions[region.id] = record",
    "    if region.kind == \"split\" then",
    "        local live = {}",
    "        for _, child in ipairs(region.children) do",
    "            if not (child.collapse and held(child, members) == 0) then",
    "                live[#live + 1] = child",
    "            end",
    "        end",
    "        local row = region.axis == \"row\"",
    "        local sizes = sizes_along(live, row and box.w or box.h, row and box.h or box.w, region.axis, state.scales)",
    "        local position = row and box.x or box.y",
    "        for i, child in ipairs(live) do",
    "            local child_box",
    "            if row then",
    "                child_box = { x = position, y = box.y, w = sizes[i], h = box.h }",
    "            else",
    "                child_box = { x = box.x, y = position, w = box.w, h = sizes[i] }",
    "            end",
    "            layout_region(child, child_box, members, weight, region, regions, out)",
    "            position = position + sizes[i]",
    "        end",
    "    elseif #record.windows > 0 then",
    "        place_stack(box, region.kind == \"stack\" and region.axis or \"column\", record.windows, weight, out)",
    "    end",
    "end",
    "",
    "local function passes(arrangement, area, count)",
    "    local when = arrangement.when",
    "    if when.min_windows > 0 and count < when.min_windows then return false end",
    "    if when.max_windows > 0 and count > when.max_windows then return false end",
    "    if when.min_width > 0 and area.w < when.min_width then return false end",
    "    if when.max_width > 0 and area.w > when.max_width then return false end",
    "    return true",
    "end",
    "",
    "local function fits(arrangement, regions)",
    "    for _, region in ipairs(regions) do",
    "        if (region.kind == \"slot\" or region.kind == \"stack\") and (region.w < arrangement.fit or region.h < arrangement.fit) then",
    "            return false",
    "        end",
    "    end",
    "    return true",
    "end",
    "",
    "local function arrange_with(index, area, count, weight)",
    "    local arrangement = layout.arrangements[index]",
    "    local members, assigned = deal(arrangement, count)",
    "    local regions, out = {}, {}",
    "    layout_region(arrangement.root, { x = area.x, y = area.y, w = area.w, h = area.h }, members, weight, nil, regions, out)",
    "    return { regions = regions, windows = out, assigned = assigned }",
    "end",
    "",
    "local function arrange(area, count, weight)",
    "    local last = #layout.arrangements",
    "    for i = 1, last - 1 do",
    "        local arrangement = layout.arrangements[i]",
    "        if passes(arrangement, area, count) then",
    "            local tried = arrange_with(i, area, count, weight)",
    "            if fits(arrangement, tried.regions) then",
    "                return tried",
    "            end",
    "        end",
    "    end",
    "    return arrange_with(last, area, count, weight)",
    "end",
    "",
    "local function weigher(targets)",
    "    return function(index)",
    "        local window = targets[index].window",
    "        return window and state.weights[window.address] or 1",
    "    end",
    "end",
    "",
    "local function recalculate(ctx)",
    "    local targets = ctx.targets",
    "    if #targets == 0 then return end",
    "    local placed = arrange(ctx.area, #targets, weigher(targets))",
    "    for index, target in ipairs(targets) do",
    "        local box = placed.windows[index]",
    "        if box then",
    "            target:place(box)",
    "        end",
    "    end",
    "end",
    "",
    "local axes = { taller = \"column\", shorter = \"column\", wider = \"row\", narrower = \"row\" }",
    "",
    "local function promote(targets, index)",
    "    local first = targets[1].window",
    "    if index == 1 or not first then return end",
    "    local swap = function()",
    "        hl.dispatch(hl.dsp.window.swap({ target = \"address:\" .. first.address }))",
    "    end",
    "    if hl.timer then",
    "        hl.timer(swap, { timeout = 1, type = \"oneshot\" })",
    "    else",
    "        swap()",
    "    end",
    "end",
    "",
    "local function layout_msg(ctx, msg)",
    "    if msg == \"reset\" then",
    "        state.weights, state.scales = {}, {}",
    "        return",
    "    end",
    "    local active = hl.get_active_window()",
    "    if not active then return end",
    "    local targets = ctx.targets",
    "    local index",
    "    for i, target in ipairs(targets) do",
    "        if target.window and target.window.address == active.address then",
    "            index = i",
    "        end",
    "    end",
    "    if not index then return end",
    "    if msg == \"promote\" then",
    "        promote(targets, index)",
    "        return",
    "    end",
    "    local axis = axes[msg]",
    "    if not axis then return end",
    "    local limits = layout.messages",
    "    local factor = (msg == \"taller\" or msg == \"wider\") and limits.step or 1 / limits.step",
    "    local placed = arrange(ctx.area, #targets, weigher(targets))",
    "    local holder = placed.regions[placed.assigned[index]]",
    "    if holder.kind == \"stack\" and holder.axis == axis then",
    "        state.weights[active.address] = math.max(limits.smallest, math.min((state.weights[active.address] or 1) * factor, limits.largest))",
    "        return",
    "    end",
    "    local walk = holder",
    "    while walk do",
    "        if walk.parent_axis == axis and (walk.rule == \"share\" or walk.rule == \"fraction\") then",
    "            state.scales[walk.id] = math.max(limits.smallest, math.min((state.scales[walk.id] or 1) * factor, limits.largest))",
    "            return",
    "        end",
    "        walk = walk.parent ~= \"\" and placed.regions[walk.parent] or nil",
    "    end",
    "end"
].join("\n");

function luaString(text) {
    return "\"" + String(text).replace(/\\/g, "\\\\").replace(/"/g, "\\\"").replace(/\n/g, "\\n") + "\"";
}

function luaKey(key) {
    var name = SNAKE[key] || key;
    if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(name) && LUA_WORDS.indexOf(name) < 0)
        return name;
    return "[" + luaString(name) + "]";
}

function luaNumber(value) {
    return String(Number(value));
}

function trimmedRegion(region) {
    var out = { id: region.id, kind: region.kind };
    if (region.kind === "stack" || region.kind === "split")
        out.axis = region.axis;
    out.size = region.size;
    if (region.collapse)
        out.collapse = true;
    if (region.kind === "split")
        out.children = region.children.map(trimmedRegion);
    return out;
}

function luaTable(value, indent) {
    if (value === null || value === undefined)
        return "nil";
    if (typeof value === "boolean")
        return value ? "true" : "false";
    if (typeof value === "number")
        return luaNumber(value);
    if (typeof value === "string")
        return luaString(value);
    var array = Array.isArray(value);
    var parts = array ? value.map(function (item) {
        return luaTable(item, indent + "    ");
    }) : Object.keys(value).map(function (key) {
        return luaKey(key) + " = " + luaTable(value[key], indent + "    ");
    });
    if (!parts.length)
        return "{}";
    var inline = "{ " + parts.join(", ") + " }";
    if (inline.indexOf("\n") < 0 && indent.length + inline.length <= 100)
        return inline;
    return "{\n" + parts.map(function (part) {
        return indent + "    " + part + ",";
    }).join("\n") + "\n" + indent + "}";
}

function layoutTable(model) {
    return {
        arrangements: model.arrangements.map(function (arrangement) {
            return {
                fit: arrangement.fit,
                when: arrangement.when,
                order: { first: arrangement.order.first, repeat: arrangement.order.repeat },
                root: trimmedRegion(arrangement.root)
            };
        }),
        messages: model.messages
    };
}

function generate(model) {
    return [
        "-- " + model.name + ": made in the banditshell Layout Workshop. Saving there rewrites this file.",
        "",
        "local name = " + luaString(model.name),
        "",
        "local layout = " + luaTable(layoutTable(model), ""),
        "",
        "banditshell_workshop = banditshell_workshop or {}",
        "banditshell_workshop.layouts = banditshell_workshop.layouts or {}",
        "banditshell_workshop.state = banditshell_workshop.state or {}",
        "local state = banditshell_workshop.state[name] or { weights = {}, scales = {} }",
        "banditshell_workshop.state[name] = state",
        "",
        ENGINE,
        "",
        "banditshell_workshop.layouts[name] = { recalculate = recalculate, layout_msg = layout_msg }",
        "",
        "banditshell_workshop.registered = banditshell_workshop.registered or {}",
        "if not banditshell_workshop.registered[name] then",
        "    hl.layout.register(name, {",
        "        recalculate = function(ctx)",
        "            return banditshell_workshop.layouts[name].recalculate(ctx)",
        "        end,",
        "        layout_msg = function(ctx, msg)",
        "            return banditshell_workshop.layouts[name].layout_msg(ctx, msg)",
        "        end,",
        "    })",
        "    banditshell_workshop.registered[name] = true",
        "end",
        "",
        "return { name = \"lua:\" .. name, layout = layout }",
        ""
    ].join("\n");
}

function bindLines(model, messages) {
    return messages.map(function (entry) {
        return "hl.bind(" + luaString(entry.chord) + ", hl.dsp.layout(" + luaString(entry.name) + "), { description = " + luaString(model.name + ": " + entry.label) + " })";
    });
}

function loader(paths, afterReload) {
    var lines = afterReload ? ["if banditshell_workshop then banditshell_workshop.registered = {} end"] : [];
    lines.push("local failed = {}");
    lines.push("for _, file in ipairs({ " + paths.map(luaString).join(", ") + " }) do");
    lines.push("    local ok, problem = pcall(dofile, file)");
    lines.push("    if not ok then failed[#failed + 1] = tostring(problem) end");
    lines.push("end");
    lines.push("if #failed > 0 then error(table.concat(failed, \"\\n\"), 0) end");
    return lines.join("\n");
}

function failedNames(output, names, folder) {
    var text = String(output || "");
    if (text.trim() === "ok")
        return [];
    return names.filter(function (name) {
        return text.indexOf(folder + "/" + name + ".lua") >= 0 || text.indexOf("'lua:" + name + "'") >= 0;
    });
}
