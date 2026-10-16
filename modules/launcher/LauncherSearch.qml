pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.settings
import "search.js" as Search
import "../files/marks.js" as Marks
import "../settings/catalogue.js" as Catalogue
import "../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property string query
    required property string screenName

    property string armed: ""

    signal launch(var what)
    signal leave(var what)
    signal retype(string text)

    readonly property var caps: ({
            apps: 8,
            commands: 4,
            settings: 5,
            windows: 5,
            devices: 4,
            processes: 8,
            files: 6,
            contents: 5
        })

    readonly property string text: root.query.trim()
    readonly property var path: Search.pathQuery(root.query, Files.home)
    readonly property string url: Search.urlOf(root.text)

    readonly property var timer: Search.timerAsk(root.text)
    readonly property var reminder: Search.reminderAsk(root.text)
    readonly property int volume: Search.volumeAsk(root.text)
    readonly property string place: Search.zoneAsk(root.text)
    readonly property var killing: Search.killAsk(root.text)

    readonly property bool intent: !!root.timer || !!root.reminder || root.volume >= 0 || root.zoneRows.length > 0 || root.killing !== null

    property bool started: false

    property bool quiet: false

    onQueryChanged: {
        root.armed = "";
        if (!root.query)
            root.started = false;
        else if (!root.started) {
            root.started = true;
            Files.refreshPlaces();
        }
        if (Search.zoneAsk(root.query.trim()))
            Clock.loadZoneList();
        if (Search.killAsk(root.query.trim()) !== null)
            root.listProcesses();
        if (root.quiet)
            return;
        const typed = Search.pathQuery(root.query, Files.home);
        if (typed) {
            FileSearch.list(typed.dir);
            FileSearch.grep("");
        } else {
            FileSearch.find(root.query);
            FileSearch.grep(root.query);
        }
    }

    function appScore(entry: var): real {
        const tier = Apps.tier(entry, root.text);
        return tier >= 3 ? tier - 2 : tier === 2 ? 0.5 : tier === 1 ? 0.25 : 0.1;
    }

    function wordScore(label: string, words: string): real {
        return Math.max(Ranking.place(label, root.text), Ranking.place(words, root.text) - 0.5);
    }

    readonly property string volumeText: `${Math.round(Audio.volume * 100)}%`

    readonly property var commands: [
        {
            id: "lock",
            icon: "lock",
            label: "Lock screen",
            words: "lock screen away",
            run: () => Lock.lock()
        },
        {
            id: "suspend",
            icon: "bedtime",
            label: "Suspend",
            words: "sleep suspend",
            run: () => Suspension.perform("suspend")
        },
        {
            id: "hibernate",
            icon: "mode_standby",
            label: "Hibernate",
            words: "hibernate",
            hidden: !Suspension.hibernatePossible,
            run: () => Suspension.perform("hibernate")
        },
        {
            id: "reboot",
            icon: "restart_alt",
            label: "Restart",
            words: "reboot restart",
            confirm: true,
            run: () => root.power("reboot")
        },
        {
            id: "poweroff",
            icon: "power_settings_new",
            label: "Shut down",
            words: "shut down power off turn off shutdown",
            confirm: true,
            run: () => root.power("poweroff")
        },
        {
            id: "logout",
            icon: "logout",
            label: "Log out",
            words: "log out sign out logout exit",
            confirm: true,
            run: () => root.power("logout")
        },
        {
            id: "clipboard",
            icon: "content_paste",
            label: "Clipboard history",
            words: "clipboard paste copied history",
            run: () => Shell.forScreen(root.screenName)?.clipboard.show()
        },
        {
            id: "wallpapers",
            icon: "wallpaper",
            label: "Wallpapers",
            words: "wallpaper background picture",
            run: () => Shell.forScreen(root.screenName)?.wallpapers.show()
        },
        {
            id: "settings",
            icon: "tune",
            label: "Settings",
            words: "settings preferences options",
            run: () => Settings.show(root.screenName, "")
        },
        {
            id: "playpause",
            icon: Media.playing ? "pause" : "play_arrow",
            label: Media.playing ? "Pause" : "Play",
            words: "play pause resume music media",
            hidden: !Media.available,
            run: () => Media.toggle()
        },
        {
            id: "next",
            icon: "skip_next",
            label: "Next track",
            words: "next skip track song music",
            hidden: !Media.available,
            run: () => Media.next()
        },
        {
            id: "previous",
            icon: "skip_previous",
            label: "Previous track",
            words: "previous back track song music",
            hidden: !Media.available,
            run: () => Media.previous()
        },
        {
            id: "volumeup",
            icon: "volume_up",
            label: "Volume up",
            words: "volume up louder sound",
            detail: root.volumeText,
            hidden: !Audio.ready,
            stay: true,
            run: () => Audio.setVolume(Math.min(Audio.maxVolume, Audio.volume + 0.1))
        },
        {
            id: "volumedown",
            icon: "volume_down",
            label: "Volume down",
            words: "volume down quieter softer sound",
            detail: root.volumeText,
            hidden: !Audio.ready,
            stay: true,
            run: () => Audio.setVolume(Math.max(0, Audio.volume - 0.1))
        },
        {
            id: "mute",
            icon: Audio.muted ? "volume_off" : "volume_up",
            label: "Mute sound",
            words: "mute unmute sound volume silence speakers",
            toggle: Audio.muted,
            hidden: !Audio.ready,
            stay: true,
            run: () => Audio.toggleMute()
        },
        {
            id: "micmute",
            icon: Audio.sourceMuted ? "mic_off" : "mic",
            label: "Mute microphone",
            words: "mute unmute microphone mic",
            toggle: Audio.sourceMuted,
            hidden: !Audio.source,
            stay: true,
            run: () => Audio.toggleSourceMute()
        },
        {
            id: "awake",
            icon: "coffee",
            label: "Keep awake",
            words: "keep awake caffeine coffee stay on no sleep",
            toggle: Idle.awake,
            stay: true,
            run: () => Idle.awake = !Idle.awake
        },
        {
            id: "trash",
            icon: "delete_sweep",
            label: "Empty trash",
            words: "empty trash bin rubbish",
            confirm: true,
            run: () => Quickshell.execDetached(["gio", "trash", "--empty"])
        }
    ].concat(Files.drives.map(d => ({
                id: `eject:${d.path}`,
                icon: "eject",
                label: `Eject ${d.name}`,
                words: `eject unmount drive usb disk ${d.name}`,
                detail: d.detail,
                run: () => root.eject(d.path)
            })))

    function eject(path: string): void {
        Quickshell.execDetached(["sh", "-c", 'dev=$(findmnt -no SOURCE -- "$1") && udisksctl unmount -b "$dev" && udisksctl power-off -b "$dev"', "sh", path]);
    }

    function power(key: string): void {
        const entry = Power.actions.find(a => a.key === key);
        if (entry)
            Power.run(entry);
    }

    function liveToggle(row: var): bool {
        return row.kind === "toggle" && !SettingsState.plannedKey(row.k) && !(row.dis && row.dis(SettingsState));
    }

    function appRow(entry: var): var {
        const arming = root.armed === `uninstall:${entry.id}`;
        return {
            key: `app:${entry.id}`,
            kind: "app",
            entry: entry,
            label: entry.name ?? "",
            detail: arming ? Uninstaller.detailFor(entry.id) : entry.genericName || entry.comment || "",
            armed: arming,
            iconSource: entry.icon ? Quickshell.iconPath(entry.icon, true) : "",
            icon: "apps",
            score: root.appScore(entry)
        };
    }

    readonly property var appRows: Apps.search(root.text).map(entry => root.appRow(entry))

    function commandRow(c: var): var {
        return {
            key: `command:${c.id}`,
            kind: "command",
            command: c,
            label: root.armed === c.id ? `Press Enter again to ${c.label.toLowerCase()}` : c.label,
            armed: root.armed === c.id,
            detail: c.detail ?? "",
            icon: c.icon,
            toggle: c.toggle,
            score: root.wordScore(c.label, c.words)
        };
    }

    readonly property var commandRows: root.text.length < 2 ? [] : root.commands.filter(c => !c.hidden).map(c => root.commandRow(c)).filter(r => r.score > 0).sort((a, b) => b.score - a.score)

    readonly property var volumeRows: root.volume < 0 || !Audio.ready ? [] : [
        {
            key: "command:volumeset",
            kind: "command",
            command: {
                id: "volumeset",
                label: `Set volume to ${root.volume}%`,
                stay: true,
                run: () => Audio.setVolume(Math.min(Audio.maxVolume, root.volume / 100))
            },
            label: `Set volume to ${root.volume}%`,
            detail: root.volumeText,
            icon: "volume_up",
            score: Infinity
        }
    ]

    function settingRow(hit: var): var {
        const live = root.liveToggle(hit.row);
        const group = typeof hit.group.t === "string" ? hit.group.t : "";
        return {
            key: `setting:${hit.page.id}:${hit.row.k ?? hit.label}`,
            kind: "setting",
            hit: hit,
            label: hit.label,
            detail: group ? `${hit.page.name} › ${group}` : hit.page.name,
            icon: hit.row.icon || hit.page.icon || "tune",
            toggle: live ? !!SettingsState.v(hit.row.k) : undefined,
            score: Math.max(0.5, Ranking.place(hit.label, root.text))
        };
    }

    readonly property var settingRows: root.text.length < 2 ? [] : Catalogue.search(root.text).map(hit => root.settingRow(hit))

    function rowById(id: string): var {
        const at = id.indexOf(":");
        const rest = id.slice(at + 1);
        switch (id.slice(0, at)) {
        case "app":
            {
                const entry = Apps.entryById(rest);
                return entry ? root.appRow(entry) : null;
            }
        case "command":
            {
                const c = root.commands.find(c => c.id === rest && !c.hidden);
                return c ? root.commandRow(c) : null;
            }
        case "setting":
            {
                const cut = rest.indexOf(":");
                const hit = Catalogue.hitFor(rest.slice(0, cut), rest.slice(cut + 1));
                return hit ? root.settingRow(hit) : null;
            }
        }
        return null;
    }

    function runnable(row: var): bool {
        return ["app", "command", "setting"].includes(row?.kind) && row.command?.id !== "volumeset";
    }

    function keyable(row: var): bool {
        return root.runnable(row) && !row.command?.confirm;
    }

    function nameOf(row: var): string {
        return row.kind === "command" ? row.command.label : row.kind === "app" ? row.entry.name ?? "" : row.label;
    }

    function runById(id: string): string {
        const row = root.rowById(id);
        switch (row?.kind) {
        case "app":
            Apps.launch(row.entry);
            Hypr.claimNextWindow();
            break;
        case "command":
            if (row.command.confirm)
                return "";
            row.command.run();
            break;
        case "setting":
            if (row.toggle !== undefined)
                SettingsState.set(row.hit.row.k, !row.toggle);
            else
                Settings.openAt(root.screenName, row.hit.page.id, row.hit.row.k ?? "");
            break;
        default:
            return "";
        }
        return row.kind === "app" ? row.entry.name : row.label;
    }

    readonly property string aliasId: Search.aliasTarget(Config.values.launcher.aliases, root.text)
    readonly property var aliasRow: root.aliasId ? root.rowById(root.aliasId) : null
    readonly property var aliasOf: Search.aliasesById(Config.values.launcher.aliases)

    function withAlias(kind: string, rows: var): var {
        const hit = root.aliasRow;
        if (hit?.kind !== kind)
            return rows;
        return [Object.assign({}, hit, {
                score: Infinity
            })].concat(rows.filter(r => r.key !== hit.key));
    }

    function fileRow(f: var, prefix: string): var {
        return {
            key: `${prefix}:${f.path}`,
            kind: "file",
            path: f.path,
            dir: f.dir,
            label: f.name,
            detail: Search.shortPath(f.path.slice(0, f.path.lastIndexOf("/")) || "/", Files.home),
            icon: Marks.iconFor(f.path, f.name, f.dir, Files.home) || (f.dir ? "folder" : "draft"),
            score: f.score ?? 0
        };
    }

    readonly property var fileRows: root.path || root.text.length < FileSearch.least ? [] : Search.fileRows(FileSearch.lines, root.text, Ranking.place).map(f => root.fileRow(Object.assign({}, f, {
                score: f.score - Ranking.EXACT
            }), "file"))

    readonly property var contentRows: root.path || FileSearch.grepAnswered !== root.text ? [] : FileSearch.hits.map(line => Search.contentRow(line, Files.home)).filter(hit => hit && !root.fileRows.some(f => f.path === hit.path)).map(hit => ({
                key: `content:${hit.path}`,
                kind: "file",
                path: hit.path,
                dir: false,
                label: hit.name,
                detail: `${hit.text} · ${hit.where}`,
                icon: Marks.iconFor(hit.path, hit.name, false, Files.home) || "draft",
                score: -1
            }))

    readonly property var fallbackRows: Search.fallbackRows(Config.values.launcher.fallbacks, root.text, Config.values.launcher.webSearch).map(f => ({
                key: `fallback:${f.id}`,
                kind: "fallback",
                fallback: f,
                label: f.label,
                detail: "",
                icon: f.icon,
                score: -Infinity
            }))

    readonly property var pathRows: root.path && FileSearch.listedDir === root.path.dir ? Search.pathRows(FileSearch.entries, root.path, FileSearch.hidden, Files.home).map(f => root.fileRow(f, "path")) : []

    readonly property var windowRows: root.text.length < 2 ? [] : Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) !== 0).map(t => {
        const o = t.lastIpcObject ?? {};
        const cls = o.class || o.initialClass || "";
        const app = Apps.nameFor(cls);
        const title = t.title || o.title || app;
        return {
            key: `window:${t.address}`,
            kind: "window",
            address: Hypr.windowAddress(t.address),
            label: title,
            detail: `${app} · workspace ${t.workspace?.name ?? ""}`,
            iconSource: Apps.iconSourceFor([cls]),
            icon: "web_asset",
            score: Math.max(Ranking.place(title, root.text), Ranking.place(app, root.text), Ranking.place(cls, root.text) - 0.5)
        };
    }).filter(r => r.score > 0).sort((a, b) => b.score - a.score)

    function kindScore(label: string, words: string): real {
        return Math.max(Ranking.place(label, root.text), Ranking.place(words, root.text) - 0.5);
    }

    readonly property var deviceRows: {
        if (root.text.length < 2)
            return [];
        const bluetooth = Bluetooth.enabled ? Bluetooth.known.map(d => ({
                    key: `bluetooth:${d.address}`,
                    kind: "bluetooth",
                    device: d,
                    label: d.name ?? d.address,
                    detail: Bluetooth.stateLabel(d),
                    icon: Bluetooth.icon(d),
                    toggle: !!d.connected,
                    score: root.kindScore(d.name ?? "", "bluetooth device connect")
                })) : [];
        const wifi = Network.enabled ? Network.knownNetworks.map(n => ({
                    key: `wifi:${n.name}`,
                    kind: "wifi",
                    name: n.name,
                    label: n.name,
                    detail: Network.stateLabel(n),
                    icon: "wifi",
                    toggle: !!n.connected,
                    score: root.kindScore(n.name, "wifi wi-fi network wireless join")
                })) : [];
        const outputs = Audio.sinks.map(n => ({
                    key: `output:${n.id}`,
                    kind: "output",
                    node: n,
                    label: Audio.deviceLabel(n),
                    detail: n === Audio.sink ? "in use" : "",
                    icon: Audio.deviceIcon(n),
                    score: root.kindScore(Audio.deviceLabel(n), "sound output speakers headphones audio")
                }));
        return bluetooth.concat(wifi, outputs).filter(r => r.score > 0).sort((a, b) => b.score - a.score);
    }

    property var zoneOffsets: ({})

    readonly property var zoneIds: root.place ? Search.zoneMatches(Clock.allZones, root.place, Clock.cityOf).slice(0, 3) : []

    onZoneIdsChanged: {
        const unknown = root.zoneIds.filter(id => root.zoneOffsets[id] === undefined && Clock.validZone(id));
        if (!unknown.length)
            return;
        root.offsets.running = false;
        root.offsets.command = ["sh", "-c", 'for z in "$@"; do printf "%s %s\\n" "$z" "$(TZ="$z" date +%z)"; done', "sh", ...unknown];
        root.offsets.running = true;
    }

    property Process offsets: Process {
        stdout: StdioCollector {
            onStreamFinished: root.zoneOffsets = Object.assign({}, root.zoneOffsets, Search.readOffsets(text))
        }
    }

    readonly property var zoneRows: root.zoneIds.filter(id => root.zoneOffsets[id] !== undefined).map(id => {
        const offset = root.zoneOffsets[id];
        const now = Date.now();
        const there = new Date(now + offset * 60000);
        const time = TimeFormat.clock(there.getUTCHours(), there.getUTCMinutes());
        return {
            key: `zone:${id}`,
            kind: "zone",
            zone: id,
            time: time,
            label: `${time} in ${Clock.cityOf(id)}`,
            detail: `${Qt.locale().dayName(there.getUTCDay(), Locale.LongFormat)} · ${Clock.offsetLabel(offset + new Date(now).getTimezoneOffset())}`,
            icon: "schedule",
            score: Infinity
        };
    })

    function reminderRow(ask: var): var {
        const about = ask.label ? ` to ${ask.label}` : "";
        if (ask.at) {
            const when = new Date();
            when.setHours(ask.at.hour, ask.at.minute, 0, 0);
            return {
                key: "reminder",
                kind: "reminder",
                ask: ask,
                label: `Remind me at ${TimeFormat.clock(ask.at.hour, ask.at.minute)}${about}`,
                detail: when.getTime() > Date.now() ? "today" : "tomorrow",
                icon: "notifications_active",
                score: Infinity
            };
        }
        return {
            key: "reminder",
            kind: "reminder",
            ask: ask,
            label: `Remind me in ${Search.spanText(ask.seconds)}${about}`,
            detail: TimeFormat.time(new Date(Date.now() + ask.seconds * 1000), false),
            icon: "notifications_active",
            score: Infinity
        };
    }

    readonly property var clockRows: {
        const out = [];
        if (root.timer)
            out.push({
                key: "timer",
                kind: "timer",
                ask: root.timer,
                label: `Start a ${Search.spanText(root.timer.seconds)} timer${root.timer.label ? ` for ${root.timer.label}` : ""}`,
                detail: `ends ${TimeFormat.time(new Date(Date.now() + root.timer.seconds * 1000), false)}`,
                icon: "timer",
                score: Infinity
            });
        if (root.reminder)
            out.push(root.reminderRow(root.reminder));
        return out.concat(root.zoneRows);
    }

    property var processes: []

    readonly property var sessionProcesses: ["ps", "sh", "quickshell", "qs", "Hyprland", "systemd", "(sd-pam)", "dbus-broker", "dbus-broker-lau", "dbus-daemon", "pipewire", "pipewire-pulse", "wireplumber"]

    function listProcesses(): void {
        root.lister.running = false;
        root.lister.running = true;
    }

    property Process lister: Process {
        command: ["sh", "-c", 'ps -u "$(id -u)" -o pid=,rss=,comm= --sort=-rss']
        stdout: StdioCollector {
            onStreamFinished: root.processes = Search.readProcesses(text, root.sessionProcesses)
        }
    }

    property Timer relist: Timer {
        interval: 400
        onTriggered: root.listProcesses()
    }

    function memoryText(kb: real): string {
        return kb >= 1048576 ? `${(kb / 1048576).toLocaleString(Qt.locale(), "f", 1)} GB` : `${Math.max(1, Math.round(kb / 1024))} MB`;
    }

    readonly property var processRows: root.killing === null ? [] : root.processes.filter(p => p.name.toLowerCase().indexOf(root.killing) >= 0).map(p => ({
                key: `process:${p.pid}`,
                kind: "process",
                pid: p.pid,
                label: p.name,
                detail: `${root.memoryText(p.kb)} · PID ${p.pid}`,
                iconSource: Apps.iconSourceFor([p.name]),
                icon: "memory",
                score: Infinity
            }))

    function kill(pid: int, signal: string): void {
        Quickshell.execDetached(["kill", `-${signal}`, String(pid)]);
        root.relist.restart();
    }

    readonly property var rows: root.keyed(root.arranged)

    function keyed(rows: var): var {
        return rows.map(r => {
            if (r.header)
                return r;
            const alias = root.runnable(r) ? root.aliasOf[r.key] ?? "" : "";
            const hotkey = root.keyable(r) ? LauncherHotkeys.chordOf(r.key) : "";
            return Object.assign({}, r, {
                id: r.key,
                alias: alias,
                hotkey: hotkey,
                key: `${r.key}|${r.label}|${r.toggle}|${r.detail}|${alias}|${hotkey}`
            });
        });
    }

    readonly property var arranged: {
        if (!root.text)
            return root.appRows;
        if (root.path)
            return root.pathRows;
        const groups = [];
        if (root.url)
            groups.push({
                key: "link",
                title: "Link",
                items: [
                    {
                        key: `link:${root.url}`,
                        kind: "link",
                        label: `Open ${root.text}`,
                        detail: "",
                        icon: "link",
                        score: Infinity
                    }
                ]
            });
        groups.push({
            key: "clock",
            title: "Clock",
            items: root.clockRows
        }, {
            key: "processes",
            title: "Processes",
            items: root.processRows
        }, {
            key: "apps",
            title: "Apps",
            items: root.withAlias("app", root.appRows)
        }, {
            key: "commands",
            title: "Commands",
            items: root.withAlias("command", root.volumeRows.concat(root.commandRows))
        }, {
            key: "settings",
            title: "Settings",
            items: root.withAlias("setting", root.settingRows)
        }, {
            key: "windows",
            title: "Windows",
            items: root.windowRows
        }, {
            key: "devices",
            title: "Devices",
            items: root.deviceRows
        }, {
            key: "files",
            title: "Files",
            items: root.fileRows
        }, {
            key: "contents",
            title: "Inside files",
            items: root.contentRows
        }, {
            key: "fallbacks",
            title: "Elsewhere",
            items: root.fallbackRows
        });
        return Search.arrange(groups, root.caps);
    }

    function openSetting(row: var): void {
        const hit = row.hit;
        root.leave(() => Settings.openAt(root.screenName, hit.page.id, hit.row.k ?? ""));
    }

    function activate(row: var): void {
        switch (row?.kind) {
        case "app":
            if (root.armed === `uninstall:${row.entry.id}`) {
                const entry = row.entry;
                if (Uninstaller.ready(entry.id))
                    root.leave(() => Uninstaller.remove(entry));
                return;
            }
            root.launch(() => Apps.launch(row.entry));
            return;
        case "command":
            if (row.command.confirm && root.armed !== row.command.id) {
                root.armed = row.command.id;
                return;
            }
            if (row.command.stay)
                row.command.run();
            else
                root.leave(row.command.run);
            return;
        case "window":
            root.leave(() => Hypr.focusAddress(row.address));
            return;
        case "bluetooth":
            Bluetooth.toggleDevice(row.device);
            return;
        case "wifi":
            {
                const n = Network.find(row.name);
                if (n?.connected)
                    n.disconnect();
                else if (n)
                    n.connect();
            }
            return;
        case "output":
            Audio.setSink(row.node);
            return;
        case "timer":
            root.leave(() => Clock.startTimer(row.ask.seconds, row.ask.label));
            return;
        case "reminder":
            root.leave(() => root.remind(row.ask));
            return;
        case "zone":
            root.leave(() => Files.copyText(row.time));
            return;
        case "process":
            root.kill(row.pid, "TERM");
            return;
        case "setting":
            if (row.toggle !== undefined)
                SettingsState.set(row.hit.row.k, !row.toggle);
            else
                root.openSetting(row);
            return;
        case "file":
            if (row.dir && root.path)
                root.retype(`${Search.shortPath(row.path, Files.home)}/`);
            else if (row.dir)
                root.leave(() => Files.show(row.path));
            else
                root.launch(() => Files.openWith(row.path));
            return;
        case "link":
            root.launch(() => Quickshell.execDetached(["xdg-open", root.url]));
            return;
        case "fallback":
            if (row.fallback.url) {
                const url = row.fallback.url;
                root.launch(() => Quickshell.execDetached(["xdg-open", url]));
            } else {
                const typed = root.text.replace(/'/g, "'\\''");
                root.launch(() => Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `(eval '${typed}')\nexec "\${SHELL:-sh}"`]));
            }
            return;
        }
    }

    function windowsOf(entry: var): var {
        return Hyprland.toplevels.values.filter(t => {
            const o = t.lastIpcObject ?? {};
            return (t.workspace?.id ?? 0) !== 0 && Apps.entryFor(o.class || o.initialClass || "")?.id === entry.id;
        });
    }

    function appActions(entry: var): var {
        const open = root.windowsOf(entry);
        if (!open.length)
            return [];
        return [
            {
                icon: "close",
                label: open.length > 1 ? `Quit · ${open.length} windows` : "Quit",
                short: "Quit",
                run: () => open.forEach(t => Hypr.closeWindow(Hypr.windowAddress(t.address)))
            },
            {
                icon: "dangerous",
                label: "Force quit",
                tucked: true,
                run: () => root.forceQuit(open)
            }
        ];
    }

    function forceQuit(open: var): void {
        const pids = [...new Set(open.map(t => t.lastIpcObject?.pid).filter(pid => pid > 0))];
        if (pids.length)
            Quickshell.execDetached(["kill", "-KILL", ...pids.map(String)]);
    }

    function confirmActions(row: var): var {
        const cancel = {
            icon: "close",
            label: "Cancel",
            run: () => root.armed = ""
        };
        if (row.kind === "app")
            return Uninstaller.plans[row.entry.id]?.refused ? [cancel] : [
                {
                    icon: "delete",
                    label: "Uninstall",
                    alarm: true,
                    run: () => root.activate(row)
                },
                cancel
            ];
        return [cancel];
    }

    function armUninstall(entry: var): void {
        root.armed = `uninstall:${entry.id}`;
        Uninstaller.plan(entry);
    }

    function remind(ask: var): void {
        if (!ask.at) {
            Clock.startTimer(ask.seconds, ask.label || "Reminder");
            return;
        }
        const id = Clock.addAlarm();
        if (id)
            Clock.setAlarm(id, {
                hour: ask.at.hour,
                minute: ask.at.minute,
                days: [],
                label: ask.label || "Reminder"
            });
    }

    function complete(row: var): bool {
        if (row?.kind !== "file")
            return false;
        root.retype(`${Search.shortPath(row.path, Files.home)}${row.dir ? "/" : ""}`);
        return true;
    }

    function actionsFor(row: var): var {
        switch (row?.kind) {
        case "file":
            return [
                {
                    icon: row.dir ? "folder_open" : "open_in_new",
                    label: "Open",
                    run: () => row.dir ? root.leave(() => Files.show(row.path)) : root.launch(() => Files.openWith(row.path))
                },
                {
                    icon: "drive_file_move",
                    label: "Show in folder",
                    run: () => root.leave(() => Files.reveal(row.path))
                },
                {
                    icon: "content_copy",
                    label: "Copy path",
                    run: () => root.leave(() => Files.copyText(row.path))
                }
            ];
        case "setting":
            return row.toggle === undefined ? [
                {
                    icon: "tune",
                    label: "Open in settings",
                    run: () => root.openSetting(row)
                }
            ] : [
                {
                    icon: row.toggle ? "toggle_off" : "toggle_on",
                    label: row.toggle ? "Turn off" : "Turn on",
                    run: () => root.activate(row)
                },
                {
                    icon: "tune",
                    label: "Open in settings",
                    run: () => root.openSetting(row)
                }
            ];
        case "link":
            return [
                {
                    icon: "link",
                    label: "Open",
                    run: () => root.activate(row)
                },
                {
                    icon: "content_copy",
                    label: "Copy link",
                    run: () => root.leave(() => Files.copyText(root.url))
                }
            ];
        case "window":
            return [
                {
                    icon: "open_in_new",
                    label: "Switch to",
                    run: () => root.activate(row)
                },
                {
                    icon: "close",
                    label: "Close",
                    run: () => Hypr.closeWindow(row.address)
                }
            ];
        case "process":
            return [
                {
                    icon: "close",
                    label: "Quit",
                    run: () => root.kill(row.pid, "TERM")
                },
                {
                    icon: "dangerous",
                    label: "Force quit",
                    run: () => root.kill(row.pid, "KILL")
                }
            ];
        case "zone":
            return [
                {
                    icon: "content_copy",
                    label: "Copy time",
                    run: () => root.activate(row)
                }
            ].concat(Clock.places.includes(row.zone) || row.zone === Clock.localZone ? [] : [
                    {
                        icon: "add",
                        label: "Add to world clock",
                        short: "Add",
                        run: () => Clock.addZone(row.zone)
                    }
                ]);
        case "bluetooth":
        case "wifi":
            return [
                {
                    icon: row.icon,
                    label: row.toggle ? "Disconnect" : "Connect",
                    run: () => root.activate(row)
                }
            ];
        case "output":
        case "timer":
        case "reminder":
        case "command":
        case "fallback":
            return [
                {
                    icon: row.icon,
                    label: row.kind === "command" ? row.command.label : row.label,
                    run: () => root.activate(row)
                }
            ];
        }
        return [];
    }
}
