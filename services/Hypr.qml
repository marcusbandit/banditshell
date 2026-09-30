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

    readonly property int count: Appearance.sizes.wsPersistent

    readonly property var bands: HyprConfig.bands.filter(b => !b.dynamic && b.path?.[1] === HyprConfig.hostName)

    readonly property var order: {
        const banded = root.bands.filter(b => !b.invalid).sort((a, b) => a.first - b.first).map(b => b.monitor);
        const out = banded.slice();
        for (const s of Quickshell.screens)
            if (out.indexOf(s.name) < 0)
                out.push(s.name);
        return out;
    }

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

    readonly property string specialShown: root.specialByMonitor[root.focusedScreen] ?? ""

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

    function isFocused(client: var): bool {
        const addr = client?.lastIpcObject?.address ?? "";
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
        const bare = (addr.startsWith("0x") ? addr.slice(2) : addr).toLowerCase();
        const client = Hyprland.toplevels.values.find(t => (t.address ?? "").toLowerCase() === bare);
        const id = client?.workspace?.id ?? 0;
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
        const wsId = special?.name ? special.id : mon.activeWorkspace?.id;
        return Hyprland.toplevels.values.filter(c => c.workspace?.id === wsId).sort((a, b) => {
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

    signal windowOpened(addr: string, title: string, cls: string)

    signal windowClosed(addr: string)

    signal configReloaded

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            const n = event.name;

            if (n === "openwindow") {

                const parts = (event.data ?? "").split(",");
                const raw = parts[0] ?? "";
                const addr = raw && !raw.startsWith("0x") ? `0x${raw}` : raw;

                if (addr)
                    root.windowOpened(addr, parts.slice(3).join(","), parts[2] ?? "");

                if (addr && root.takeClaim())
                    root.focusAddress(addr);
            }

            if (n === "closewindow") {
                const raw = (event.data ?? "").trim();
                if (raw) {
                    const gone = raw.startsWith("0x") ? raw : `0x${raw}`;

                    if (root.focusedAddress === gone)
                        root.focusedAddress = "";
                    root.forgetFocus(gone);

                    root.windowClosed(gone);
                }
            }

            if (n === "configreloaded") {
                root.configReloaded();

            }

            if (n === "activewindowv2") {
                const addr = (event.data ?? "").trim();
                if (addr && addr !== ",") {
                    const now = addr.startsWith("0x") ? addr : `0x${addr}`;
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

            if (n.includes("workspace") || n.includes("window") || n.includes("mon") || n.includes("special")) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshToplevels();

                Hyprland.refreshMonitors();
            }
        }
    }
}
