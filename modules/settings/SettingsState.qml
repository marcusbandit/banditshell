pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "catalogue.js" as Catalogue
import "screens.js" as Screens

Singleton {
    id: root

    readonly property var planDefaults: ({
            hotspot: false,
            hotspotName: "banditshell",
            hotspotPass: "",
            hotspotBand: "2.4 GHz",
            alerts: true,
            alertSet: "soft",
            alertVol: 0.5,
            nightSched: "off",
            dnd: false,
            dndUntil: "off by hand",
            dndAlarms: true,
            dndNightly: false,
            mode: "none",
            greyCap: false,
            breaks: false,
            breakEvery: 50,
            kbDelay: 300,
            kbRate: 30,
            mouseSpeed: 0,
            padSpeed: 0.2,
            naturalScroll: true,
            tapClick: true,
            penBtn1: "right click",
            penBtn2: "erase",
            chargeLimit: true,
            chargeMax: 80,
            lowWarn: 15,
            lowAction: "suspend at 5%",
            profile: "balanced",
            lidBattery: "suspend",
            lidPlugged: "lock",
            lidDocked: "nothing",
            idleLock: "5 min",
            idleOff: "10 min",
            idleSuspend: "30 min",
            defBrowser: "firefox",
            defFiles: "files",
            defTerm: "kitty",
            defMail: "thunderbird",
            defImages: "loupe",
            defVideo: "mpv",
            clock24: true,
            dateFormat: "14/10/2026",
            autoZone: true,
            zone: "Europe/Copenhagen",
            lang: "English (UK)",
            region: "Denmark",
            reduceMotion: false,
            largerText: false,
            contrast: false,
            layout: "dwindle",
            overAmp: true,
            specialsShown: true,
            sbClock: "stacked",
            sbDate: "day and month",
            sbSound: true,
            sbNet: true,
            sbBt: true,
            sbBatt: true,
            tray: true,
            boardRepeat: true,
            customLayout: "",
            startup: [],
            rules: [],
            layouts: [],
            tunnels: [],
            screens: ({})
        })

    readonly property var uiDefaults: ({
            wallTarget: "everywhere"
        })

    property var planned: ({})
    property var ui: ({})
    property var changes: []
    property var wrote: null
    property var modeWas: ({})

    property bool loaded: false

    readonly property string path: `${Config.stateDir}/settings.json`

    readonly property var transforms: ({
            notifTimeout: {
                read: v => Math.round(v / 1000),
                write: v => v * 1000
            },
            cloud: {
                read: v => (v || []).join(" "),
                write: v => String(v).trim().split(/\s+/).filter(Boolean)
            },
            termColours: {
                read: v => JSON.stringify(v) === JSON.stringify(Config.defaults.files.terminal.palette) ? "one dark" : "theme",
                write: v => v === "one dark" ? Config.defaults.files.terminal.palette : root.themePalette()
            },
            iconMode: {
                read: v => v === "colour" ? "colour" : "mono",
                write: v => v === "colour" ? "colour" : "symbol"
            },
            roleSpeakers: {
                read: v => v,
                write: v => v
            }
        })

    function themePalette(): var {
        const t = Appearance.theme;
        const r = t.ramp;
        return [r[1], t.alarm, t.bright, t.mid, t.dim, t.mid, t.bright, r[9], r[6], t.alarm, t.bright, t.mid, t.dim, t.mid, t.bright, r[10]].map(c => String(c));
    }

    function rowOf(k: string): var {
        return Catalogue.ROW_BY_KEY[k] ?? null;
    }

    function cfgOf(k: string): string {
        const r = root.rowOf(k);
        return r?.cfg ?? "";
    }

    readonly property var configBacked: ({
            keepFresh: "network.keepListFresh",
            netCheck: "network.checkForInternet",
            portalUri: "network.portalUri",
            volStep: "volume.step",
            roleSpeakers: "audio.speakers",
            roleHeadphones: "audio.headphones",
            warmest: "screen.warmest",
            fromWall: "themeFromWallpaper",
            accent: "colour.accent",
            surface: "colour.surface",
            surfaceAlpha: "material.surfaceAlpha",
            wallOn: "wallpaper.enabled",
            wallDir: "wallpaper.dir",
            wallAnim: "wallpaper.animate",
            wallAudio: "wallpaper.audio",
            wallReveal: "wallpaper.reveal",
            wallFit: "wallpaper.fit",
            font: "font.family",
            iconFont: "font.icon",
            fontBase: "font.base",
            iconScale: "font.iconScale",
            follow: "compositor.follow",
            rounding: "rounding.base",
            power: "rounding.power",
            border: "edge.border",
            roundOuter: "edge.roundOuter",
            pushBorders: "compositor.pushBorders",
            bare: "edge.bare",
            anim: "anim.base",
            sidebarW: "sidebar.width",
            wsStyle: "sidebar.workspaces.style",
            iconMode: "sidebar.workspaces.iconMode",
            persistent: "sidebar.workspaces.persistent",
            trayMax: "sidebar.tray.max",
            sbUpdate: "sidebar.update",
            edgeLift: "windows.edge",
            dropMode: "windows.mode",
            followSent: "windows.follow",
            launcherW: "launcher.width",
            clipW: "clipboard.width",
            menuW: "menu.width",
            settingsW: "settings.width",
            concept: "launcher.concept",
            launcherIcon: "launcher.iconSize",
            halfLife: "launcher.halfLifeDays",
            clip: "clipboard.record",
            clipMax: "clipboard.maxEntries",
            clipText: "clipboard.maxText",
            clipBlob: "clipboard.maxBlob",
            notifTimeout: "notifications.timeout",
            notifPopups: "notifications.maxPopups",
            notifHistory: "notifications.maxHistory",
            wheelSeek: "media.wheelSeek",
            seekSmall: "media.seekSmall",
            seekLarge: "media.seekLarge",
            snooze: "clock.snoozeMinutes",
            ring: "clock.ringMinutes",
            catchUp: "clock.catchUpMinutes",
            timerMax: "clock.timerMax",
            alarmMax: "clock.alarmMax",
            cloud: "clock.cloud",
            cloudSeconds: "clock.cloudSeconds",
            capHours: "usage.capHours",
            rightForward: "calendar.rightGoesForward",
            shotDir: "picker.dir",
            shotEditor: "picker.editor",
            outline: "picker.outline",
            stream: "stream.enabled",
            streamScreen: "stream.screen",
            streamHeight: "stream.height",
            lockBlur: "lock.blur",
            lockDim: "lock.dim",
            lockDesat: "lock.desaturate",
            filesView: "files.view",
            filesSort: "files.sort",
            filesHidden: "files.hidden",
            filesMarkdown: "files.markdown",
            filesZoom: "files.zoom",
            termFont: "files.terminal.font",
            termRows: "files.terminal.rows",
            termScroll: "files.terminal.scrollback",
            termColours: "files.terminal.palette",
            sheetBoard: "cheatsheet.board",
            touchEdges: "control.touchEdges",
            gestureFeel: "control.pullCommit",
            autoKeyboard: "tablet.autoKeyboard",
            docked: "tablet.docked",
            boardHeight: "tablet.height",
            pen: "pen.enabled",
            aspectLock: "pen.aspectLock",
            branch: "updates.branch",
            remote: "updates.remote",
            updEvery: "updates.interval",
            sourceEdits: "sourceEdits.acknowledged",
            sheetShape: "cheatsheet.shape"
        })

    function plannedKey(k: string): bool {
        return root.planDefaults[k] !== undefined;
    }

    function v(k: string): var {
        const cfg = root.configBacked[k];
        if (cfg) {
            const raw = Config.get(cfg);
            const t = root.transforms[k];
            return t ? t.read(raw) : raw;
        }
        if (k === "scr:layout")
            return root.liveSpecs();
        if (k.startsWith("scr:"))
            return root.screenValue(k.slice(4));
        switch (k) {
        case "wifi":
            return Network.enabled;
        case "autoJoin":
            return Network.autoconnect;
        case "wired":
            return Network.wiredManaged;
        case "wiredAuto":
            return Network.wiredAutoconnect;
        case "bt":
            return Bluetooth.enabled;
        case "btVisible":
            return Bluetooth.discoverable;
        case "btPairable":
            return Bluetooth.pairable;
        case "volume":
            return Audio.volume;
        case "muted":
            return Audio.muted;
        case "output":
            return Audio.sink?.name ?? "";
        case "input":
            return Audio.source?.name ?? "";
        case "micLevel":
            return Audio.sourceVolume;
        case "level":
            return Display.levelKnown ? Math.round(Display.level * 100) : 100;
        case "warmth":
            return Display.warm ? Math.round(Math.max(0, Math.min(100, (Display.neutral - Display.kelvin) / Math.max(1, Display.neutral - Display.warmest) * 100))) : 0;
        case "theme":
            return Config.values.theme;
        case "sidebar":
            return SidebarState.enabled;
        case "sheetKeyboard":
            return Keyboards.stored || root.boardWanted ? "file" : Keyboards.shape;
        case "bindsFile":
            return HyprConfig.configPath;
        case "cfgPath":
            return Config.path;
        case "statePath":
            return Config.stateDir;
        case "tabComplete":
            return root.completionsInstalled;
        case "penScreen":
            return PenMap.monitorName || "all";
        case "wallTarget":
            return root.ui.wallTarget ?? root.uiDefaults.wallTarget;
        case "vpnFirst":
            return (root.planned.tunnels ?? []).some(t => t.on);
        case "warm":
            return Display.warm;
        case "saver":
            return root.v("profile") === "saver";
        }
        if (root.plannedKey(k))
            return root.planned[k] ?? root.planDefaults[k];
        return undefined;
    }

    function defaultOf(k: string): var {
        const cfg = root.configBacked[k];
        if (cfg) {
            const raw = root.lookup(Config.defaults, cfg);
            const t = root.transforms[k];
            return t ? t.read(raw) : raw;
        }
        if (root.plannedKey(k))
            return root.planDefaults[k];
        return undefined;
    }

    function lookup(values: var, key: string): var {
        let at = values;
        for (const part of key.split(".")) {
            if (at === null || at === undefined)
                return undefined;
            at = at[part];
        }
        return at;
    }

    function write(k: string, value: var): void {
        const cfg = root.configBacked[k];
        if (cfg) {
            const t = root.transforms[k];
            Config.set(cfg, t ? t.write(value) : value);
            return;
        }
        if (k === "scr:layout")
            return root.restore(value);
        if (k.startsWith("scr:"))
            return root.setScreen(k.slice(4), value);
        switch (k) {
        case "wifi":
            return Network.setEnabled(value);
        case "autoJoin":
            return Network.setAutoconnect(value);
        case "wired":
            return Network.setWiredManaged(value);
        case "wiredAuto":
            return Network.setWiredAutoconnect(value);
        case "bt":
            return Bluetooth.setEnabled(value);
        case "btVisible":
            return Bluetooth.setDiscoverable(value);
        case "btPairable":
            return Bluetooth.setPairable(value);
        case "volume":
            return Audio.setVolume(value);
        case "muted":
            if (Audio.muted !== value)
                Audio.toggleMute();
            return;
        case "output":
            {
                const n = Audio.sinks.find(s => s.name === value);
                if (n)
                    Audio.setSink(n);
                else
                    root.denied = true;
                return;
            }
        case "input":
            {
                const n = Audio.sources.find(s => s.name === value);
                if (n)
                    Audio.setSource(n);
                else
                    root.denied = true;
                return;
            }
        case "micLevel":
            return Audio.setSourceVolume(value);
        case "level":
            return Display.setLevel(value / 100);
        case "warmth":
            return Display.setWarmth(value > 0 ? Math.round(Display.neutral - value / 100 * (Display.neutral - Display.warmest)) : 0);
        case "warm":
            return Display.toggleWarm();
        case "theme":
            return ThemeSwitcher.apply(value);
        case "sidebar":
            return SidebarState.setAll(value);
        case "sheetKeyboard":
            if (value !== "file") {
                root.boardWanted = false;
                if (Keyboards.stored)
                    Keyboards.clear();
                Config.set(root.configBacked.sheetShape, value);
            } else {
                root.boardWanted = true;
            }
            return;
        case "tabComplete":
            return root.setCompletions(value);
        case "penScreen":
            return root.mapPen(value);
        case "wallTarget":
            root.ui = Object.assign({}, root.ui, {
                wallTarget: value
            });
            root.save();
            return;
        case "saver":
            return root.set("profile", value ? "saver" : "balanced");
        case "vpnFirst":
            {
                const list = (root.planned.tunnels ?? []).slice();
                if (list.length)
                    list[0] = Object.assign({}, list[0], {
                        on: value
                    });
                return root.plan("tunnels", list);
            }
        }
        if (root.plannedKey(k))
            root.plan(k, value);
    }

    property bool boardWanted: false

    property string penWanted: ""

    function mapPen(name: string): void {
        if (name === "all") {
            root.penWanted = "";
            PenMap.unbind();
            PenMap.mapped = false;
            PenMap.monitorName = "";
            PenMap.save();
            return;
        }
        const mon = PenMap.monitorNamed(name);
        if (!mon) {
            root.penWanted = name;
            PenMap.scanMonitors();
            return;
        }
        root.penWanted = "";
        PenMap.mapped = true;
        PenMap.monitorName = name;
        if (Config.values.pen.aspectLock)
            PenMap.fitAndCentre();
        else {
            PenMap.region = Qt.rect(mon.x, mon.y, mon.w, mon.h);
            PenMap.applyRegion();
            PenMap.save();
        }
    }

    Connections {
        target: PenMap

        function onMonitorsChanged(): void {
            if (root.penWanted)
                root.mapPen(root.penWanted);
        }
    }

    function plan(k: string, value: var): void {
        const next = Object.assign({}, root.planned);
        next[k] = value;
        root.planned = next;
        root.save();
    }

    property bool muteLog: false

    property bool denied: false

    function set(k: string, value: var): void {
        const before = root.v(k);
        if (JSON.stringify(before) === JSON.stringify(value))
            return;
        root.denied = false;
        root.write(k, value);
        if (root.denied)
            return;
        const r = root.rowOf(k);
        const typed = r?.kind === "text" || r?.kind === "secret";
        if (r && !typed && !root.muteLog && !root.stagedKey(k) && (value === null || typeof value !== "object"))
            root.log(k, r, before, value);
        if (r?.cfg && !typed && root.configBacked[k]) {
            const t = root.transforms[k];
            const written = t ? t.write(value) : value;
            root.wrote = {
                key: r.cfg,
                value: typeof written === "string" ? `"${written}"` : typeof written === "number" ? +written.toFixed(3) : JSON.stringify(written)
            };
        }
    }

    function shown(r: var, x: var): string {
        return Catalogue.show(r, x, root);
    }

    function log(k: string, r: var, from: var, to: var): void {
        const label = Catalogue.labelOf(r) || k;
        const now = Date.now();
        const list = root.changes.slice();
        const prev = list[0];
        if (prev && prev.k === k && now - prev.t < 4000) {
            if (JSON.stringify(prev.old) === JSON.stringify(to))
                list.shift();
            else
                list[0] = Object.assign({}, prev, {
                    to: root.shown(r, to),
                    v: to,
                    t: now
                });
        } else {
            list.unshift({
                k,
                label,
                page: r.page,
                from: root.shown(r, from),
                to: root.shown(r, to),
                old: from,
                v: to,
                t: now
            });
        }
        root.changes = list.slice(0, 30);
        root.save();
    }

    function undo(i: int): var {
        const c = root.changes[i];
        if (!c)
            return null;
        const list = root.changes.slice();
        list.splice(i, 1);
        root.changes = list;
        root.muteLog = true;
        root.set(c.k, c.old);
        root.muteLog = false;
        root.save();
        return c;
    }

    function setMode(id: string): void {
        const m = Catalogue.MODES.find(x => x.id === id);
        if (!m)
            return;
        root.muteLog = true;
        if (root.v("mode") !== "none")
            for (const key of Object.keys(root.modeWas).filter(k => root.plannedKey(k)))
                root.set(key, root.modeWas[key]);
        const was = {};
        for (const key of Object.keys(m.set).filter(k => root.plannedKey(k))) {
            was[key] = root.v(key);
            root.set(key, m.set[key]);
        }
        root.modeWas = was;
        root.plan("modeWas", was);
        root.set("mode", id);
        root.muteLog = false;
    }

    function screenRecord(name: string): var {
        return (root.planned.screens ?? {})[name] ?? {
            on: true,
            mirror: ""
        };
    }

    function screenValue(sub: string): var {
        const name = Monitors.selected;
        const spec = root.stagedSpec(name);
        switch (sub) {
        case "on":
            return root.screenRecord(name).on;
        case "mirror":
            return root.screenRecord(name).mirror;
        case "res":
            return spec ? spec.mode.split("@")[0] : "";
        case "hz":
            return spec ? `${Math.round(+(spec.mode.split("@")[1] ?? 0))}` : "";
        case "scale":
            return spec ? Math.round(spec.scale * 100) / 100 : 1;
        case "rot":
            return spec ? (spec.transform % 4) * 90 : 0;
        case "vrr":
            return !!spec?.vrr;
        case "ws":
            return root.bandOf(name);
        case "bar":
            return SidebarState.visibleOn(name);
        }
        return undefined;
    }

    function describeMonitor(name: string): string {
        const spec = root.stagedSpec(name);
        if (!root.screenRecord(name).on)
            return "disable";
        if (!spec)
            return "";
        return `${spec.mode}, ${spec.position}, ${Math.round(spec.scale * 100) / 100}${spec.transform ? `, transform ${spec.transform}` : ""}${root.stage[name] ? " · not applied yet" : ""}`;
    }

    function bandOf(name: string): string {
        return Hypr.bands.find(b => b.monitor === name)?.workspaces ?? "";
    }

    signal refused(string why, string go)

    function edits(): bool {
        if (Config.values.sourceEdits?.acknowledged)
            return true;
        root.denied = true;
        root.refused("turn on Edit Hyprland files first", "shell");
        return false;
    }

    function setScreen(sub: string, value: var): void {
        const name = Monitors.selected;
        if (!name)
            return;
        const spec = root.stagedSpec(name);
        switch (sub) {
        case "on":
        case "mirror":
            {
                const all = Object.assign({}, root.planned.screens ?? {});
                all[name] = Object.assign({}, root.screenRecord(name), sub === "on" ? {
                    on: value
                } : {
                    mirror: value
                });
                root.plan("screens", all);
                return;
            }
        case "res":
            {
                if (!spec)
                    return;
                const wh = String(value).split("x").map(Number);
                const hz = +(root.liveSpec(name)?.mode.split("@")[1] ?? spec.mode.split("@")[1] ?? 60);
                const rates = root.modesOf(name).filter(m => m.w === wh[0] && m.h === wh[1]).map(m => m.hz);
                rates.sort((a, b) => Math.abs(a - hz) - Math.abs(b - hz));
                return root.stageSize(name, {
                    mode: Monitors.modeString(wh[0], wh[1], rates[0] ?? hz)
                });
            }
        case "hz":
            {
                if (!spec)
                    return;
                const wh = spec.mode.split("@")[0].split("x").map(Number);
                return root.stageScreen(name, {
                    mode: Monitors.modeString(wh[0], wh[1], +value)
                });
            }
        case "scale":
            return root.stageSize(name, {
                scale: +value
            });
        case "rot":
            return root.stageSize(name, {
                transform: Math.round(+value / 90) % 4
            });
        case "vrr":
            return root.stageScreen(name, {
                vrr: value ? 1 : 0
            });
        case "ws":
            return root.assignBand(name, value);
        case "bar":
            return SidebarState.setOn(name, value);
        }
    }

    property var stage: ({})
    property var confirm: null

    readonly property var screenRects: Monitors.outputs.map(m => Screens.rectOf(m.name, root.stagedSpec(m.name)))
    readonly property var liveRects: Monitors.outputs.map(m => Screens.rectOf(m.name, root.liveSpec(m.name)))
    readonly property var stagedNames: Object.keys(root.stage).filter(n => Monitors.outputs.some(m => m.name === n))
    readonly property var screenTrouble: Screens.issues(root.screenRects)
    readonly property int confirmLeft: root.confirm?.left ?? 0

    function stagedKey(k: string): bool {
        return ["scr:res", "scr:hz", "scr:scale", "scr:rot", "scr:vrr"].indexOf(k) >= 0;
    }

    function liveSpec(name: string): var {
        return Monitors.queued[name] ?? Monitors.displaySpec(name);
    }

    function stagedSpec(name: string): var {
        const live = root.liveSpec(name);
        if (!live)
            return null;
        return Object.assign({}, live, root.stage[name] ?? {});
    }

    function sameField(key: string, a: var, b: var): bool {
        if (key === "scale")
            return Math.abs(+a - +b) < 0.001;
        return String(a) === String(b);
    }

    function restage(fields: var): void {
        const next = Object.assign({}, root.stage);
        for (const name of Object.keys(fields)) {
            const live = root.liveSpec(name);
            if (!live)
                continue;
            const mine = Object.assign({}, next[name] ?? {}, fields[name]);
            for (const key of Object.keys(mine))
                if (root.sameField(key, mine[key], live[key]))
                    delete mine[key];
            if (Object.keys(mine).length)
                next[name] = mine;
            else
                delete next[name];
        }
        root.stage = next;
    }

    function stageScreen(name: string, fields: var): void {
        root.restage({
            [name]: fields
        });
    }

    function stageSize(name: string, fields: var): void {
        const fresh = Screens.rectOf(name, Object.assign({}, root.stagedSpec(name), fields));
        const moves = Screens.resize(root.screenRects, name, fresh);
        const all = {
            [name]: Object.assign({}, fields)
        };
        for (const other of Object.keys(moves))
            all[other] = Object.assign(all[other] ?? {}, {
                position: `${moves[other].x}x${moves[other].y}`
            });
        root.restage(all);
    }

    function pendingNote(sub: string): string {
        const field = {
            res: "mode",
            hz: "mode",
            scale: "scale",
            rot: "transform",
            vrr: "vrr"
        }[sub];
        const mine = root.stage[Monitors.selected];
        if (!mine || mine[field] === undefined)
            return "";
        const live = root.liveSpec(Monitors.selected);
        if (sub === "res" && live && String(live.mode).split("@")[0] === String(mine.mode).split("@")[0])
            return "";
        if (sub === "hz" && live && String(live.mode).split("@")[1] === String(mine.mode).split("@")[1])
            return "";
        return "not applied yet";
    }

    function resetStage(): void {
        root.stage = {};
    }

    function liveSpecs(): var {
        const out = {};
        for (const m of Monitors.outputs) {
            const spec = root.liveSpec(m.name);
            if (spec)
                out[m.name] = spec;
        }
        return out;
    }

    function differs(a: var, b: var): bool {
        return ["mode", "position", "scale", "transform", "vrr"].some(key => !root.sameField(key, a[key], b[key]));
    }

    function restore(specs: var): void {
        if (!root.edits())
            return;
        for (const name of Object.keys(specs ?? {})) {
            const live = root.liveSpec(name);
            if (live && root.differs(live, specs[name]))
                Monitors.applySpec(specs[name]);
        }
    }

    function summary(before: var, after: var): string {
        const parts = [];
        for (const name of Object.keys(after)) {
            const a = before[name];
            const b = after[name];
            const what = [];
            if (!root.sameField("mode", a.mode, b.mode))
                what.push(String(b.mode).replace("x", " × ").replace("@", " · ") + " Hz");
            if (!root.sameField("scale", a.scale, b.scale))
                what.push(`×${Math.round(b.scale * 100) / 100}`);
            if (!root.sameField("transform", a.transform, b.transform))
                what.push(`${(b.transform % 4) * 90}°`);
            if (!root.sameField("vrr", a.vrr, b.vrr))
                what.push(b.vrr ? "vrr on" : "vrr off");
            if (!what.length && !root.sameField("position", a.position, b.position))
                what.push("moved");
            parts.push(`${name} ${what.join(" · ")}`);
        }
        return parts.join(", ");
    }

    function applyStage(): void {
        if (root.confirm || !root.stagedNames.length || root.screenTrouble.clash.length || !root.edits())
            return;
        const placed = root.screenRects;
        const before = {};
        const after = {};
        let risky = false;
        for (const r of placed) {
            const live = root.liveSpec(r.name);
            if (!live)
                continue;
            const next = Object.assign({}, live, root.stage[r.name] ?? {}, {
                position: `${r.x}x${r.y}`
            });
            if (!root.differs(live, next))
                continue;
            before[r.name] = live;
            after[r.name] = next;
            if (["mode", "scale", "transform"].some(key => !root.sameField(key, live[key], next[key])))
                risky = true;
        }
        root.stage = {};
        if (!Object.keys(after).length)
            return;
        for (const name of Object.keys(after))
            Monitors.applySpec(after[name]);
        const now = Date.now();
        const list = root.changes.slice();
        list.unshift({
            k: "scr:layout",
            label: "Screens",
            page: "screens",
            from: "as they were",
            to: root.summary(before, after),
            old: before,
            v: after,
            t: now
        });
        root.changes = list.slice(0, 30);
        root.save();
        if (risky)
            root.confirm = {
                before,
                t: now,
                left: 15
            };
        else
            SettingsView.drop("screens applied", "check", null);
    }

    function keepApplied(): void {
        root.confirm = null;
    }

    function revertApplied(): void {
        const c = root.confirm;
        root.confirm = null;
        if (!c)
            return;
        for (const name of Object.keys(c.before))
            Monitors.applySpec(c.before[name]);
        root.changes = root.changes.filter(x => !(x.k === "scr:layout" && x.t === c.t));
        root.save();
        SettingsView.drop("screens went back", "undo", null);
    }

    function closed(): void {
        root.stage = {};
        if (root.confirm)
            root.revertApplied();
    }

    Timer {
        interval: 1000
        repeat: true
        running: !!root.confirm && !HyprConfig.applying && Object.keys(Monitors.queued).length === 0
        onTriggered: {
            const c = root.confirm;
            if (!c)
                return;
            if (c.left <= 1)
                root.revertApplied();
            else
                root.confirm = Object.assign({}, c, {
                    left: c.left - 1
                });
        }
    }

    function assignBand(name: string, spec: string): void {
        if (!root.edits())
            return;
        const entry = HyprConfig.bands.find(b => !b.dynamic && b.monitor === name && b.path?.[1] === HyprConfig.hostName);
        if (entry)
            HyprConfig.updateBand(entry.id, {
                workspaces: spec
            });
        else if (spec)
            HyprConfig.addBand({
                monitor: name,
                workspaces: spec
            });
    }

    function modesOf(name: string): var {
        const out = [];
        const o = Monitors.outputs.find(m => m.name === name);
        for (const s of o?.availableModes ?? []) {
            const p = Monitors.parseMode(s);
            if (p)
                out.push(p);
        }
        return out;
    }

    readonly property var resolutions: {
        const seen = [];
        const out = [];
        const modes = root.modesOf(Monitors.selected);
        modes.sort((a, b) => b.w * b.h - a.w * a.h);
        for (const m of modes) {
            const key = `${m.w}x${m.h}`;
            if (seen.indexOf(key) < 0) {
                seen.push(key);
                out.push([key, `${m.w} × ${m.h}`]);
            }
        }
        return out;
    }

    readonly property var rates: {
        const res = root.v("scr:res");
        const out = [];
        for (const m of root.modesOf(Monitors.selected)) {
            const hz = `${Math.round(m.hz)}`;
            if (`${m.w}x${m.h}` === res && !out.some(o => o[0] === hz))
                out.push([hz, `${hz} Hz`]);
        }
        return out.sort((a, b) => +b[0] - +a[0]);
    }

    readonly property var bandChoices: {
        const out = [];
        for (const b of Hypr.bands)
            if (b.workspaces && !out.some(o => o[0] === b.workspaces))
                out.push([b.workspaces, root.bandLabel(b.workspaces)]);
        const mine = root.bandOf(Monitors.selected);
        if (mine && !out.some(o => o[0] === mine))
            out.push([mine, root.bandLabel(mine)]);
        out.push(["", "any"]);
        return out;
    }

    function bandLabel(spec: string): string {
        return String(spec).split(",").map(p => p.trim().replace("-", " to ")).join(", ");
    }

    readonly property var monitorNames: Monitors.outputs.map(m => m.name)
    readonly property var screensOn: root.monitorNames.filter(n => root.screenRecord(n).on)
    readonly property string selMon: Monitors.selected
    readonly property bool onlyOn: root.screenRecord(Monitors.selected).on && root.screensOn.length === 1

    readonly property string selMonWhat: {
        const o = Monitors.outputs.find(m => m.name === Monitors.selected);
        if (!o)
            return "";
        if (o.name.startsWith("eDP"))
            return "built-in";
        const l = Monitors.layoutOf(o);
        const ratio = l.w / Math.max(1, l.h);
        if (ratio > 2.6)
            return "ultrawide";
        if (ratio < 1)
            return "portrait";
        return o.model || o.description || "screen";
    }

    readonly property string wifiNet: Network.enabled && Network.connected ? Network.activeName : ""
    readonly property string reach: Network.online ? "online" : Network.reachLabel() || (Network.linked ? "checking" : "offline")

    readonly property string btName: Bluetooth.adapterName || "this machine"
    readonly property var btConnected: Bluetooth.connectedDevices.map(d => d.name || d.deviceName || "device")
    readonly property int btNear: Bluetooth.strangers.length

    readonly property string wiredDetail: Network.wiredConnected ? `${Network.wiredDeviceName}${Network.wiredLabel ? " · " + Network.wiredLabel : ""}` : Network.wiredAvailable ? "unplugged" : "no port"
    readonly property string wiredFact: [Network.wiredDeviceName, Network.wiredAddress].filter(Boolean).join(" · ")

    readonly property int tunnelCount: (root.planned.tunnels ?? []).length

    readonly property string vpnOn: (root.planned.tunnels ?? []).find(t => t.on)?.name ?? ""

    readonly property var outputs: Audio.sinks.map(n => [n.name, Audio.deviceLabel(n)])
    readonly property var inputs: Audio.sources.map(n => [n.name, Audio.deviceLabel(n)])
    readonly property string outputName: Audio.sink ? Audio.deviceLabel(Audio.sink) : "no output"
    readonly property string inputName: Audio.source ? Audio.deviceLabel(Audio.source) : "no microphone"
    readonly property int appsPlaying: Audio.playing.length

    readonly property string wallName: Wallpaper.name || "nothing"

    property var fonts: [Config.values.font.family]
    property var monoFonts: [Config.values.files.terminal.font]

    readonly property int neutral: Display.neutral

    readonly property string followDetail: `rounding ${Math.round(Compositor.rounding)} · gaps ${Compositor.gapsOut}`

    readonly property var specialNames: Hypr.specials.map(s => s.label)
    readonly property bool hasBattery: Battery.available
    property bool lidSeen: false
    readonly property bool hasLid: root.lidSeen || Monitors.outputs.some(m => m.name.startsWith("eDP") || m.name.startsWith("LVDS") || m.name.startsWith("DSI"))
    readonly property int trayCount: Tray.items.length
    readonly property int starredCount: Object.keys(Config.values.launcher.starred ?? {}).length

    readonly property bool clipseImported: !Config.values.clipboard.importClipse
    readonly property int clipseWaiting: 0
    readonly property string clipseDetail: root.clipseImported ? "brought over" : "comes over at the next start"

    readonly property string nextAlarm: {
        const now = Date.now();
        let best = 0;
        for (const a of Clock.alarms) {
            if (!a.armed)
                continue;
            const at = Clock.nextFor(a, now);
            if (at && (!best || at < best))
                best = at;
        }
        return best ? `next alarm ${Qt.formatTime(new Date(best), "HH:mm")}` : "no alarms set";
    }

    property double tick: Date.now()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.tick = Date.now()
    }

    readonly property var usageToday: {
        const now = root.tick;
        return Usage.forDay(new Date(now));
    }

    readonly property int usedMinutes: root.usageToday?.minutes ?? 0

    readonly property var usageHours: {
        const live = Usage.revision;
        const now = new Date(root.tick);
        const from = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const out = [];
        for (let h = 0; h < 24; h++)
            out.push(0);
        for (const sp of Usage.spans) {
            const s = Math.max(sp.s, from);
            const e = Math.min(sp.e, from + 86400000);
            for (let t = s; t < e;) {
                const h = Math.floor((t - from) / 3600000);
                const edge = Math.min(e, from + (h + 1) * 3600000);
                out[h] += (edge - t) / 60000;
                t = edge;
            }
        }
        return out.map(m => Math.round(m));
    }

    function minutesLabel(m: int): string {
        return m >= 60 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${m} min`;
    }

    readonly property string usedLabel: root.minutesLabel(root.usedMinutes)

    readonly property var kbLayouts: (root.planned.layouts ?? []).length ? root.planned.layouts : root.detectedLayouts
    property var detectedLayouts: [{
            name: "english (us)",
            code: "us"
        }]

    readonly property int keyCount: HyprConfig.binds.length + Object.keys(Config.values.files.keys ?? {}).length

    readonly property string repeatDetail: `${Config.defaults.tablet.repeatDelay} ms, then every ${Config.values.tablet.repeatInterval}`

    readonly property string penName: Config.values.pen.device.replace(/-pen$/, "").replace(/-/g, " ")

    readonly property int batteryPct: Battery.percent
    readonly property bool healthKnown: Battery.healthKnown
    readonly property int healthPct: Math.round(Battery.health)

    readonly property int startupOn: (root.planned.startup ?? []).filter(s => s.on).length

    function appsFor(k: string): var {
        const seed = [root.v(k)];
        const pool = ({
                defBrowser: ["firefox", "chromium", "zen"],
                defFiles: ["files", "nautilus", "thunar"],
                defTerm: ["kitty", "foot", "alacritty"],
                defMail: ["thunderbird", "geary"],
                defImages: ["loupe", "imv", "gwenview"],
                defVideo: ["mpv", "celluloid", "vlc"]
            })[k] ?? [];
        return seed.concat(pool.filter(a => a !== seed[0]));
    }

    readonly property var zoneChoices: {
        const here = Clock.localZone;
        const out = [];
        for (const z of [here, "Europe/Copenhagen", "Europe/London", "America/New_York", "Asia/Tokyo"])
            if (z && out.indexOf(z) < 0)
                out.push(z);
        return out;
    }

    readonly property var branches: {
        const out = [Config.values.updates.branch];
        for (const b of ["main", "dev"])
            if (out.indexOf(b) < 0)
                out.push(b);
        return out;
    }

    readonly property string version: Device.version || "dev"

    readonly property string updateStatus: {
        switch (Update.state) {
        case Update.available:
            return `${Update.behind} new on ${Update.branch}`;
        case Update.downloading:
            return "getting it";
        case Update.downloaded:
            return "restart to finish";
        case Update.failed:
            return "could not look";
        }
        return Update.checking ? "looking" : "up to date";
    }

    readonly property bool updateReady: Update.state === Update.available
    readonly property string updateHeadline: `${Update.behind} new on ${Update.branch}`
    readonly property string updateDetail: Update.remoteHead ? Update.remoteHead.slice(0, 7) : "ready to get"

    readonly property int changeCount: root.changes.length

    readonly property string modeIcon: {
        const id = root.v("mode");
        return id && id !== "none" ? (Catalogue.MODES.find(m => m.id === id)?.icon ?? "") : "";
    }

    property bool completionsInstalled: false

    function setCompletions(on: bool): void {
        completer.command = ["banditshell", "completions", on ? "install" : "remove"];
        completer.running = true;
    }

    Process {
        id: completer

        onExited: root.probeCompletions()
    }

    function probeCompletions(): void {
        completionProbe.running = true;
    }

    Process {
        id: completionProbe

        command: ["banditshell", "completions", "status"]
        onExited: code => root.completionsInstalled = code < 2
    }

    Process {
        id: fontProbe

        command: ["fc-list", ":", "family", "spacing"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = [];
                const mono = [];
                for (const line of text.split("\n")) {
                    const parts = line.split(":");
                    const family = (parts[0] ?? "").split(",")[0].trim();
                    if (!family || family.startsWith("Material Symbols") || /Nerd Font Propo|Nerd Font$/.test(family) && !/Mono/.test(family))
                        continue;
                    if (all.indexOf(family) < 0)
                        all.push(family);
                    if (/spacing=(100|110)/.test(line) && mono.indexOf(family) < 0)
                        mono.push(family);
                }
                all.sort((a, b) => a.localeCompare(b));
                mono.sort((a, b) => a.localeCompare(b));
                const keep = (list, first) => [first].concat(list.filter(f => f !== first));
                root.fonts = keep(mono.length ? mono : all, Config.values.font.family);
                root.monoFonts = keep(mono, Config.values.files.terminal.font);
            }
        }
    }

    Process {
        id: layoutProbe

        command: ["hyprctl", "getoption", "input:kb_layout", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const codes = String(JSON.parse(text).str ?? "").split(",").map(c => c.trim()).filter(Boolean);
                    if (codes.length)
                        root.detectedLayouts = codes.map(c => ({
                                    name: c,
                                    code: c
                                }));
                } catch (e) {}
            }
        }
    }

    property bool woken: false

    function wake(): void {
        if (root.woken)
            return;
        root.woken = true;
        fontProbe.running = true;
        lidProbe.running = true;
        root.probeCompletions();
        if (Compositor.isHyprland)
            layoutProbe.running = true;
    }

    function save(): void {
        if (root.loaded)
            saver.restart();
    }

    function adopt(): void {
        if (!root.loaded || !Config.loaded)
            return;
        const moved = Object.keys(root.planned).filter(k => root.configBacked[k] && !root.plannedKey(k));
        if (!moved.length)
            return;
        const pairs = [];
        for (const k of moved) {
            const cfg = root.configBacked[k];
            if (JSON.stringify(Config.get(cfg)) !== JSON.stringify(root.lookup(Config.defaults, cfg)))
                continue;
            const t = root.transforms[k];
            pairs.push([cfg, t ? t.write(root.planned[k]) : root.planned[k]]);
        }
        if (pairs.length)
            Config.setMany(pairs);
        const next = Object.assign({}, root.planned);
        for (const k of moved)
            delete next[k];
        root.planned = next;
        root.save();
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            root.adopt();
        }
    }

    Process {
        id: lidProbe

        command: ["sh", "-c", "ls /proc/acpi/button/lid 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.lidSeen = text.trim() !== ""
        }
    }

    Timer {
        id: saver

        interval: 200
        onTriggered: root.flush()
    }

    function flush(): void {
        store.setText(JSON.stringify({
            planned: root.planned,
            ui: root.ui,
            changes: root.changes
        }, null, 2) + "\n");
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(store.text());
                root.planned = data.planned ?? {};
                root.ui = data.ui ?? {};
                root.changes = data.changes ?? [];
                root.modeWas = root.planned.modeWas ?? {};
            } catch (e) {
                console.warn(`SettingsState: ${root.path} is not valid, starting fresh`);
            }
            root.loaded = true;
            root.adopt();
        }

        onLoadFailed: root.loaded = true
    }
}
