pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.settings
import qs.modules.launcher.sources
import "search.js" as Search
import "shellcli.js" as ShellCli
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

    readonly property list<QtObject> sources: [
        FallbackSource {
            search: root
        },
        SoundSource {
            search: root
        },
        MediaSource {
            search: root
        },
        EmojiSource {
            search: root
        },
        SnippetSource {
            search: root
        },
        QuicklinkSource {
            search: root
        },
        ClipboardSource {
            search: root
        }
    ]

    readonly property var sourceGroups: root.sources.reduce((out, s) => out.concat(s.groups ?? []), [])

    readonly property var sourceCommands: root.sources.reduce((out, s) => out.concat(s.commands ?? []), [])

    readonly property bool sourceIntent: root.sources.some(s => !!s.intent)

    readonly property var limits: root.sources.reduce((out, s) => Object.assign(out, s.caps ?? {}), Object.assign({}, root.caps))

    function sourceOf(row: var): var {
        return row?.kind ? root.sources.find(s => (s.kinds ?? []).includes(row.kind)) ?? null : null;
    }

    readonly property var caps: ({
            apps: 8,
            commands: 6,
            settings: 5,
            windows: root.windowList ? 24 : 5,
            devices: 4,
            processes: 8,
            shell: 12,
            output: 12,
            suggestions: 6,
            sound: 5,
            files: 6,
            contents: 5
        })

    readonly property string text: root.query.trim()
    readonly property var path: Search.pathQuery(root.query, Files.home)
    readonly property string url: Search.urlOf(root.text)

    readonly property var timer: Search.timerAsk(root.text)
    readonly property var reminder: Search.reminderAsk(root.text)
    readonly property string place: Search.zoneAsk(root.text)
    readonly property var convert: Search.zoneConvertAsk(root.text)
    readonly property var killing: Search.killAsk(root.text)

    readonly property bool intent: root.sourceIntent || root.cliLine !== null || !!root.timer || !!root.reminder || root.zoneRows.length > 0 || root.convertRows.length > 0 || root.killing !== null || root.awakeFor > 0 || root.workspaceRows.length > 0 || root.windowList

    property bool started: false

    property bool quiet: false

    property string target: ""

    onQueryChanged: {
        root.armed = "";
        if (!root.query)
            root.started = false;
        else if (!root.started) {
            root.started = true;
            Files.refreshPlaces();
            Hyprland.refreshToplevels();
        }
        if (Search.zoneAsk(root.query.trim()) || Search.zoneConvertAsk(root.query.trim()))
            Clock.loadZoneList();
        if (Search.killAsk(root.query.trim()) !== null)
            root.listProcesses();
        if (root.quiet || ShellCli.ask(root.query) !== null)
            return;
        const typed = Search.pathQuery(root.query, Files.home);
        if (typed)
            FileSearch.list(typed.dir);
        else
            FileSearch.find(root.query);
    }

    readonly property string grepFor: root.quiet || root.path || root.intent || root.aliasId || root.text.length < 4 || !/[a-z].*[a-z].*[a-z]/i.test(root.text) || Calculator.answerFor(root.text) ? "" : root.text

    onGrepForChanged: FileSearch.grep(root.grepFor)

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
            id: "restartshell",
            icon: "refresh",
            label: "Restart shell",
            words: "restart shell reload banditshell",
            run: () => Quickshell.execDetached([root.cli, "restart"])
        },
        {
            id: "reboot",
            icon: "restart_alt",
            label: "Restart computer",
            words: "reboot restart computer",
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
            detail: Idle.awake && Idle.awakeUntil ? `until ${TimeFormat.time(new Date(Idle.awakeUntil), false)}` : "",
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
        },
        {
            id: "nightlight",
            icon: "nightlight",
            label: "Night light",
            words: "night light warm screen warmth blue light filter",
            detail: Display.warm ? `${Display.kelvin} K` : "",
            toggle: Display.warm,
            stay: true,
            run: () => Display.toggleWarm()
        },
        {
            id: "darkmode",
            icon: "dark_mode",
            label: "Dark mode",
            words: "dark mode light mode appearance colour color scheme apps",
            toggle: DarkMode.dark,
            hidden: !DarkMode.available,
            stay: true,
            run: () => DarkMode.set(!DarkMode.dark)
        },
        {
            id: "sleepdisplays",
            icon: "desktop_access_disabled",
            label: "Sleep displays",
            words: "sleep displays screens off monitors off blank dpms",
            run: () => Idle.sleepScreens()
        },
        {
            id: "energysaver",
            icon: "eco",
            label: "Energy saver",
            words: "energy saver power saver battery saver low power eco",
            toggle: PowerProfile.profile === "saver",
            hidden: !PowerProfile.choices.includes("saver"),
            stay: true,
            run: () => PowerProfile.set(PowerProfile.profile === "saver" ? "balanced" : "saver")
        },
        {
            id: "performance",
            icon: "speed",
            label: "Performance mode",
            words: "performance mode fast power high power",
            toggle: PowerProfile.profile === "fast",
            hidden: !PowerProfile.choices.includes("fast"),
            stay: true,
            run: () => PowerProfile.set(PowerProfile.profile === "fast" ? "balanced" : "fast")
        },
        {
            id: "airplane",
            icon: "flight",
            label: "Airplane mode",
            words: "airplane mode aeroplane flight mode radios off wifi bluetooth",
            toggle: root.airplane,
            stay: true,
            run: () => root.setAirplane(!root.airplane)
        },
        {
            id: "quitall",
            icon: "cancel_presentation",
            label: "Quit all apps",
            words: "quit all apps close all windows",
            detail: root.openWindows.length === 1 ? "1 window" : `${root.openWindows.length} windows`,
            hidden: !root.openWindows.length,
            confirm: true,
            run: () => root.openWindows.forEach(t => Hypr.closeWindow(Hypr.windowAddress(t.address)))
        },
        {
            id: "dismiss",
            icon: "clear_all",
            label: "Dismiss notifications",
            words: "dismiss clear notifications",
            detail: Notifications.count === 1 ? "1 notification" : `${Notifications.count} notifications`,
            hidden: !Notifications.count,
            stay: true,
            run: () => Notifications.clear()
        }
    ].concat(root.windowCommands, root.layoutCommands, root.sourceCommands, Files.drives.map(d => ({
                id: `eject:${d.path}`,
                icon: "eject",
                label: `Eject ${d.name}`,
                words: `eject unmount drive usb disk ${d.name}`,
                detail: d.detail,
                run: () => root.eject(d.path)
            })))

    function windowTarget(): string {
        return Hypr.windowAddress(root.target || Hypr.focusedOn(root.screenName));
    }

    readonly property var targetToplevel: Hypr.toplevelFor(root.target || Hypr.focusedOn(root.screenName))
    readonly property var targetState: root.targetToplevel?.lastIpcObject ?? {}
    readonly property string targetName: root.targetState.class ? Apps.nameFor(root.targetState.class) : ""

    function snap(tile: var): void {
        const outer = Compositor.gapsOut;
        const inner = Compositor.gapsIn;
        Hypr.snapWindow(root.windowTarget(), mon => Search.cellRect(Search.usableArea(mon), outer, inner, tile));
    }

    readonly property var directions: [
        {
            short: "l",
            name: "left",
            icon: "west"
        },
        {
            short: "r",
            name: "right",
            icon: "east"
        },
        {
            short: "u",
            name: "up",
            icon: "north"
        },
        {
            short: "d",
            name: "down",
            icon: "south"
        }
    ]

    function tileIcon(tile: var): string {
        if (tile.cols * tile.rows === 2)
            return `splitscreen_${tile.id.split("-")[0]}`;
        return tile.cols === 3 && tile.rows === 1 ? "view_column" : tile.rows === 2 && tile.cols === 2 ? "grid_view" : "view_module";
    }

    readonly property var windowCommands: {
        if (!root.targetToplevel)
            return [];
        const many = Hyprland.monitors.values.length > 1;
        const named = c => Object.assign({
                detail: root.targetName
            }, c);
        const layout = WindowLayouts.current;
        const full = root.targetState.fullscreen === 2;
        const big = root.targetState.fullscreen === 1;
        const floating = !!root.targetState.floating;
        return [
            {
                id: "fullscreen",
                icon: full ? "fullscreen_exit" : "fullscreen",
                label: full ? "Exit fullscreen" : "Fullscreen",
                words: "fullscreen full screen exit fullscreen leave window",
                run: () => Hypr.fullscreenWindow(root.windowTarget(), "fullscreen")
            },
            {
                id: "maximize",
                icon: big ? "close_fullscreen" : "open_in_full",
                label: big ? "Unmaximize" : "Maximize",
                words: "maximize maximise unmaximize unmaximise window bigger",
                run: () => Hypr.fullscreenWindow(root.windowTarget(), "maximized")
            },
            {
                id: "restore",
                icon: "close_fullscreen",
                label: "Restore window",
                words: "restore window unmaximize tile tiled normal size",
                run: () => Hypr.restoreWindow(root.windowTarget())
            },
            {
                id: "float",
                icon: floating ? "grid_view" : "picture_in_picture",
                label: floating ? "Tile window" : "Float window",
                words: "float floating tile tiled unfloat window",
                lead: /^(?:un)?(?:float(?:ing)?|tile[sd]?|tiling)(?: (?:the )?window)?$/i,
                run: () => Hypr.floatWindow(root.windowTarget())
            },
            {
                id: "promote",
                icon: "vertical_align_top",
                label: "Promote window",
                words: "promote window main master stage make main swap with master",
                run: () => Hypr.promoteWindow(root.windowTarget(), layout)
            },
            {
                id: "center",
                icon: "center_focus_strong",
                label: "Center window",
                words: "center centre window middle",
                run: () => Hypr.centerWindow(root.windowTarget())
            }
        ].concat(Search.TILES.map(t => ({
                    id: t.id,
                    icon: root.tileIcon(t),
                    label: t.label,
                    words: t.words,
                    run: () => root.snap(t)
                })), many ? [
            {
                id: "nextdisplay",
                icon: "move_up",
                label: "Move to next display",
                words: "next display monitor screen move window",
                run: () => Hypr.moveToMonitor(root.windowTarget(), "+1")
            },
            {
                id: "previousdisplay",
                icon: "move_down",
                label: "Move to previous display",
                words: "previous display monitor screen move window",
                run: () => Hypr.moveToMonitor(root.windowTarget(), "-1")
            }
        ] : [], root.directions.map(d => ({
                    id: `swap-${d.name}`,
                    icon: d.icon,
                    label: `Swap ${d.name}`,
                    words: `swap ${d.name} window`,
                    run: () => Hypr.swapWindow(root.windowTarget(), d.short, layout)
                })), root.directions.map(d => ({
                    id: `focus-${d.name}`,
                    icon: d.icon,
                    label: `Focus ${d.name}`,
                    words: `focus ${d.name} window go`,
                    run: () => Hypr.focusToward(d.short, layout)
                })), root.directions.map(d => ({
                    id: `move-${d.name}`,
                    icon: d.icon,
                    label: `Move window ${d.name}`,
                    words: `move window ${d.name}`,
                    run: () => Hypr.moveWindowToward(root.windowTarget(), d.short)
                })), [
            {
                id: "nextworkspace",
                icon: "arrow_forward",
                label: "Move to next workspace",
                words: "next workspace move window",
                run: () => Hypr.moveToWorkspace(root.windowTarget(), "r+1")
            },
            {
                id: "previousworkspace",
                icon: "arrow_back",
                label: "Move to previous workspace",
                words: "previous workspace move window",
                run: () => Hypr.moveToWorkspace(root.windowTarget(), "r-1")
            }
        ]).map(named).concat([
            {
                id: "focusnextworkspace",
                icon: "arrow_forward",
                label: "Next workspace",
                words: "next workspace focus go switch",
                run: () => Hypr.focusWorkspace("r+1")
            },
            {
                id: "focuspreviousworkspace",
                icon: "arrow_back",
                label: "Previous workspace",
                words: "previous workspace focus go switch",
                run: () => Hypr.focusWorkspace("r-1")
            }
        ]);
    }

    readonly property var layoutCommands: WindowLayouts.available.map(name => ({
                id: `layout:${name}`,
                icon: "dashboard",
                label: `${Search.layoutLabel(name)} layout`,
                words: `layout tiling window ${Search.layoutLabel(name).toLowerCase()}`,
                detail: WindowLayouts.current === name ? "in use" : "",
                toggle: WindowLayouts.current === name,
                lead: /^(?:switch |change )?(?:window )?layouts?$/i,
                stay: true,
                run: () => WindowLayouts.use(name)
            }))

    readonly property int workspaceWanted: Search.workspaceAsk(root.text)
    readonly property int workspaceShown: Search.focusWorkspaceAsk(root.text)

    readonly property var workspaceRows: {
        const shown = root.workspaceShown;
        if (shown > 0)
            return [
                {
                    key: "command:showworkspace",
                    kind: "command",
                    command: {
                        id: "showworkspace",
                        label: `Focus workspace ${shown}`,
                        run: () => Hypr.focusWorkspace(String(shown))
                    },
                    label: `Focus workspace ${shown}`,
                    detail: "",
                    icon: "space_dashboard",
                    score: Infinity
                }
            ];
        const n = root.workspaceWanted;
        if (n <= 0 || !root.targetToplevel)
            return [];
        return [
            {
                key: "command:toworkspace",
                kind: "command",
                command: {
                    id: "toworkspace",
                    label: `Move to workspace ${n}`,
                    run: () => Hypr.moveToWorkspace(root.windowTarget(), String(n))
                },
                label: `Move to workspace ${n}`,
                detail: root.targetName,
                icon: "move_item",
                score: Infinity
            }
        ];
    }

    readonly property var openWindows: Hyprland.toplevels.values.filter(t => (t.workspace?.id ?? 0) !== 0)

    readonly property bool airplane: !Network.enabled && !Bluetooth.enabled

    property bool bluetoothBefore: false

    function setAirplane(on: bool): void {
        if (on) {
            root.bluetoothBefore = Bluetooth.enabled;
            Network.setEnabled(false);
            Bluetooth.setEnabled(false);
            return;
        }
        Network.setEnabled(true);
        if (root.bluetoothBefore)
            Bluetooth.setEnabled(true);
    }

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
            detail: arming ? Uninstaller.detailFor(entry.id) : entry.genericName || (entry.comment ?? "").replace(/^play this game on steam\.?$/i, ""),
            armed: arming,
            iconSource: entry.icon ? Quickshell.iconPath(entry.icon, true) : "",
            icon: "apps",
            score: root.appScore(entry)
        };
    }

    readonly property var appRows: {
        const found = Apps.search(root.text);
        return (root.text ? found.slice(0, root.caps.apps) : found).map(entry => root.appRow(entry));
    }

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
            score: c.lead?.test(root.text) ? Infinity : root.wordScore(c.label, c.words)
        };
    }

    readonly property var commandRows: root.text.length < 2 ? [] : root.commands.filter(c => !c.hidden).map(c => root.commandRow(c)).filter(r => r.score > 0).sort((a, b) => b.score - a.score)

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

    readonly property int awakeFor: Search.awakeAsk(root.text)

    readonly property var awakeRows: root.awakeFor <= 0 ? [] : [
        {
            key: "command:awakefor",
            kind: "command",
            command: {
                id: "awakefor",
                label: `Keep awake for ${Search.spanText(root.awakeFor)}`,
                stay: true,
                run: () => Idle.stayAwake(root.awakeFor)
            },
            label: `Keep awake for ${Search.spanText(root.awakeFor)}`,
            detail: `until ${TimeFormat.time(new Date(Date.now() + root.awakeFor * 1000), false)}`,
            icon: "coffee",
            score: Infinity
        }
    ]

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
        for (const s of root.sources) {
            const row = s.rowById?.(id) ?? null;
            if (row)
                return row;
        }
        return null;
    }

    function runnable(row: var): bool {
        return (["app", "command", "setting"].includes(row?.kind) || !!root.sourceOf(row)?.rowById);
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
            {
                const owner = root.sourceOf(row);
                if (!owner)
                    return "";
                owner.activate(row);
            }
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

    readonly property var contentRows: !root.grepFor || FileSearch.grepAnswered !== root.text ? [] : FileSearch.hits.map(line => Search.contentRow(line, Files.home)).filter(hit => hit && !root.fileRows.some(f => f.path === hit.path)).map(hit => ({
                key: `content:${hit.path}`,
                kind: "file",
                path: hit.path,
                dir: false,
                line: hit.line,
                label: hit.name,
                detail: `${hit.text} · ${hit.where}`,
                icon: Marks.iconFor(hit.path, hit.name, false, Files.home) || "draft",
                score: -1
            }))

    readonly property string cli: `${Quickshell.shellDir}/cli/banditshell`
    readonly property var cliLine: ShellCli.ask(root.query)

    property var help: null

    property FileView helpFile: FileView {
        path: root.cliLine !== null || root.help ? root.cli : ""
        onLoaded: root.help = ShellCli.parseHelp(root.helpFile.text())
    }

    property var cliOutput: null

    function runCli(line: string): void {
        const command = [root.cli, ...line.split(/\s+/).filter(Boolean)];
        if (ShellCli.detached(line)) {
            root.leave(() => Quickshell.execDetached(command));
            return;
        }
        root.cliOutput = {
            line: line,
            lines: ["…"]
        };
        root.cliRunner.running = false;
        root.cliRunner.line = line;
        root.cliRunner.command = command;
        root.cliRunner.running = true;
    }

    property Process cliRunner: Process {
        property string line: ""

        stdout: StdioCollector {
            id: cliSaid

            onStreamFinished: root.cliOutput = {
                line: root.cliRunner.line,
                lines: cliSaid.text.split("\n").map(l => l.replace(/\x1b\[[0-9;]*m/g, "")).filter(l => l.trim()).slice(0, 40)
            }
        }
    }

    readonly property var shellRows: {
        const line = root.cliLine;
        if (line === null)
            return [];
        const trimmed = line.trim();
        const usage = root.help && trimmed ? ShellCli.usageFor(root.help, trimmed) : null;
        const next = root.help ? ShellCli.nextWords(root.help, line) : null;
        const out = trimmed && (usage || !next?.words.length) ? [
            {
                key: `cli:${trimmed}`,
                kind: "cli",
                line: trimmed,
                label: `banditshell ${trimmed}`,
                detail: usage?.about ?? "",
                icon: "terminal",
                score: Infinity
            }
        ] : [];
        if (!next)
            return out;
        const typed = next.typed.join(" ");
        return out.concat(next.words.map(w => {
            const text = `${typed}${typed ? " " : ""}${w.word}`;
            return {
                key: `suggest:bandit ${text}`,
                kind: "suggest",
                complete: `bandit ${text} `,
                label: `banditshell ${text}`,
                detail: w.about,
                icon: "keyboard_tab",
                score: 2
            };
        }));
    }

    readonly property var outputRows: !root.cliOutput || root.cliOutput.line !== (root.cliLine ?? "").trim() ? [] : root.cliOutput.lines.map((text, i) => ({
                key: `output:${i}:${text}`,
                kind: "output",
                label: text,
                detail: "",
                icon: "subdirectory_arrow_right",
                score: 1
            }))

    readonly property var cities: ["Tokyo", "New York", "London", "Los Angeles", "Paris", "Berlin", "Sydney", "Singapore", "Dubai", "Toronto"]

    readonly property var suggestRows: {
        const typed = root.query.replace(/^\s+/, "");
        if (!typed || root.path)
            return [];
        const found = {
            places: [...new Set([...Clock.places.map(z => Clock.cityOf(z)), ...root.cities])],
            workspaces: Hyprland.workspaces.values.filter(w => w.id > 0).map(w => w.id).sort((a, b) => a - b).map(String),
            playing: Audio.playing.map(n => Search.streamName(Audio.streamLabel(n)).toLowerCase()),
            processes: [...new Set(root.processes.map(p => p.name))]
        };
        const more = root.sources.reduce((out, s) => out.concat(s.phrases ?? []), []);
        const inside = Search.PHRASES.concat(more).some(p => typed.toLowerCase().indexOf(p.head) === 0);
        return Search.suggestions(typed, found, more).slice(0, root.caps.suggestions).map(text => {
            const preview = Calculator.answerFor(text);
            return {
                key: `suggest:${text}`,
                kind: "suggest",
                complete: text,
                label: text.endsWith(" ") ? `${text}…` : text,
                detail: preview && !preview.missing ? preview.text : "",
                icon: "keyboard_tab",
                score: inside ? 3 : 0.4
            };
        });
    }

    readonly property var pathRows: root.path && FileSearch.listedDir === root.path.dir ? Search.pathRows(FileSearch.entries, root.path, FileSearch.hidden, Files.home).map(f => root.fileRow(f, "path")) : []

    readonly property bool windowList: Search.windowListAsk(root.text)

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
            workspace: t.workspace?.name ?? "",
            detail: `${app} · workspace ${t.workspace?.name ?? ""}`,
            iconSource: Apps.iconSourceFor([cls]),
            icon: "web_asset",
            recency: o.focusHistoryID > 0 ? o.focusHistoryID : 999,
            score: root.windowList ? Infinity : Math.max(Ranking.place(title, root.text), Ranking.place(app, root.text), Ranking.place(cls, root.text) - 0.5)
        };
    }).filter(r => r.score > 0).sort((a, b) => b.score - a.score || a.recency - b.recency)

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

    function zoneFor(place: string): string {
        if (!place)
            return Clock.localZone;
        return Search.ZONE_ABBREVIATIONS[place] ?? Search.zoneMatches(Clock.allZones, place, Clock.cityOf)[0] ?? "";
    }

    function placeName(place: string, zone: string): string {
        return Search.ZONE_ABBREVIATIONS[place] ? place.toUpperCase() : Clock.cityOf(zone);
    }

    readonly property var conversion: {
        const ask = root.convert;
        if (!ask)
            return null;
        const from = root.zoneFor(ask.from);
        const to = root.zoneFor(ask.to);
        if (!from || !to || from === to || !Clock.validZone(from) || !Clock.validZone(to))
            return null;
        return {
            ask: ask,
            from: from,
            to: to,
            at: `${String(ask.clock.hour).padStart(2, "0")}:${String(ask.clock.minute).padStart(2, "0")}`,
            key: `${from}|${to}|${ask.clock.hour}:${ask.clock.minute}`
        };
    }

    property var converted: null

    onConversionChanged: {
        const c = root.conversion;
        if (!c || root.converted?.key === c.key)
            return;
        root.converter.running = false;
        root.converter.key = c.key;
        root.converter.command = ["sh", "-c", 'day=$(TZ="$2" date +%F) && TZ="$1" date -d "TZ=\\"$2\\" $day $3" "+%H %M %F" && echo "$day"', "sh", c.to, c.from, c.at];
        root.converter.running = true;
    }

    property Process converter: Process {
        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const got = Search.readConversion(text);
                root.converted = got ? Object.assign(got, {
                    key: root.converter.key
                }) : null;
            }
        }
    }

    readonly property var convertRows: {
        const c = root.conversion;
        const got = root.converted;
        if (!c || got?.key !== c.key)
            return [];
        const time = TimeFormat.clock(got.hour, got.minute);
        const shifted = got.shift ? ` · ${Qt.locale().dayName(new Date(`${got.day}T12:00:00`).getDay(), Locale.LongFormat)}` : "";
        const local = c.to === Clock.localZone;
        return [
            {
                key: `convert:${c.key}`,
                kind: "zone",
                zone: local ? c.from : c.to,
                time: time,
                label: `${time} in ${root.placeName(c.ask.to, c.to)}${shifted}`,
                detail: `${TimeFormat.clock(c.ask.clock.hour, c.ask.clock.minute)} in ${root.placeName(c.ask.from, c.from)}`,
                icon: "schedule",
                score: Infinity
            }
        ];
    }

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
        return out.concat(root.convertRows, root.zoneRows);
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
        if (root.cliLine !== null)
            return Search.arrange([
                {
                    key: "output",
                    title: "Output",
                    items: root.outputRows
                },
                {
                    key: "shell",
                    title: "banditshell",
                    items: root.shellRows
                }
            ], root.caps);
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
            key: "suggestions",
            title: "Suggestions",
            items: root.suggestRows
        }, {
            key: "apps",
            title: "Apps",
            items: root.withAlias("app", root.appRows)
        }, {
            key: "commands",
            title: "Commands",
            items: root.withAlias("command", root.awakeRows.concat(root.workspaceRows, root.commandRows))
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
        }, ...root.sourceGroups);
        return Search.arrange(groups, root.limits);
    }

    function openSetting(row: var): void {
        const hit = row.hit;
        root.leave(() => Settings.openAt(root.screenName, hit.page.id, hit.row.k ?? ""));
    }

    function activate(row: var): void {
        const owner = root.sourceOf(row);
        if (owner) {
            owner.activate(row);
            return;
        }
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
        case "suggest":
            root.retype(row.complete);
            return;
        case "cli":
            root.runCli(row.line);
            return;
        case "output":
            root.leave(() => Files.copyText(row.label));
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
        const owner = root.sourceOf(row);
        if (owner)
            return !!owner.complete?.(row);
        if (row?.kind === "suggest") {
            root.retype(row.complete);
            return true;
        }
        if (row?.kind !== "file")
            return false;
        root.retype(`${Search.shortPath(row.path, Files.home)}${row.dir ? "/" : ""}`);
        return true;
    }

    function actionsFor(row: var): var {
        const owner = root.sourceOf(row);
        if (owner)
            return owner.actionsFor?.(row) ?? [];
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
            {
                const here = Hyprland.focusedMonitor?.activeWorkspace;
                return [
                    {
                        icon: "open_in_new",
                        label: "Switch to",
                        run: () => root.activate(row)
                    }
                ].concat(!here || here.name === row.workspace ? [] : [
                        {
                            icon: "move_down",
                            label: "Bring here",
                            run: () => root.leave(() => {
                                Hypr.moveToWorkspace(row.address, String(here.id));
                                Hypr.focusAddress(row.address);
                            })
                        }
                    ], [
                    {
                        icon: "close",
                        label: "Close",
                        run: () => Hypr.closeWindow(row.address)
                    }
                ]);
            }
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
