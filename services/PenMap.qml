pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property bool active: root.editing

    readonly property bool aspectLocked: root.locked

    readonly property bool followWindow: root.following

    readonly property real surfaceAspect: {
        const surface = Config.values.pen.surface;
        const w = Number(surface?.width);
        const h = Number(surface?.height);

        return w > 0 && h > 0 ? w / h : 1;
    }

    readonly property string monitorName: root.home

    readonly property rect region: root.mapping

    readonly property rect hoveredWindow: root.hovered

    readonly property string hoveredWindowName: root.hoveredName

    readonly property string boundWindow: root.bound

    readonly property string boundWindowName: root.boundName

    readonly property bool tracking: root.bound !== ""

    readonly property bool padConnected: root.padAlive

    function begin(): void {
        if (root.editing)
            return;

        root.before = {
            home: root.home,
            region: root.mapping,
            locked: root.locked,
            bound: root.bound,
            boundName: root.boundName
        };

        root.mapped = true;
        root.editing = true;
        root.unbind();

        root.scanMonitors();

        root.forgetWindows();
        if (root.following)
            root.scanClients();

        padLost.stop();
    }

    function commit(): void {
        if (!root.editing)
            return;

        if (root.following && root.hovered.width > 0 && root.hovered.height > 0) {
            root.snapToWindow(root.hovered);
            root.bindWindow(root.hoveredAddr, root.hoveredName);
        } else {
            root.unbindWindow();
        }

        root.editing = false;
        root.applyRegion();
        root.save();
        root.forgetWindows();
    }

    function cancel(): void {
        if (!root.editing)
            return;

        root.editing = false;

        const was = root.before;
        if (was) {
            root.home = was.home;
            root.mapping = was.region;
            root.locked = was.locked;

            root.bound = root.following ? was.bound : "";
            root.boundName = root.following ? was.boundName : "";
            root.boundMisses = 0;
        }

        root.applyRegion();
        root.save();
        root.forgetWindows();

        root.followBound();
    }

    function toggleAspect(): void {
        root.locked = !root.locked;

        root.proposeRegion(root.mapping.x, root.mapping.y, root.mapping.width, root.mapping.height);

        if (!root.editing) {
            if (root.mapped)
                root.applyRegion();
            root.save();
        }
    }

    function fitAndCentre(): void {
        const mon = root.monitorNamed(root.home) ?? root.monitors.find(m => m.focused) ?? root.monitors[0];
        if (!mon)
            return;

        root.mapped = true;
        root.locked = true;
        root.unbindWindow();

        const aspect = root.surfaceAspect;
        let w = mon.h * aspect;
        let h = mon.h;

        if (w > mon.w) {
            w = mon.w;
            h = w / aspect;
        }

        root.home = mon.name;
        root.proposeRegion(mon.x + (mon.w - w) / 2, mon.y + (mon.h - h) / 2, w, h);

        if (!root.editing) {
            root.applyRegion();
            root.save();
        }
    }

    function toggleFollowWindow(): void {
        root.following = !root.following;

        if (!root.following) {

            root.forgetWindows();

            root.unbindWindow();
            return;
        }

        if (root.editing)
            root.scanClients();
        else
            root.save();
    }

    function unbindWindow(): void {
        root.bound = "";
        root.boundName = "";
        root.boundMisses = 0;

        if (!root.editing)
            root.save();
    }

    function setPointer(gx: real, gy: real): void {

        if (!root.editing)
            return;

        if (!isFinite(gx) || !isFinite(gy))
            return;

        root.pointerX = gx;
        root.pointerY = gy;
        root.pointerKnown = true;
        root.refreshHover();
    }

    function proposeRegion(x: real, y: real, w: real, h: real): void {
        let px = x;
        let py = y;

        let pw = Math.abs(w);
        let ph = Math.abs(h);

        if (!isFinite(px) || !isFinite(py) || !isFinite(pw) || !isFinite(ph))
            return;

        const mon = root.homeFor(px, py, pw, ph);
        if (!mon) {

            root.mapping = Qt.rect(px, py, pw, ph);
            return;
        }

        const aspect = root.surfaceAspect;
        const floor = Math.max(1, Number(Config.values.pen.minSize) || 1);

        if (root.locked) {

            let t = (pw * aspect + ph) / (aspect * aspect + 1);

            const ceiling = Math.min(mon.h, mon.w / aspect);
            t = Math.min(Math.max(t, Math.max(floor, floor / aspect)), ceiling);

            pw = t * aspect;
            ph = t;
        } else {
            pw = Math.min(Math.max(pw, floor), mon.w);
            ph = Math.min(Math.max(ph, floor), mon.h);
        }

        px = root.clamp(px, mon.x, mon.x + mon.w - pw);
        py = root.clamp(py, mon.y, mon.y + mon.h - ph);

        root.home = mon.name;
        root.mapping = Qt.rect(px, py, pw, ph);
    }

    property bool editing: false
    property rect mapping
    property string home: ""

    property bool locked: Config.values.pen.aspectLock

    property bool following: false

    property bool padAlive: false

    property bool mapped: false

    property var before: null

    property var monitors: []

    property bool monitorsKnown: false
    property bool stateKnown: false
    property bool settled: false

    property string layoutSeen: ""

    property bool layoutMoved: false

    property bool pushAnyway: false

    property var stored: null

    function clamp(v: real, lo: real, hi: real): real {

        if (hi < lo)
            return lo;
        return v < lo ? lo : v > hi ? hi : v;
    }

    function sameRect(a: rect, b: rect): bool {
        return a.x === b.x && a.y === b.y && a.width === b.width && a.height === b.height;
    }

    function bareAddress(addr: string): string {
        const s = String(addr ?? "");
        return (s.startsWith("0x") ? s.slice(2) : s).toLowerCase();
    }

    function monitorNamed(name: string): var {
        return root.monitors.find(m => m.name === name) ?? null;
    }

    function homeFor(x: real, y: real, w: real, h: real): var {
        const mons = root.monitors;
        if (!mons.length)
            return null;

        const cx = x + w / 2;
        const cy = y + h / 2;

        for (const m of mons)
            if (cx >= m.x && cx < m.x + m.w && cy >= m.y && cy < m.y + m.h)
                return m;

        let best = null;
        let bestArea = 0;
        for (const m of mons) {
            const ox = Math.max(0, Math.min(x + w, m.x + m.w) - Math.max(x, m.x));
            const oy = Math.max(0, Math.min(y + h, m.y + m.h) - Math.max(y, m.y));
            if (ox * oy > bestArea) {
                bestArea = ox * oy;
                best = m;
            }
        }
        if (best)
            return best;

        let near = mons[0];
        let nearD = Infinity;
        for (const m of mons) {
            const dx = cx - (m.x + m.w / 2);
            const dy = cy - (m.y + m.h / 2);
            const d = dx * dx + dy * dy;
            if (d < nearD) {
                nearD = d;
                near = m;
            }
        }
        return near;
    }

    function defaultRegion(): void {
        const mon = root.monitors.find(m => m.focused) ?? root.monitors[0];
        if (!mon)
            return;

        const aspect = root.surfaceAspect;
        let h = mon.h;
        let w = h * aspect;

        if (w > mon.w) {
            w = mon.w;
            h = w / aspect;
        }

        root.home = mon.name;
        root.proposeRegion(mon.x + (mon.w - w) / 2, mon.y + (mon.h - h) / 2, w, h);
    }

    function luaString(s: string): string {
        return `"${String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
    }

    function evalDevice(fields: string): void {
        root.evalLua(`hl.device({ name = ${root.luaString(Config.values.pen.device)}, ${fields} })`);
    }

    function unbind(): void {
        root.evalDevice(`output = "", absolute_region_position = false, region_position = {0,0}, region_size = {0,0}`);
    }

    function applyRegion(): void {
        if (!root.mapped)
            return;

        const mon = root.monitorNamed(root.home);
        if (!mon) {

            console.warn(`PenMap: no monitor named "${root.home}" is connected, so the mapping was not applied.`);
            return;
        }

        const rx = Math.round(root.mapping.x - mon.x);
        const ry = Math.round(root.mapping.y - mon.y);
        const rw = Math.max(1, Math.round(root.mapping.width));
        const rh = Math.max(1, Math.round(root.mapping.height));

        root.evalDevice(`output = ${root.luaString(mon.name)}, region_position = {${rx},${ry}}, region_size = {${rw},${rh}}`);
    }

    property string queued: ""

    function evalLua(expr: string): void {

        if (!Compositor.isHyprland)
            return;

        if (applier.running) {
            root.queued = expr;
            return;
        }
        root.runLua(expr);
    }

    function runLua(expr: string): void {
        applier.command = ["hyprctl", "eval", expr];
        applier.running = true;
    }

    Process {
        id: applier

        stdout: StdioCollector {
            onStreamFinished: {
                const answer = text.trim();

                if (answer && answer !== "ok")
                    console.warn(`PenMap: hyprctl eval answered "${answer}".`);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn(`PenMap: hyprctl eval: ${text.trim()}`)
        }

        onExited: if (root.queued) {
            const next = root.queued;
            root.queued = "";
            root.runLua(next);
        }
    }

    property bool scanAgain: false

    function scanMonitors(): void {

        if (monScan.running) {
            root.scanAgain = true;
            return;
        }
        monScan.running = true;
    }

    Process {
        id: monScan

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: root.readMonitors(text)
        }

        onExited: {
            if (root.scanAgain) {
                root.scanAgain = false;
                return root.scanMonitors();
            }
            root.afterScan();
        }
    }

    function readMonitors(text: string): void {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {

        }
        if (!Array.isArray(raw))
            raw = [];

        const next = [];
        for (const m of raw) {
            if (!m || !m.name || m.disabled === true)
                continue;

            const scale = typeof m.scale === "number" && m.scale > 0 ? m.scale : 1;

            const turned = Number(m.transform) % 2 === 1;
            const w = (turned ? m.height : m.width) / scale;
            const h = (turned ? m.width : m.height) / scale;
            if (!(w > 0) || !(h > 0))
                continue;

            next.push({
                name: m.name,

                id: typeof m.id === "number" ? m.id : -1,
                x: Number(m.x) || 0,
                y: Number(m.y) || 0,
                w: w,
                h: h,
                focused: m.focused === true,

                ws: Number(m.activeWorkspace?.id) || 0,
                special: Number(m.specialWorkspace?.id) || 0
            });
        }

        root.layoutMoved = false;
        if (!next.length)
            return;

        const seen = next.map(m => `${m.name}@${m.x},${m.y}+${m.w}x${m.h}`).join("|");
        root.layoutMoved = seen !== root.layoutSeen;
        root.layoutSeen = seen;

        root.monitors = next;
        root.monitorsKnown = true;
    }

    function afterScan(): void {
        const forced = root.pushAnyway;
        root.pushAnyway = false;

        if (!root.settled)
            return root.settle();

        if (!forced && !root.layoutMoved)
            return;

        root.proposeRegion(root.mapping.x, root.mapping.y, root.mapping.width, root.mapping.height);

        if (root.editing)
            root.unbind();
        else
            root.applyRegion();
    }

    property var snapshot: []

    property real pointerX: 0
    property real pointerY: 0
    property bool pointerKnown: false

    property rect hovered
    property string hoveredName: ""

    property string hoveredAddr: ""

    readonly property var candidates: root.buildCandidates(root.snapshot, root.monitors)

    onCandidatesChanged: root.refreshHover()

    function buildCandidates(raw: var, mons: var): var {
        const out = [];
        if (!Array.isArray(raw) || !Array.isArray(mons))
            return out;

        const byId = {};
        const shown = {};
        for (const m of mons) {
            byId[m.id] = m;
            if (m.ws)
                shown[m.ws] = true;
            if (m.special)
                shown[m.special] = true;
        }

        for (let i = 0; i < raw.length; i++) {
            const c = raw[i];
            if (!c || c.mapped !== true || c.hidden === true)
                continue;

            const ws = Number(c.workspace?.id);
            if (!isFinite(ws))
                continue;

            if (c.pinned !== true && shown[ws] !== true)
                continue;

            const at = c.at;
            const size = c.size;
            if (!at || !size || at.length < 2 || size.length < 2)
                continue;

            let x = Number(at[0]);
            let y = Number(at[1]);
            let w = Number(size[0]);
            let h = Number(size[1]);
            if (!isFinite(x) || !isFinite(y) || !(w > 0) || !(h > 0))
                continue;

            const mon = byId[Number(c.monitor)];
            if (mon) {
                const x0 = Math.max(x, mon.x);
                const y0 = Math.max(y, mon.y);
                const x1 = Math.min(x + w, mon.x + mon.w);
                const y1 = Math.min(y + h, mon.y + mon.h);
                if (!(x1 > x0) || !(y1 > y0))
                    continue;
                x = x0;
                y = y0;
                w = x1 - x0;
                h = y1 - y0;
            }

            const above = [Number(c.fullscreen) > 0, c.floating === true, c.pinned === true];
            let rung = 0;
            for (let r = 0; r < above.length; r++)
                if (above[r])
                    rung = r + 1;

            const parts = String(c["class"] ?? "").split(".").filter(s => s.length > 0);

            out.push({
                x: x,
                y: y,
                w: w,
                h: h,

                address: String(c.address ?? ""),

                order: i,
                rank: (ws < 0 ? 1 : 0) * (above.length + 1) + rung,
                name: parts.length ? parts[parts.length - 1] : String(c.title ?? "")
            });
        }

        return out;
    }

    function windowAt(gx: real, gy: real): var {
        let best = null;
        for (const c of root.candidates) {
            if (gx < c.x || gy < c.y || gx >= c.x + c.w || gy >= c.y + c.h)
                continue;
            if (!best || c.rank > best.rank || (c.rank === best.rank && c.order > best.order))
                best = c;
        }
        return best;
    }

    function refreshHover(): void {
        const hit = root.editing && root.following && root.pointerKnown ? root.windowAt(root.pointerX, root.pointerY) : null;
        root.setHover(hit ? Qt.rect(hit.x, hit.y, hit.w, hit.h) : Qt.rect(0, 0, 0, 0), hit ? hit.name : "", hit ? hit.address : "");
    }

    function setHover(r: rect, name: string, addr: string): void {
        if (root.hoveredName === name && root.hoveredAddr === addr && root.sameRect(root.hovered, r))
            return;

        root.hovered = r;
        root.hoveredName = name;
        root.hoveredAddr = addr;
    }

    function forgetWindows(): void {
        root.snapshot = [];
        root.pointerKnown = false;
        root.refreshHover();
    }

    function snapToWindow(r: rect): void {
        let x = r.x;
        let y = r.y;
        let w = r.width;
        let h = r.height;

        if (root.locked) {
            const aspect = root.surfaceAspect;
            const t = Math.min(w / aspect, h);
            x += (w - t * aspect) / 2;
            y += (h - t) / 2;
            w = t * aspect;
            h = t;
        }

        root.proposeRegion(x, y, w, h);
    }

    property string bound: ""
    property string boundName: ""

    property int boundMisses: 0

    readonly property int trackPoll: 250

    readonly property int trackGrace: 1000

    readonly property var boundToplevel: {
        if (!root.bound)
            return null;
        const want = root.bareAddress(root.bound);
        return Hyprland.toplevels.values.find(t => root.bareAddress(t.address) === want) ?? null;
    }

    readonly property rect boundRect: {
        const tl = root.boundToplevel;
        const shown = tl ? root.buildCandidates([tl.lastIpcObject], root.monitors) : [];
        return shown.length ? Qt.rect(shown[0].x, shown[0].y, shown[0].w, shown[0].h) : Qt.rect(0, 0, 0, 0);
    }

    onBoundRectChanged: root.followBound()

    function bindWindow(addr: string, name: string): void {

        if (!addr)
            return root.unbindWindow();

        root.bound = addr;
        root.boundName = name;
        root.boundMisses = 0;
    }

    function followBound(): void {

        if (!root.bound || !root.settled)
            return;

        if (root.editing)
            return;

        const r = root.boundRect;
        if (!(r.width > 0) || !(r.height > 0))
            return;

        const wasHome = root.home;
        const was = Qt.rect(root.mapping.x, root.mapping.y, root.mapping.width, root.mapping.height);

        root.snapToWindow(r);

        if (root.home === wasHome && root.sameRect(root.mapping, was))
            return;

        root.applyRegion();
        boundSave.restart();
    }

    function pollBound(): void {
        if (!root.bound)
            return;

        if (root.boundToplevel) {
            root.boundMisses = 0;
        } else {
            root.boundMisses += 1;
            if (root.boundMisses * root.trackPoll >= root.trackGrace)
                return root.unbindWindow();
        }

        Hypr.resync();
    }

    Timer {
        id: boundPoll

        running: root.tracking
        repeat: true
        interval: root.trackPoll

        triggeredOnStart: true
        onTriggered: root.pollBound()
    }

    Timer {
        id: boundSave

        interval: 1000
        onTriggered: root.save()
    }

    function scanClients(): void {

        if (winScan.running)
            return;
        winScan.running = true;
    }

    Process {
        id: winScan

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: root.readClients(text)
        }
    }

    function readClients(text: string): void {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {

        }

        root.snapshot = Array.isArray(raw) ? raw : [];
    }

    readonly property string stateDir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string statePath: `${root.stateDir}/penmap.json`

    function save(): void {

        boundSave.stop();

        const out = {
            aspectLocked: root.locked,
            followWindow: root.following,

            boundWindow: root.bound,
            boundWindowName: root.boundName
        };

        const mon = root.mapped ? root.monitorNamed(root.home) : null;
        if (mon) {
            out.monitor = mon.name;
            out.x = Math.round(root.mapping.x - mon.x);
            out.y = Math.round(root.mapping.y - mon.y);
            out.width = Math.round(root.mapping.width);
            out.height = Math.round(root.mapping.height);
        }

        store.setText(JSON.stringify(out, null, 4) + "\n");
    }

    function absorb(data: var): void {
        if (!data || typeof data !== "object")
            return;

        if (typeof data.aspectLocked === "boolean")
            root.locked = data.aspectLocked;

        if (typeof data.followWindow === "boolean")
            root.following = data.followWindow;

        if (root.following && typeof data.boundWindow === "string" && typeof data.boundWindowName === "string" && data.boundWindow) {
            root.bound = data.boundWindow;
            root.boundName = data.boundWindowName;
        }

        const name = typeof data.monitor === "string" ? data.monitor : "";
        const nums = [data.x, data.y, data.width, data.height].map(Number);

        if (!name || nums.some(n => !isFinite(n)) || !(nums[2] > 0) || !(nums[3] > 0))
            return;

        root.stored = {
            monitor: name,
            x: nums[0],
            y: nums[1],
            width: nums[2],
            height: nums[3]
        };
    }

    function settle(): void {
        if (root.settled || !root.monitorsKnown || !root.stateKnown)
            return;
        root.settled = true;

        const s = root.stored;
        const mon = s ? root.monitorNamed(s.monitor) : null;

        if (s && mon) {
            root.mapped = true;
            root.home = mon.name;

            const w = Math.min(s.width, mon.w);
            const h = Math.min(s.height, mon.h);
            root.proposeRegion(mon.x + root.clamp(s.x, 0, mon.w - w), mon.y + root.clamp(s.y, 0, mon.h - h), s.width, s.height);

            root.applyRegion();

            root.followBound();
            return;
        }

        if (s)
            console.warn(`PenMap: the saved mapping is on "${s.monitor}", which is not connected; starting from the focused screen instead.`);

        root.defaultRegion();
    }

    FileView {
        id: store

        path: root.statePath
        printErrors: false

        onLoaded: {
            let data = null;
            try {
                data = JSON.parse(text());
            } catch (e) {

                console.warn(`PenMap: ${root.statePath} is not valid JSON; starting from the defaults and overwriting it on the next commit.`, e);
            }

            root.absorb(data);
            root.stateKnown = true;
            root.settle();
        }

        onLoadFailed: err => {

            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
            else
                console.warn(`PenMap: could not read ${root.statePath} (${err}); starting from the defaults.`);

            root.stateKnown = true;
            root.settle();
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.stateDir]
    }

    function startPad(): void {
        if (pad.running)
            return;

        const argv = ["python3", Quickshell.shellPath("scripts/pen-pad.py"), "--device-name", String(Config.values.pen.pad ?? "")];
        if (Config.values.pen.grabPad)
            argv.push("--grab");
        pad.command = argv;
        pad.running = true;
    }

    function syncPad(): void {
        if (Config.loaded && Config.values.pen.enabled === true)
            root.startPad();
        else if (pad.running)
            pad.running = false;
    }

    Connections {
        target: Config

        function onValuesChanged(): void {
            root.syncPad();
        }

        function onLoadedChanged(): void {
            root.syncPad();
        }
    }

    readonly property int chatterGuard: 150

    property var padEdgeAt: ({})

    function padSteady(code: int): bool {
        const now = Date.now();
        const last = root.padEdgeAt[code];
        root.padEdgeAt[code] = now;
        return last === undefined || now - last >= root.chatterGuard;
    }

    function padLine(line: string): void {
        const words = line.trim().split(/\s+/);
        const verb = words[0];
        if (!verb)
            return;

        if (verb === "ready") {
            root.padAlive = true;

            padLost.stop();

            root.padEdgeAt = {};
            return;
        }

        if (verb === "gone") {
            root.padAlive = false;
            root.padEdgeAt = {};

            if (root.editing)
                padLost.restart();
            return;
        }

        if (verb === "ring")
            return;

        if (verb !== "down" && verb !== "up")
            return;

        const code = parseInt(words[1], 10);
        if (!isFinite(code))
            return;

        const steady = root.padSteady(code);
        if (verb !== "down" || !steady)
            return;

        const cfg = Config.values.pen;

        if (code === cfg.toggleButton) {
            if (root.editing)
                root.commit();
            else
                root.begin();
        } else if (code === cfg.aspectButton) {

            root.toggleAspect();
        } else if (code === cfg.centreButton) {

            root.fitAndCentre();
        }
    }

    Process {
        id: pad

        stdout: SplitParser {
            onRead: line => root.padLine(line)
        }

        stderr: SplitParser {

            onRead: line => console.warn("PenMap(pad):", line)
        }

        onExited: {
            root.padAlive = false;
            root.padEdgeAt = {};

            if (root.editing)
                padLost.restart();
            padRetry.restart();
        }
    }

    Timer {
        id: padRetry

        interval: 2000
        onTriggered: root.syncPad()
    }

    Timer {
        id: padLost

        interval: 30000
        onTriggered: root.cancel()
    }

    readonly property string layoutKey: Hyprland.monitors.values.map(m => `${m.name}@${m.x},${m.y}+${m.width}x${m.height}*${m.scale}`).join("|")

    onLayoutKeyChanged: layoutSettle.restart()

    Timer {
        id: layoutSettle

        interval: 200
        onTriggered: root.scanMonitors()
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.pushAnyway = true;
            root.scanMonitors();
        }

        function onWindowClosed(addr: string): void {
            if (root.bound && root.bareAddress(addr) === root.bareAddress(root.bound))
                root.unbindWindow();
        }
    }

    Component.onCompleted: {
        root.scanMonitors();
        root.syncPad();
    }
}
