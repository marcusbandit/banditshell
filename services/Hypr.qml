pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property int activeId: {
        const focused = Hyprland.focusedWorkspace?.id ?? 1;
        if (focused > 0)
            return focused;
        return Hyprland.focusedMonitor?.activeWorkspace?.id ?? 1;
    }

    readonly property int count: Config.values.sidebar.workspaces.persistent

    readonly property var bands: HyprConfig.hostBands

    function bandFor(screen: string): int {
        const b = root.bands.find(x => x.monitor === screen && !x.invalid);
        if (b)
            return b.first;
        let last = 0;
        for (const b of root.bands)
            if (!b.invalid)
                last = Math.max(last, b.last);
        return last + 1;
    }

    readonly property var activeByMonitor: {
        const out = {};
        for (const mon of Hyprland.monitors.values) {
            const live = mon.activeWorkspace?.id ?? 0;
            out[mon.name] = live > 0 ? live : (mon.lastIpcObject?.activeWorkspace?.id ?? 0);
        }
        return out;
    }

    function activeOn(screen: string): int {
        return root.activeByMonitor[screen] || root.bandFor(screen);
    }

    readonly property bool settled: HyprConfig.ready && Config.loaded

    onSettledChanged: root.home()

    readonly property int known: Hyprland.workspaces.values.length
    property bool homed: false

    onKnownChanged: root.home()
    onParserKnownChanged: root.home()
    Component.onCompleted: root.home()

    function home(): void {
        if (root.homed || root.known === 0 || !root.parserKnown || !root.settled)
            return;
        root.homed = true;
        const band = root.bandFor(root.focusedScreen);
        if (root.activeId < band || root.activeId >= band + root.count)
            root.switchTo(band);
    }

    readonly property var clients: {
        const out = {};
        for (const c of Hyprland.toplevels.values) {
            const id = c.workspace?.id ?? 0;
            if (id !== 0) {
                if (!out[id])
                    out[id] = [];
                out[id].push(c);
            }
        }
        for (const id in out)
            out[id].sort((a, b) => {
                const x = a.lastIpcObject?.at ?? [0, 0];
                const y = b.lastIpcObject?.at ?? [0, 0];
                return (x[0] - y[0]) || (x[1] - y[1]);
            });
        return out;
    }

    function clientsIn(id: int): var {
        return root.clients[id] ?? [];
    }

    function resync(): void {
        Hyprland.refreshToplevels();
    }

    readonly property var specials: {
        const out = [];
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id >= 0)
                continue;
            const name = ws.lastIpcObject?.name ?? "";
            out.push({
                id: ws.id,
                name,
                label: name.startsWith("special:") ? name.slice(8) : name,
                windows: root.clients[ws.id] ?? []
            });
        }
        return out;
    }

    readonly property var specialDeck: {
        if (!Config.values.sidebar.workspaces.rack)
            return [];
        const want = Config.values.sidebar.workspaces.specials;
        const live = root.specials;
        const out = [];
        for (const name of want)
            out.push(live.find(s => s.label === name) ?? ({
                        id: 0,
                        name: `special:${name}`,
                        label: name,
                        windows: []
                    }));
        for (const s of live.slice().sort((a, b) => a.label.localeCompare(b.label)))
            if (want.indexOf(s.label) < 0)
                out.push(s);
        return out;
    }

    property var specialByMonitor: ({})

    function specialOn(screen: string): string {
        return root.specialByMonitor[screen] ?? "";
    }

    function noteSpecial(monitor: string, name: string): void {
        const next = Object.assign({}, root.specialByMonitor);
        next[monitor] = name;
        root.specialByMonitor = next;
    }

    Process {
        running: true
        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                let mons = [];
                try {
                    mons = JSON.parse(text);
                } catch (e) {}
                const next = Object.assign({}, root.specialByMonitor);
                for (const m of mons)
                    if (m.name && !(m.name in next))
                        next[m.name] = m.specialWorkspace?.name ?? "";
                root.specialByMonitor = next;
            }
        }
    }

    function send(lua: string, legacy: string): void {
        Hyprland.dispatch(root.lua ? lua : legacy);
    }

    property bool lua: false

    property bool parserKnown: false

    Process {
        running: true
        command: ["hyprctl", "dispatch", "hl.dsp.no_op()"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.lua = text.trim() === "ok";
                root.parserKnown = true;
            }
        }
    }

    function toggleSpecial(name: string): void {
        const bare = name.startsWith("special:") ? name.slice(8) : name;
        root.send(`hl.dsp.workspace.toggle_special("${bare}")`, `togglespecialworkspace ${bare}`);
    }

    readonly property var activeClient: Hyprland.activeToplevel

    function windowAddress(raw: var): string {
        const bare = String(raw ?? "").trim().toLowerCase().replace(/^0x/, "");
        return /^[0-9a-f]+$/.test(bare) ? `0x${bare}` : "";
    }

    function toplevelFor(addr: string): var {
        const want = root.windowAddress(addr);
        if (!want)
            return null;
        return Hyprland.toplevels.values.find(t => root.windowAddress(t.address) === want) ?? null;
    }

    function isFocused(client: var): bool {
        const addr = root.windowAddress(client?.lastIpcObject?.address);
        if (!addr)
            return false;
        return root.focusedAddress ? root.focusedAddress === addr : root.activeClient === client;
    }

    function classOf(client: var): string {
        const o = client?.lastIpcObject;
        return o?.class || o?.initialClass || "";
    }

    function stackClients(clients: var): var {
        const out = [];
        for (const client of clients) {
            const cls = root.classOf(client);
            const held = out.find(m => m.cls === cls);
            if (held)
                held.count++;
            else
                out.push({
                    client,
                    cls,
                    count: 1
                });
        }
        return out;
    }

    function focusClient(client: var): void {
        root.focusAddress(client?.lastIpcObject?.address ?? "");
    }

    function focusAddress(addr: string): void {
        if (addr)
            root.send(`hl.dsp.focus({ window = "address:${addr}" })`, `focuswindow address:${addr}`);
    }

    function restoreFocus(addr: string): void {
        if (addr && root.onScreen(addr))
            root.send(`(function() local p = hl.get_cursor_pos() hl.dispatch(hl.dsp.focus({ window = "address:${addr}" })) return hl.dsp.cursor.move({ x = p.x, y = p.y }) end)()`, `focuswindow address:${addr}`);
    }

    function monitorOf(addr: string): string {
        const id = root.toplevelFor(addr)?.workspace?.id ?? 0;
        if (id === 0)
            return "";
        const shown = Hyprland.monitors.values.find(mon => {
            const special = mon.lastIpcObject?.specialWorkspace;
            return mon.activeWorkspace?.id === id || (!!special?.name && special.id === id);
        });
        return shown?.name ?? "";
    }

    function onScreen(addr: string): bool {
        return root.monitorOf(addr) !== "";
    }

    function fullscreenWindow(addr: string, mode: string): void {
        const w = root.windowAddress(addr);
        if (w)
            root.send(`hl.dsp.window.fullscreen({ mode = "${mode}", action = "toggle", window = "address:${w}" })`, `fullscreen ${mode === "maximized" ? 1 : 0}`);
    }

    function restoreWindow(addr: string): void {
        const w = root.windowAddress(addr);
        if (!w)
            return;
        if (root.lua) {
            Hyprland.dispatch(`(function() hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = "address:${w}" })) return hl.dsp.window.float({ action = "off", window = "address:${w}" }) end)()`);
            return;
        }
        Hyprland.dispatch("fullscreenstate 0 0");
        Hyprland.dispatch(`settiled address:${w}`);
    }

    function floatWindow(addr: string): void {
        const w = root.windowAddress(addr);
        if (w)
            root.send(`hl.dsp.window.float({ action = "toggle", window = "address:${w}" })`, `togglefloating address:${w}`);
    }

    function centerWindow(addr: string): void {
        const w = root.windowAddress(addr);
        if (!w)
            return;
        if (root.lua) {
            Hyprland.dispatch(`(function() hl.dispatch(hl.dsp.window.float({ action = "on", window = "address:${w}" })) return hl.dsp.window.center({ window = "address:${w}" }) end)()`);
            return;
        }
        Hyprland.dispatch(`setfloating address:${w}`);
        Hyprland.dispatch("centerwindow");
    }

    function placeWindow(addr: string, rect: var): void {
        const w = root.windowAddress(addr);
        if (!w || !rect)
            return;
        if (root.lua) {
            const on = `window = "address:${w}"`;
            Hyprland.dispatch(`(function() hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", ${on} })) hl.dispatch(hl.dsp.window.float({ action = "on", ${on} })) hl.dispatch(hl.dsp.window.resize({ x = ${rect.w}, y = ${rect.h}, ${on} })) return hl.dsp.window.move({ x = ${rect.x}, y = ${rect.y}, ${on} }) end)()`);
            return;
        }
        Hyprland.dispatch("fullscreenstate 0 0");
        Hyprland.dispatch(`setfloating address:${w}`);
        Hyprland.dispatch(`resizewindowpixel exact ${rect.w} ${rect.h},address:${w}`);
        Hyprland.dispatch(`movewindowpixel exact ${rect.x} ${rect.y},address:${w}`);
    }

    function moveToMonitor(addr: string, which: string): void {
        const w = root.windowAddress(addr);
        if (w)
            root.send(`hl.dsp.window.move({ monitor = "${which}", window = "address:${w}" })`, `movewindow mon:${which},address:${w}`);
    }

    function moveToWorkspace(addr: string, which: string): void {
        const w = root.windowAddress(addr);
        if (w)
            root.send(`hl.dsp.window.move({ workspace = "${which}", window = "address:${w}" })`, `movetoworkspace ${which},address:${w}`);
    }

    function closeWindow(addr: string): void {
        if (addr)
            root.send(`hl.dsp.window.close({ window = "address:${addr}" })`, `closewindow address:${addr}`);
    }

    function sendToWorkspace(addr: string, target: var, follow: bool): void {
        if (!addr)
            return;

        const ws = typeof target === "number" ? `${target}` : `"${target}"`;

        if (follow) {
            root.send(`hl.dsp.window.move({ window = "address:${addr}", workspace = ${ws} })`, `movetoworkspace ${target},address:${addr}`);
            return;
        }

        root.send(`(function() local w = hl.get_active_workspace() hl.dispatch(hl.dsp.window.move({ window = "address:${addr}", workspace = ${ws} })) return hl.dsp.focus({ workspace = w }) end)()`, `movetoworkspacesilent ${target},address:${addr}`);
    }

    function swapWith(addr: string, other: string): void {
        if (!addr || !other || addr === other)
            return;

        if (!root.lua) {
            console.warn("Hypr: swapping two windows by address needs Hyprland's Lua dispatcher; the old parser's swapwindow only takes a direction.");
            return;
        }

        Hyprland.dispatch(`hl.dsp.window.swap({ window = "address:${addr}", with = "address:${other}" })`);
    }

    function walkColumn(addr: string, steps: int): void {
        if (!addr || steps === 0)
            return;

        if (!root.lua) {
            console.warn("Hypr: walking a column needs Hyprland's Lua dispatcher; the old parser cannot compose the focus around it.");
            return;
        }

        const dir = steps < 0 ? "l" : "r";
        let walk = "";
        for (let i = 0; i < Math.abs(steps); i++)
            walk += `hl.dispatch(hl.dsp.layout("swapcol ${dir}")) `;

        Hyprland.dispatch(`(function() local p = hl.get_cursor_pos() local w = hl.get_active_window() hl.dispatch(hl.dsp.focus({ window = "address:${addr}" })) ${walk}if w then hl.dispatch(hl.dsp.focus({ window = w })) end return hl.dsp.cursor.move({ x = p.x, y = p.y }) end)()`);
    }

    property var claims: []

    function claimNextWindow(): void {
        root.claims = [...root.claims, Date.now() + Config.values.launcher.claimMs];
        claim.restart();
    }

    function takeClaim(): bool {
        const live = root.claims.filter(until => until > Date.now());
        if (!live.length) {
            if (root.claims.length)
                root.claims = live;
            return false;
        }
        root.claims = live.slice(1);
        return true;
    }

    Timer {
        id: claim

        interval: Config.values.launcher.claimMs
        onTriggered: root.claims = []
    }

    property string focusedAddress: ""

    property var focusedByMonitor: ({})

    function focusedOn(screen: string): string {
        return root.focusedByMonitor[screen || root.focusedScreen] ?? "";
    }

    function noteFocus(monitor: string, addr: string): void {
        if (!monitor)
            return;
        const next = Object.assign({}, root.focusedByMonitor);
        next[monitor] = addr;
        root.focusedByMonitor = next;
    }

    function forgetFocus(addr: string): void {
        const next = {};
        let held = false;
        for (const mon in root.focusedByMonitor) {
            const was = root.focusedByMonitor[mon];
            held = held || was === addr;
            next[mon] = was === addr ? "" : was;
        }
        if (held)
            root.focusedByMonitor = next;
    }

    function clientsOn(screen: var): var {
        const mon = Hyprland.monitorFor(screen);
        if (!mon)
            return [];
        const special = mon.lastIpcObject?.specialWorkspace;
        const workspaceId = special?.name ? special.id : mon.activeWorkspace?.id;
        return Hyprland.toplevels.values.filter(c => c.workspace?.id === workspaceId).sort((a, b) => {
            const x = a.lastIpcObject;
            const y = b.lastIpcObject;
            return (y.pinned - x.pinned) || ((y.fullscreen !== 0) - (x.fullscreen !== 0)) || (y.floating - x.floating);
        });
    }

    readonly property var occupancy: {
        const out = {};
        for (const mon of Hyprland.monitors.values) {
            const special = mon.lastIpcObject?.specialWorkspace;
            const id = special?.name ? special.id : mon.activeWorkspace?.id;
            out[mon.name] = id === undefined ? 0 : Hyprland.toplevels.values.filter(c => c.workspace?.id === id).length;
        }
        return out;
    }

    function windowsOn(screen: string): int {
        return root.occupancy[screen] ?? 0;
    }

    function switchTo(id: int): void {
        root.send(`hl.dsp.focus({ workspace = ${id} })`, `workspace ${id}`);
    }

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? ""

    readonly property string requestSocket: Hyprland.requestSocketPath

    signal windowOpened(addr: string, title: string, cls: string)

    signal windowClosed(addr: string)

    signal configReloaded

    readonly property var refreshes: ({
            openwindow: ["toplevels"],
            closewindow: ["toplevels"],
            movewindow: ["toplevels"],
            changefloatingmode: ["toplevels"],
            fullscreen: ["toplevels"],
            pin: ["toplevels"],
            minimized: ["toplevels"],
            togglegroup: ["toplevels"],
            moveintogroup: ["toplevels"],
            moveoutofgroup: ["toplevels"],
            activewindow: ["toplevels"],
            workspace: ["workspaces", "monitors", "toplevels"],
            focusedmon: ["monitors"],
            createworkspace: ["workspaces", "monitors"],
            destroyworkspace: ["workspaces", "monitors"],
            renameworkspace: ["workspaces"],
            activespecial: ["workspaces", "monitors", "toplevels"],
            moveworkspace: ["workspaces", "monitors", "toplevels"],
            monitoradded: ["workspaces", "monitors", "toplevels"],
            monitorremoved: ["workspaces", "monitors", "toplevels"]
        })

    property var owed: ({})

    function owe(event: string): void {
        const wanted = root.refreshes[event.replace(/v2$/, "")];
        if (!wanted)
            return;
        const next = Object.assign({}, root.owed);
        for (const kind of wanted)
            next[kind] = true;
        root.owed = next;
        if (!coalesce.running)
            coalesce.start();
    }

    Timer {
        id: coalesce

        interval: 30
        onTriggered: {
            const due = root.owed;
            root.owed = {};
            if (due.workspaces)
                Hyprland.refreshWorkspaces();
            if (due.monitors)
                Hyprland.refreshMonitors();
            if (due.toplevels)
                Hyprland.refreshToplevels();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            const n = event.name;

            if (n === "openwindow") {
                const parts = (event.data ?? "").split(",");
                const addr = root.windowAddress(parts[0]);

                if (addr)
                    root.windowOpened(addr, parts.slice(3).join(","), parts[2] ?? "");

                if (addr && root.takeClaim())
                    root.focusAddress(addr);
            }

            if (n === "closewindow") {
                const gone = root.windowAddress(event.data);
                if (gone) {
                    if (root.focusedAddress === gone)
                        root.focusedAddress = "";
                    root.forgetFocus(gone);

                    root.windowClosed(gone);
                }
            }

            if (n === "configreloaded")
                root.configReloaded();

            if (n === "activewindowv2") {
                const now = root.windowAddress(event.data);
                if (now) {
                    root.focusedAddress = now;
                    root.noteFocus(root.monitorOf(now) || root.focusedScreen, now);
                }
            }

            if (n === "activespecial") {
                const data = event.data ?? "";
                const cut = data.lastIndexOf(",");
                const monitor = cut >= 0 ? data.slice(cut + 1) : root.focusedScreen;
                const name = cut >= 0 ? data.slice(0, cut) : data;
                root.noteSpecial(monitor, name);
            }

            root.owe(n);
        }
    }
}
