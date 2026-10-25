pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "catalogue.js" as Catalogue
import "durations.js" as Durations
import "screens.js" as Screens

Singleton {
    id: root

    readonly property var planDefaults: ({})

    readonly property var uiDefaults: ({
            wallTarget: "everywhere",
            railFolded: false
        })

    readonly property bool railFolded: root.ui.railFolded ?? root.uiDefaults.railFolded

    property var planned: ({})
    property var ui: ({})
    property var changes: []
    property var wrote: null

    property bool loaded: false

    readonly property string path: `${Config.stateDir}/settings.json`

    readonly property var transforms: ({
            nightSched: {
                read: v => v === "times" ? "set times" : v,
                write: v => v === "set times" ? "times" : v
            },
            warmFrom: {
                read: v => Display.minutesOf(v),
                write: v => Display.clockOf(v)
            },
            warmTo: {
                read: v => Display.minutesOf(v),
                write: v => Display.clockOf(v)
            },
            dateFormat: {
                read: v => TimeFormat.styleOf(v),
                write: v => TimeFormat.styleOf(v)
            },
            notifTimeout: {
                read: v => Math.round(v / 1000),
                write: v => v * 1000
            },
            cloud: {
                read: v => (v || []).join(" "),
                write: v => String(v).trim().split(/\s+/).filter(Boolean)
            },
            termColours: {
                read: v => v === "theme" ? "theme" : JSON.stringify(v) === JSON.stringify(Config.defaults.files.terminal.palette) ? "one dark" : "custom",
                write: v => v === "theme" ? "theme" : Config.defaults.files.terminal.palette
            },
            iconMode: {
                read: v => v === "colour" ? "colour" : "mono",
                write: v => v === "colour" ? "colour" : "symbol"
            },
            roleSpeakers: {
                read: v => v,
                write: v => v
            },
            idleLock: {
                read: v => Durations.choiceFromMinutes(v),
                write: v => Durations.minutesFromChoice(v)
            },
            idleOff: {
                read: v => Durations.choiceFromMinutes(v),
                write: v => Durations.minutesFromChoice(v)
            },
            idleSuspend: {
                read: v => Durations.choiceFromMinutes(v),
                write: v => Durations.minutesFromChoice(v)
            },
            lowAction: {
                read: v => v === "nothing" ? v : `${v} at ${Battery.nearlyEmptyPercent}%`,
                write: v => String(v).split(" ")[0]
            },
            dndUntil: {
                read: v => Notifications.endsLabel(v),
                write: v => Notifications.deadlineFor(v)
            },
            rules: {
                read: v => v,
                write: v => Array.isArray(v) ? Notifications.rulesFromList(v) : v
            }
        })

    function rowOf(k: string): var {
        return Catalogue.ROW_BY_KEY[k] ?? null;
    }

    function cfgOf(k: string): string {
        const r = root.rowOf(k);
        return r?.cfg ?? "";
    }

    readonly property var configBacked: ({
            aiOn: "launcher.ai.enabled",
            aiBackend: "launcher.ai.backend",
            aiModel: "launcher.ai.model",
            aiAddress: "launcher.ai.openaiAddress",
            keepFresh: "network.keepListFresh",
            netCheck: "network.checkForInternet",
            portalUri: "network.portalUri",
            volStep: "volume.step",
            overAmp: "volume.boost",
            roleSpeakers: "audio.speakers",
            roleHeadphones: "audio.headphones",
            warmest: "screen.warmest",
            nightSched: "screen.schedule",
            warmFrom: "screen.warmFrom",
            warmTo: "screen.warmTo",
            clock24: "region.clock24",
            dateFormat: "region.dateFormat",
            reduceMotion: "access.lessMotion",
            largerText: "access.largerText",
            contrast: "access.moreContrast",
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
            fullscreenEdge: "edge.fullscreen",
            pushBorders: "compositor.pushBorders",
            bare: "edge.bare",
            anim: "anim.base",
            workspaceSlide: "anim.workspaceSlide",
            sidebarW: "sidebar.width",
            sbStyle: "sidebar.style",
            sbGlance: "sidebar.glance",
            sbBright: "sidebar.status.brightness",
            wsStyle: "sidebar.workspaces.style",
            iconMode: "sidebar.workspaces.iconMode",
            persistent: "sidebar.workspaces.persistent",
            trayMax: "sidebar.tray.max",
            tray: "sidebar.tray.enabled",
            specialsShown: "sidebar.workspaces.rack",
            sbClock: "sidebar.clock.style",
            sbClockSize: "sidebar.clock.size",
            sbClockWide: "sidebar.clock.wideStyle",
            sbClockWideSize: "sidebar.clock.wideSize",
            sbDate: "sidebar.clock.date",
            sbSound: "sidebar.status.sound",
            sbNet: "sidebar.status.network",
            sbBt: "sidebar.status.bluetooth",
            sbBatt: "sidebar.status.battery",
            sbUpdate: "sidebar.update",
            edgeLift: "windows.edge",
            dropMode: "windows.mode",
            followSent: "windows.follow",
            launcherW: "launcher.width",
            clipW: "clipboard.width",
            menuW: "menu.width",
            settingsW: "settings.width",
            concept: "launcher.concept",
            listPinned: "launcher.list.pinned",
            listRecents: "launcher.list.recents",
            hiddenFiles: "launcher.hiddenFiles",
            animatePreview: "launcher.animatePreview",
            polkitAgent: "polkit.agent",
            webSearch: "launcher.webSearch",
            contents: "launcher.contents",
            fallbackWeb: "launcher.fallbacks.web",
            fallbackYoutube: "launcher.fallbacks.youtube",
            fallbackWikipedia: "launcher.fallbacks.wikipedia",
            fallbackMaps: "launcher.fallbacks.maps",
            fallbackTerminal: "launcher.fallbacks.terminal",
            skinTone: "launcher.typing.skinTone",
            clipboardInSearch: "launcher.typing.clipboard",
            notificationsInSearch: "launcher.typing.notifications",
            onlineTranslate: "launcher.online.translate",
            onlineTranslateTo: "launcher.online.translateTo",
            onlineDefine: "launcher.online.define",
            onlinePackages: "launcher.online.packages",
            onlineGithub: "launcher.online.github",
            onlineBrowser: "launcher.online.browser",
            onlineSpeedtest: "launcher.online.speedtest",
            onlineVideos: "launcher.online.videos",
            systemBrightness: "launcher.systemControls.brightness",
            systemLowestBrightness: "launcher.systemControls.lowestBrightness",
            systemWifi: "launcher.systemControls.wifi",
            systemVpn: "launcher.systemControls.vpn",
            systemRecording: "launcher.systemControls.recording",
            systemRecordingFolder: "launcher.systemControls.recordingFolder",
            currency: "launcher.currency",
            launcherIcon: "launcher.iconSize",
            halfLife: "launcher.halfLifeDays",
            scriptsFolder: "launcher.powerTools.scriptsFolder",
            projectFolders: "launcher.powerTools.projectFolders",
            projectDepth: "launcher.powerTools.projectDepth",
            noteFolders: "launcher.powerTools.noteFolders",
            noteVault: "launcher.powerTools.noteVault",
            noteSkip: "launcher.powerTools.noteSkip",
            focusMinutes: "launcher.powerTools.focusMinutes",
            breakMinutes: "launcher.powerTools.breakMinutes",
            longBreakMinutes: "launcher.powerTools.longBreakMinutes",
            roundsBeforeLongBreak: "launcher.powerTools.roundsBeforeLongBreak",
            devOpsSsh: "launcher.devOps.ssh",
            devOpsPorts: "launcher.devOps.ports",
            devOpsServices: "launcher.devOps.services",
            devOpsContainers: "launcher.devOps.containers",
            devOpsPhone: "launcher.devOps.phone",
            passwordLength: "launcher.utilities.passwordLength",
            reminderHour: "launcher.utilities.reminderHour",
            clip: "clipboard.record",
            clipMax: "clipboard.maxEntries",
            clipText: "clipboard.maxText",
            clipBlob: "clipboard.maxBlob",
            notifTimeout: "notifications.timeout",
            notifPopups: "notifications.maxPopups",
            notifHistory: "notifications.maxHistory",
            notifPlace: "notifications.placement",
            islandDownloads: "island.downloads",
            islandMusic: "island.nowPlaying",
            islandGlance: "island.glanceSeconds",
            kernelEvery: "packages.interval",
            upgradeCmd: "packages.upgrade",
            dnd: "notifications.quiet",
            dndUntil: "notifications.quietUntil",
            dndAlarms: "notifications.letAlarms",
            dndNightly: "notifications.nightly",
            rules: "notifications.rules",
            alerts: "sound.alerts",
            alertSet: "sound.alertSet",
            alertVol: "sound.alertVolume",
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
            greyCap: "usage.greyAtCap",
            breaks: "usage.breaks",
            breakEvery: "usage.breakEvery",
            idleLock: "idle.lock",
            idleOff: "idle.screensOff",
            idleSuspend: "idle.sleep",
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
            boardRepeat: "tablet.repeat",
            pen: "pen.enabled",
            aspectLock: "pen.aspectLock",
            branch: "updates.branch",
            remote: "updates.remote",
            updEvery: "updates.interval",
            sourceEdits: "sourceEdits.acknowledged",
            chargeLimit: "battery.holdCharge",
            chargeMax: "battery.holdAt",
            lowWarn: "battery.warnAt",
            lowAction: "battery.nearlyEmpty",
            lidBattery: "power.lid.onBattery",
            lidPlugged: "power.lid.pluggedIn",
            lidDocked: "power.lid.docked",
            sheetShape: "cheatsheet.shape",
            penBtn1: "pen.lowerButton",
            penBtn2: "pen.upperButton"
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
        case "autoZone":
            return Localisation.zoneFollowsNetwork;
        case "zone":
            return Clock.localZone;
        case "lang":
            return Localisation.language;
        case "region":
            return Localisation.formatsId;
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
            return Tunnels.anyOn;
        case "hotspot":
            return Hotspot.on;
        case "hotspotName":
            return Hotspot.ssid;
        case "hotspotPass":
            return Hotspot.password;
        case "aiKey":
            return Assistant.savedKey;
        case "hotspotBand":
            return Hotspot.band;
        case "warm":
            return Display.warm;
        case "darkMode":
            return DarkMode.dark;
        case "saver":
            return root.v("profile") === "saver";
        case "profile":
            return PowerProfile.profile;
        case "mode":
            return Modes.current;
        case "defBrowser":
        case "defFiles":
        case "defTerm":
        case "defMail":
        case "defImages":
        case "defVideo":
            return DefaultApps.valueOf(k);
        case "startup":
            return StartupApps.entries;
        case "kbDelay":
        case "kbRate":
        case "mouseSpeed":
        case "naturalScroll":
        case "tapClick":
            return root.hyprRead(k);
        case "layout":
            return root.layoutId;
        case "padSpeed":
            return root.padSpeedNow;
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

    function resettable(k: string): bool {
        const cfg = root.configBacked[k];
        if (!cfg || !Catalogue.resettable(root.rowOf(k)))
            return false;
        const t = root.transforms[k];
        if (!t)
            return true;
        const raw = Config.get(cfg);
        return JSON.stringify(t.write(t.read(raw))) === JSON.stringify(raw);
    }

    function offersReset(k: string): bool {
        return root.resettable(k) && Catalogue.changed(root.v(k), root.defaultOf(k));
    }

    function reset(k: string): void {
        const r = root.rowOf(k);
        const before = root.v(k);
        root.set(k, root.defaultOf(k));
        const after = root.v(k);
        if (r?.kind === "text" && !root.muteLog && JSON.stringify(after) !== JSON.stringify(before))
            root.log(k, r, before, after);
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
        case "darkMode":
            return DarkMode.set(value);
        case "autoZone":
            if (value && !Localisation.geoclueInstalled) {
                root.denied = true;
                root.refused("zone from network needs geoclue, which is not installed", "");
                return;
            }
            return Localisation.setAutomaticZone(value);
        case "zone":
            return Localisation.setZone(value);
        case "lang":
            return root.setLocale(value, Localisation.languages, Localisation.setLanguage);
        case "region":
            return root.setLocale(value, Localisation.formats, Localisation.setFormats);
        case "theme":
            if (!ThemeSwitcher.available) {
                root.denied = true;
                root.refused(ThemeSwitcher.unavailableWhy, "");
                return;
            }
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
        case "profile":
            if (PowerProfile.available)
                PowerProfile.set(value);
            else
                root.denied = true;
            return;
        case "restore":
            return SettingsRestore.putBack(value);
        case "mode":
            return root.setMode(value);
        case "kbDelay":
        case "kbRate":
        case "mouseSpeed":
        case "naturalScroll":
        case "tapClick":
        case "layout":
            return root.hyprWrite(k, value);
        case "padSpeed":
            return root.writePadSpeed(value);
        case "vpnFirst":
            return Tunnels.setFirst(value);
        case "hotspot":
            return Hotspot.setOn(value);
        case "hotspotName":
            return Hotspot.setName(value);
        case "hotspotPass":
            return Hotspot.setPassword(value);
        case "aiKey":
            return Assistant.setKey(value);
        case "hotspotBand":
            return Hotspot.setBand(value);
        case "defBrowser":
        case "defFiles":
        case "defTerm":
        case "defMail":
        case "defImages":
        case "defVideo":
            return DefaultApps.choose(k, value);
        case "startup":
            if (StartupApps.needsHyprlandEdits(value) && !root.edits())
                return;
            return StartupApps.change(value);
        }
        if (root.plannedKey(k))
            root.plan(k, value);
    }

    function setLocale(id: string, options: var, apply: var): void {
        if (Localisation.hasLocale(id))
            return apply(id);
        root.denied = true;
        root.refused(`${Localisation.labelOf(options, id)} is not set up on this machine`, "");
    }

    Connections {
        target: Localisation

        function onFailed(why: string): void {
            root.refused(why, "");
        }

        function onZoneMoved(zone: string): void {
            SettingsView.drop(`the zone is ${zone} now`, "public", {
                label: "restart the shell",
                run: () => Update.restart()
            });
        }
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
        if (k === "alertSet" || k === "alertVol")
            AlertSounds.preview();
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
        if (!m || Modes.current === id)
            return;
        root.muteLog = true;
        for (const key of Object.keys(Modes.was))
            root.set(key, Modes.was[key]);
        const was = {};
        for (const key of Object.keys(m.set)) {
            const before = root.v(key);
            if (JSON.stringify(before) === JSON.stringify(m.set[key]))
                continue;
            was[key] = before;
            root.set(key, m.set[key]);
        }
        Modes.enter(id, m.icon, was);
        root.muteLog = false;
    }

    function screenOn(name: string): bool {
        return !root.stagedSpec(name)?.disabled;
    }

    function screenMirror(name: string): string {
        return root.stagedSpec(name)?.mirror ?? "";
    }

    function stagedSpecs(): var {
        const out = {};
        for (const m of Monitors.outputs) {
            const spec = root.stagedSpec(m.name);
            if (spec)
                out[m.name] = spec;
        }
        return out;
    }

    function screenValue(sub: string): var {
        const name = Monitors.selected;
        const spec = root.stagedSpec(name);
        switch (sub) {
        case "on":
            return root.screenOn(name);
        case "mirror":
            return root.screenMirror(name);
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
        if (!spec)
            return "";
        if (spec.disabled)
            return `disable${root.stage[name] ? " · not applied yet" : ""}`;
        return `${spec.mode}, ${spec.position}, ${Math.round(spec.scale * 100) / 100}${spec.transform ? `, transform ${spec.transform}` : ""}${spec.mirror ? `, mirror, ${spec.mirror}` : ""}${root.stage[name] ? " · not applied yet" : ""}`;
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
                const planned = Monitors.plan(root.stagedSpecs(), name, sub === "on" ? {
                    disabled: !value
                } : {
                    mirror: value
                });
                if (planned.why) {
                    root.denied = true;
                    root.refused(planned.why, "");
                    return;
                }
                root.restage(planned.fields);
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
        return ["scr:on", "scr:mirror", "scr:res", "scr:hz", "scr:scale", "scr:rot", "scr:vrr"].indexOf(k) >= 0;
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
        if (key === "disabled")
            return !!a === !!b;
        if (key === "mirror")
            return (a || "") === (b || "");
        return String(a) === String(b);
    }

    function restage(fields: var): void {
        const next = root.stagedWith(root.stage, fields);
        const shift = Screens.anchor(Monitors.outputs.map(m => Screens.rectOf(m.name, Object.assign({}, root.liveSpec(m.name) ?? {}, next[m.name] ?? {}))));
        const anchored = {};
        for (const name of Object.keys(shift))
            anchored[name] = {
                position: `${shift[name].x}x${shift[name].y}`
            };
        root.stage = root.stagedWith(next, anchored);
    }

    function stagedWith(stage: var, fields: var): var {
        const next = Object.assign({}, stage);
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
        return next;
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
            vrr: "vrr",
            on: "disabled",
            mirror: "mirror"
        }[sub];
        const mine = root.stage[Monitors.selected];
        if (!mine || mine[field] === undefined)
            return "";
        const live = root.liveSpec(Monitors.selected);
        if (sub === "res" && live && String(live.mode).split("@")[0] === String(mine.mode).split("@")[0])
            return "";
        if (sub === "hz" && live && String(live.mode).split("@")[1] === String(mine.mode).split("@")[1])
            return "";
        return "needs Apply";
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
        return ["mode", "position", "scale", "transform", "vrr", "disabled", "mirror"].some(key => !root.sameField(key, a[key], b[key]));
    }

    function restore(specs: var): void {
        if (!root.edits())
            return;
        const list = [];
        for (const name of Object.keys(specs ?? {})) {
            const live = root.liveSpec(name);
            if (live && root.differs(live, specs[name]))
                list.push(specs[name]);
        }
        const why = Monitors.applySpecs(list);
        if (why)
            root.refused(why, "");
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
            if (!root.sameField("disabled", a.disabled, b.disabled))
                what.push(b.disabled ? "turned off" : "turned on");
            if (!root.sameField("mirror", a.mirror, b.mirror))
                what.push(b.mirror ? `mirrors ${b.mirror}` : "stopped mirroring");
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
            if (["mode", "scale", "transform", "disabled", "mirror"].some(key => !root.sameField(key, live[key], next[key])))
                risky = true;
        }
        if (!Object.keys(after).length) {
            root.stage = {};
            return;
        }
        const why = Monitors.applySpecs(Object.values(after));
        if (why)
            return root.refused(why, "");
        root.stage = {};
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
        Monitors.applySpecs(Object.values(c.before));
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
        const entry = HyprConfig.bandEntry(name);
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
    readonly property var screensOn: root.monitorNames.filter(n => root.screenOn(n))
    readonly property string selMon: Monitors.selected
    readonly property bool onlyOn: root.screenOn(Monitors.selected) && root.screensOn.length === 1
    readonly property var mirrorChoices: Monitors.mirrorChoices(root.stagedSpecs(), Monitors.selected)

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

    readonly property int tunnelCount: Tunnels.list.length

    readonly property string vpnOn: Tunnels.activeName

    readonly property string hotspotStatus: Hotspot.status
    readonly property string alertsDetail: AlertSounds.available ? "" : "pw-play is not installed, so alerts stay silent"
    readonly property bool hotspotBlocked: Hotspot.blocker !== "" && !Hotspot.on
    readonly property string hotspotPasswordTrouble: Hotspot.passwordTrouble
    readonly property string wifiState: Hotspot.active ? "running your hotspot" : root.wifiNet || "not connected"

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
    readonly property bool hasLid: Lid.present
    readonly property bool hasDarkMode: DarkMode.available
    readonly property bool hibernatePossible: Suspension.hibernatePossible
    readonly property int nearlyEmptyPercent: Battery.nearlyEmptyPercent
    readonly property var profileChoices: PowerProfile.choices
    readonly property string profileTrouble: PowerProfile.trouble
    readonly property bool chargeSupported: !ChargeLimit.probed || ChargeLimit.supported
    readonly property string chargeTrouble: ChargeLimit.trouble
    readonly property int trayCount: Tray.items.length
    readonly property int starredCount: Object.keys(Config.values.launcher.starred ?? {}).length
    readonly property var currencies: Currency.codes
    readonly property var noteVaults: [["", "the one Obsidian opened last"]].concat(Notes.vaults.map(v => [v.path, v.name]))

    readonly property var aiModels: [["", "automatic"]].concat(Assistant.models.map(m => [m, Assistant.labelOf(m)]))
    readonly property string aiNote: ({
            off: "off",
            unknown: "",
            ready: Assistant.local ? `${Assistant.modelName} on this computer` : `${Assistant.modelName} over the internet`,
            nokey: "no API key yet",
            missing: "Ollama is not installed",
            installing: "installing Ollama",
            stopped: "Ollama is not running",
            starting: "starting Ollama",
            empty: "no model downloaded yet",
            pulling: `downloading · ${Assistant.progress}%`,
            unreachable: "Ollama is not answering"
        })[Assistant.phase] ?? ""
    readonly property string aiAddressNote: Assistant.keyHeld ? "plain http, so the key is not sent" : ""
    readonly property string aiModelNote: Assistant.modelName ? `${Assistant.modelName} in use` : ""

    readonly property string polkitNote: Polkit.serving ? "the shell asks" : "another program asks"
    readonly property string ratesNote: Currency.date ? `rates from ${Currency.date}` : "no rates yet"

    readonly property bool clipseImported: !Config.values.clipboard.importClipse
    readonly property int clipseWaiting: Clipboard.clipseWaiting
    readonly property string clipseDetail: root.clipseWaiting ? `${root.clipseWaiting} entries waiting` : root.clipseImported ? "brought over" : "nothing waiting in clipse"

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
        return best ? `next alarm ${TimeFormat.time(new Date(best), false)}` : "no alarms set";
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

    readonly property var usageApps: {
        const live = UsageApps.revision;
        const now = root.tick;
        return UsageApps.appsFor(new Date(now)).slice(0, 5);
    }

    readonly property bool idleHandled: Idle.handledElsewhere
    readonly property string idleHandler: Idle.handler

    readonly property var hyprOptions: ({
            kbDelay: {
                path: "input:repeat_delay",
                integer: true,
                fallback: 600
            },
            kbRate: {
                path: "input:repeat_rate",
                integer: true,
                fallback: 25
            },
            mouseSpeed: {
                path: "input:sensitivity",
                fallback: 0
            },
            naturalScroll: {
                path: "input:touchpad:natural_scroll",
                fallback: false
            },
            tapClick: {
                path: "input:touchpad:tap-to-click",
                fallback: true
            },
            layout: {
                path: "general:layout",
                fallback: "dwindle"
            },
            kbLayout: {
                path: "input:kb_layout",
                fallback: "us"
            },
            kbVariant: {
                path: "input:kb_variant",
                fallback: ""
            },
            kbOptions: {
                path: "input:kb_options",
                fallback: ""
            }
        })

    readonly property var hyprProbeCommand: ["hyprctl", "-j", "--batch", Object.keys(root.hyprOptions).map(k => `getoption ${root.hyprOptions[k].path}`).concat(["getoption scrolling:column_width"]).join(" ; ")]

    property var hyprValues: ({})
    property var hyprQueue: []
    property var hyprWriting: null
    property var hyprRecent: ({})
    property bool scrollingCore: false
    property bool optionsProbed: false
    property bool pluginsProbed: false
    property var hyprPlugins: []
    property var hyprMice: []
    property var pointers: []
    property var liveBinds: []
    property bool switchBindWanted: false

    readonly property string switchChord: "SUPER + SPACE"

    readonly property var layoutPool: [["danish", "dk"], ["english (us)", "us"], ["english (uk)", "gb"], ["german", "de"], ["norwegian", "no"], ["swedish", "se"], ["french", "fr"], ["colemak", "us(colemak)"]]

    readonly property var switchOptions: ({
            "grp:switch": "right alt",
            "grp:alt_shift_toggle": "alt + shift",
            "grp:ctrl_shift_toggle": "ctrl + shift",
            "grp:win_space_toggle": "super + space",
            "grp:alt_space_toggle": "alt + space",
            "grp:ctrl_space_toggle": "ctrl + space",
            "grp:caps_toggle": "caps lock",
            "grp:menu_toggle": "menu"
        })

    function hyprAsked(k: string): var {
        const queued = root.hyprQueue.filter(e => e.key === k);
        if (queued.length)
            return queued[queued.length - 1].value;
        if (root.hyprWriting?.key === k)
            return root.hyprWriting.value;
        return root.hyprRecent[k];
    }

    function hyprRead(k: string): var {
        const asked = root.hyprAsked(k);
        if (asked !== undefined)
            return asked;
        const spec = root.hyprOptions[k];
        const live = root.hyprValues[spec.path];
        return live !== undefined ? live : spec.fallback;
    }

    function hyprSchedule(): void {
        hyprFlush.restart();
    }

    function hyprLabel(k: string): string {
        const names = {
            layout: "Layout",
            kbLayout: "Layouts",
            kbVariant: "Layouts"
        };
        const row = root.rowOf(k);
        return names[k] ?? (row ? Catalogue.labelOf(row) : k);
    }

    function hyprRefusal(k: string): string {
        return HyprConfig.optionRefusal(root.hyprOptions[k].path, "");
    }

    function hyprEnqueue(entries: var): void {
        const ids = entries.map(e => e.id);
        root.hyprQueue = root.hyprQueue.filter(e => ids.indexOf(e.id) < 0).concat(entries);
        root.hyprSchedule();
    }

    function hyprWrite(k: string, value: var): void {
        if (!root.edits())
            return;
        const why = root.hyprRefusal(k);
        if (why) {
            root.denied = true;
            root.refused(why, "");
            return;
        }
        const spec = root.hyprOptions[k];
        root.hyprEnqueue([
            {
                id: k,
                key: k,
                path: spec.path,
                device: "",
                value: spec.integer ? Math.round(value) : value
            }
        ]);
    }

    function hyprNext(): void {
        if (root.hyprWriting || (!root.hyprQueue.length && !root.switchBindWanted))
            return;
        if (HyprConfig.applying || !HyprConfig.scanned)
            return root.hyprSchedule();
        if (!root.hyprQueue.length) {
            root.switchBindWanted = false;
            return root.addSwitchBind();
        }
        const entry = root.hyprQueue[0];
        root.hyprQueue = root.hyprQueue.slice(1);
        root.hyprWriting = entry;
        HyprConfig.setOption(entry.path, entry.value, entry.device);
    }

    function hyprSettled(path: string, device: string, ok: bool, said: string): void {
        const done = root.hyprWriting;
        if (!done || done.path !== path || done.device !== device)
            return;
        root.hyprWriting = null;
        if (ok) {
            root.hyprRecent = Object.assign({}, root.hyprRecent, {
                [done.key]: done.value
            });
            hyprRecentClear.restart();
            if (done.then === "bind")
                root.switchBindWanted = true;
        } else {
            root.hyprQueue = root.hyprQueue.filter(e => e.group === undefined || e.group !== done.group);
            root.refused(`${root.hyprLabel(done.key)} was not saved · ${said}`, "");
            root.probeHypr();
        }
        if (root.hyprQueue.length || root.switchBindWanted)
            root.hyprSchedule();
    }

    Timer {
        id: hyprFlush

        interval: 400
        onTriggered: root.hyprNext()
    }

    Timer {
        id: hyprRecentClear

        interval: 2500
        onTriggered: root.hyprRecent = ({})
    }

    Connections {
        target: HyprConfig

        function onOptionSettled(path: string, device: string, ok: bool, said: string): void {
            root.hyprSettled(path, device, ok, said);
        }

        function onWriteFailed(said: string): void {
            root.refused(`not saved · ${said}`, "");
        }
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            if (root.woken)
                root.probeHypr();
        }
    }

    function probeHypr(): void {
        if (!Compositor.isHyprland)
            return;
        optionProbe.running = true;
        pluginProbe.running = true;
        mouseProbe.running = true;
        bindProbe.running = true;
        pointerProbe.running = true;
    }

    Process {
        id: optionProbe

        command: root.hyprProbeCommand
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.split("\n")) {
                    if (!line.trim().startsWith("{"))
                        continue;
                    try {
                        const o = JSON.parse(line);
                        const raw = o.bool ?? o.int ?? o.float ?? o.str;
                        if (o.option === "scrolling:column_width")
                            root.scrollingCore = true;
                        else if (raw !== undefined)
                            next[o.option] = raw === "[[EMPTY]]" ? "" : raw;
                    } catch (e) {}
                }
                root.hyprValues = next;
                root.optionsProbed = true;
            }
        }
    }

    Process {
        id: pluginProbe

        command: ["hyprctl", "plugin", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hyprPlugins = text.split("\n").map(line => /^\s*Plugin\s+(.+?)\s+by\s/.exec(line)?.[1]).filter(Boolean);
                root.pluginsProbed = true;
            }
        }
    }

    Process {
        id: mouseProbe

        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.hyprMice = (JSON.parse(text).mice ?? []).map(m => m.name);
                } catch (e) {}
            }
        }
    }

    Process {
        id: bindProbe

        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.liveBinds = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    Process {
        id: pointerProbe

        command: ["python3", Quickshell.shellPath("scripts/pointing-devices.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.pointers = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    readonly property string layoutRaw: String(root.hyprRead("layout"))
    readonly property string layoutId: ["dwindle", "master", "scrolling", "hy3"].indexOf(root.layoutRaw) >= 0 ? root.layoutRaw : "custom"
    readonly property string customInUse: root.layoutId === "custom" ? root.layoutRaw.replace(/^lua:/, "") : ""

    readonly property bool layoutsProbed: root.optionsProbed && root.pluginsProbed

    function layoutAvailable(id: string): bool {
        if (!root.layoutsProbed)
            return true;
        if (id === "scrolling")
            return root.scrollingCore || root.hyprPlugins.some(n => /scrolling/i.test(n));
        if (id === "hy3")
            return root.hyprPlugins.some(n => /hy3/i.test(n));
        return true;
    }

    function layoutHowTo(id: string): string {
        if (id === "scrolling")
            return "built into newer hyprland, or the hyprscrolling plugin · hyprpm add https://github.com/hyprwm/hyprland-plugins";
        if (id === "hy3")
            return "a plugin, not loaded · hyprpm add https://github.com/outfoxxed/hy3, then hyprpm enable hy3";
        return "";
    }

    function layoutName(code: string): string {
        return root.layoutPool.find(p => p[1] === code)?.[0] ?? code;
    }

    function layoutsOf(layouts: string, variants: string): var {
        const variantList = String(variants).split(",").map(v => v.trim());
        return String(layouts).split(",").map(c => c.trim()).filter(Boolean).map((c, i) => {
            const code = variantList[i] ? `${c}(${variantList[i]})` : c;
            return {
                name: root.layoutName(code),
                code
            };
        });
    }

    readonly property var kbLayouts: root.layoutsOf(root.hyprRead("kbLayout"), root.hyprRead("kbVariant"))

    function setLayouts(list: var): bool {
        if (!list.length || !root.edits())
            return false;
        const why = root.hyprRefusal("kbLayout") || root.hyprRefusal("kbVariant");
        if (why) {
            root.refused(why, "");
            return false;
        }
        const heads = list.map(l => l.code.replace(/\(.*\)$/, ""));
        const variants = list.map(l => /\((.*)\)$/.exec(l.code)?.[1] ?? "");
        const entry = (key, value, extra) => Object.assign({
                id: key,
                key,
                group: "layouts",
                path: root.hyprOptions[key].path,
                device: "",
                value
            }, extra);
        const layout = entry("kbLayout", heads.join(","));
        const variant = entry("kbVariant", variants.some(Boolean) ? variants.join(",") : "");
        const growing = list.length >= root.kbLayouts.length;
        const changes = [layout, variant].filter(e => String(e.value) !== String(root.hyprRead(e.key)));
        if (!changes.length)
            return true;
        const ordered = growing ? changes : changes.slice().reverse();
        if (list.length > 1)
            ordered[ordered.length - 1].then = "bind";
        root.hyprEnqueue(ordered);
        return true;
    }

    readonly property var switchBind: HyprConfig.binds.find(b => !b.dynamic && /switchxkblayout/.test(b.expr ?? "")) ?? null

    readonly property string switchOption: {
        const names = String(root.hyprRead("kbOptions")).split(/[,\s]+/).filter(o => o.startsWith("grp:"));
        return names.length ? (root.switchOptions[names[0]] ?? names[0]) : "";
    }

    readonly property bool switchChordLive: root.liveBinds.some(b => b.modmask === 64 && String(b.key).toLowerCase() === "space" && !b.submap)

    readonly property string layoutSwitchNote: {
        const chord = root.switchChord.toLowerCase();
        if (root.switchBind)
            return `switch with ${root.switchBind.chord.toLowerCase()}`;
        if (root.switchOption)
            return `switch with ${root.switchOption}`;
        const holder = HyprConfig.holderOf(root.switchChord);
        if (holder)
            return `${chord} is taken · ${holder.description || holder.action || "another bind"}`;
        return root.switchChordLive ? `${chord} is taken` : "no key switches layouts yet";
    }

    function addSwitchBind(): void {
        if (root.switchBind || root.switchChordLive || HyprConfig.holderOf(root.switchChord) || root.kbLayouts.length < 2)
            return;
        const home = HyprConfig.files.find(f => f.binds.some(b => !b.dynamic && !b.submap))?.name ?? HyprConfig.shortName(HyprConfig.configPath);
        HyprConfig.addBind(home, {
            chord: root.switchChord,
            expr: "hl.dsp.exec_cmd(\"hyprctl switchxkblayout all next\")",
            description: "Switch keyboard layout"
        });
    }

    function hyprDeviceName(label: string): string {
        const plain = text => String(text).toLowerCase().replace(/[^a-z0-9]+/g, "-");
        return root.hyprMice.find(n => plain(n) === plain(label)) ?? String(label).toLowerCase().replace(/\s+/g, "-");
    }

    readonly property var touchpads: root.pointers.filter(p => p.kind === "touchpad").map(p => ({
                label: p.name,
                name: root.hyprDeviceName(p.name),
                widthMm: p.widthMm,
                heightMm: p.heightMm
            })).filter(t => !root.hyprMice.length || root.hyprMice.indexOf(t.name) >= 0)

    readonly property real padRatio: {
        const shaped = root.touchpads.find(t => t.widthMm > 0 && t.heightMm > 0);
        return shaped ? Math.max(1, Math.min(2.2, shaped.widthMm / shaped.heightMm)) : 1.5;
    }

    readonly property real padSpeedNow: {
        const asked = root.hyprAsked("padSpeed");
        if (asked !== undefined)
            return asked;
        const own = root.touchpads.length ? HyprConfig.optionValue("input:sensitivity", root.touchpads[0].name) : undefined;
        return own !== undefined ? own : root.hyprRead("mouseSpeed");
    }

    function writePadSpeed(value: var): void {
        if (!root.touchpads.length || !root.edits()) {
            root.denied = true;
            return;
        }
        const why = root.touchpads.map(t => HyprConfig.optionRefusal("input:sensitivity", t.name)).find(Boolean);
        if (why) {
            root.denied = true;
            root.refused(why, "");
            return;
        }
        root.hyprEnqueue(root.touchpads.map(t => ({
                    id: `padSpeed:${t.name}`,
                    key: "padSpeed",
                    path: "input:sensitivity",
                    device: t.name,
                    value: +value
                })));
    }

    readonly property int keyCount: HyprConfig.binds.length + Object.keys(Config.values.files.keys ?? {}).length

    readonly property string repeatDetail: `${Config.values.tablet.repeatDelay} ms, then every ${Config.values.tablet.repeatInterval}`

    readonly property string penButtonNote: {
        if (!PenButtons.remapped)
            return "as the pen sends them";
        switch (PenButtons.state) {
        case "ready":
            return "remapped";
        case "denied":
            return "can't reach the pen · see the log";
        case "gone":
            return "pen not found";
        }
        return "starting";
    }

    readonly property string penName: Config.values.pen.device.replace(/-pen$/, "").replace(/-/g, " ")

    readonly property int batteryPct: Battery.percent
    readonly property bool healthKnown: Battery.healthKnown
    readonly property int healthPct: Math.round(Battery.health)

    readonly property int startupOn: StartupApps.entries.filter(s => s.on).length

    function appsFor(k: string): var {
        return DefaultApps.offersFor(k);
    }

    function defaultName(k: string): string {
        return DefaultApps.nameFor(k);
    }

    function defaultNote(k: string): string {
        return DefaultApps.noteFor(k);
    }

    readonly property var zoneChoices: Localisation.zoneChoices
    readonly property var languageChoices: Localisation.languageChoices
    readonly property var formatChoices: Localisation.formatChoices

    readonly property string languageLabel: Localisation.labelOf(Localisation.languages, Localisation.language)
    readonly property string formatsLabel: Localisation.labelOf(Localisation.formats, Localisation.formatsId)

    readonly property var dateChoices: TimeFormat.styles.map(id => [id, TimeFormat.example(id, new Date(root.tick))])

    readonly property string timeExample: TimeFormat.time(new Date(root.tick), false)

    readonly property string moneyExample: ({
            "da_DK.UTF-8": "1.234,56 kr.",
            "en_GB.UTF-8": "£1,234.56",
            "en_US.UTF-8": "$1,234.56"
        })[Localisation.formatsId] ?? ""

    readonly property int largerBase: Config.values.access.largerBase

    function minuteText(minutes: int): string {
        return TimeFormat.clock(Math.floor(minutes / 60), minutes % 60);
    }

    readonly property string scheduleDetail: {
        const mode = Config.values.screen.schedule;
        const w = Display.warmWindow;
        if (mode === "off")
            return "";
        if (!w)
            return mode === "sunset" ? "needs a place · pick a zone below" : "pick two different times";
        if (!isFinite(w.start) || !isFinite(w.end))
            return mode === "sunset" ? "the sun does not set here now" : "";
        const span = `${TimeFormat.time(new Date(w.start), false)} to ${TimeFormat.time(new Date(w.end), false)}`;
        return mode === "sunset" ? `tonight ${span}` : span;
    }

    readonly property string zoneSuggested: Localisation.suggestedZone

    readonly property string autoZoneDetail: !Localisation.geoclueProbed ? "" : !Localisation.geoclueInstalled ? "needs geoclue, which is not installed" : "from where you are · password needed"

    readonly property var branches: {
        const out = [Config.values.updates.branch];
        for (const b of ["main", "dev"])
            if (out.indexOf(b) < 0)
                out.push(b);
        return out;
    }

    readonly property string version: Update.version || Device.version || "dev"

    readonly property string followedBranch: Update.branch

    readonly property string updateStatus: {
        switch (Update.state) {
        case Update.available:
            return `${Update.behind} new on ${Update.branch}`;
        case Update.downloading:
            return "getting it";
        case Update.verifying:
            return "checking it loads";
        case Update.restarting:
            return "restarting";
        case Update.updated:
            return "updated";
        case Update.rolledback:
            return "went back";
        case Update.failed:
            return "could not look";
        }
        return Update.checking ? "looking" : "up to date";
    }

    readonly property bool updateReady: Update.state === Update.available
    readonly property string updateHeadline: `${Update.behind} new on ${Update.branch}`
    readonly property string updateDetail: Update.remoteHead ? Update.remoteHead.slice(0, 7) : "ready to get"

    readonly property int changeCount: root.changes.length

    readonly property string modeIcon: Modes.icon

    readonly property string quietNote: Notifications.note
    readonly property string quietEndsNote: Notifications.endsNote
    readonly property string nightWindow: `${Notifications.nightFrom} to ${Notifications.nightTo}`

    property bool completionsInstalled: false

    function setCompletions(on: bool): void {
        completer.command = [`${Quickshell.shellDir}/cli/banditshell`, "completions", on ? "install" : "remove"];
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

        command: [`${Quickshell.shellDir}/cli/banditshell`, "completions", "status"]
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

    property bool woken: false

    function wake(): void {
        if (root.woken)
            return;
        root.woken = true;
        fontProbe.running = true;
        root.probeCompletions();
        root.probeHypr();
    }

    function upgradedChange(change: var): var {
        const cfg = root.configBacked[change?.k];
        const r = root.rowOf(change?.k);
        if (!cfg || !r)
            return change;
        const old = Config.upgradeValue(cfg, change.old);
        const value = Config.upgradeValue(cfg, change.v);
        if (old === change.old && value === change.v)
            return change;
        return Object.assign({}, change, {
            old,
            v: value,
            from: root.shown(r, old),
            to: root.shown(r, value)
        });
    }

    readonly property var carriedPlans: ["mode", "modeWas", "screens"]

    function withoutRetired(planned: var): var {
        const kept = {};
        for (const k of Object.keys(planned))
            if (root.plannedKey(k) || root.configBacked[k] || root.carriedPlans.includes(k))
                kept[k] = planned[k];
        return kept;
    }

    function save(): void {
        if (root.loaded)
            saver.restart();
    }

    function foldRail(folded: bool): void {
        root.ui = Object.assign({}, root.ui, {
            railFolded: folded
        });
        root.save();
    }

    function adoptMode(): void {
        if (!root.loaded || !Modes.loaded || root.planned.mode === undefined)
            return;
        const id = String(root.planned.mode);
        Modes.adopt(id, Catalogue.MODES.find(m => m.id === id)?.icon ?? "", root.planned.modeWas);
        const next = Object.assign({}, root.planned);
        delete next.mode;
        delete next.modeWas;
        root.planned = next;
        root.save();
    }

    Connections {
        target: Modes

        function onLoadedChanged(): void {
            root.adoptMode();
        }
    }

    function adopt(): void {
        root.adoptMode();
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
            const value = t ? t.write(root.planned[k]) : root.planned[k];
            if (Config.accepts(cfg, value))
                pairs.push([cfg, value]);
            else
                console.warn(`SettingsState: the old planned ${k} does not fit ${cfg}, so it is left behind`);
        }
        if (pairs.length)
            Config.setMany(pairs);
        const next = Object.assign({}, root.planned);
        for (const k of moved)
            delete next[k];
        root.planned = next;
        root.save();
    }

    function carryScreens(): void {
        const old = root.planned.screens;
        if (!root.loaded || !old || !Monitors.outputs.length)
            return;
        const specs = root.stagedSpecs();
        const fields = {};
        const take = (name, change) => {
            const planned = Monitors.plan(specs, name, change);
            for (const n of Object.keys(planned.fields)) {
                specs[n] = Object.assign({}, specs[n], planned.fields[n]);
                fields[n] = Object.assign({}, fields[n] ?? {}, planned.fields[n]);
            }
        };
        for (const name of Object.keys(old))
            if (specs[name] && old[name].on === false && !specs[name].disabled)
                take(name, {
                    disabled: true
                });
        for (const name of Object.keys(old))
            if (specs[name] && old[name].mirror && old[name].mirror !== specs[name].mirror)
                take(name, {
                    mirror: old[name].mirror
                });
        root.restage(fields);
        const next = Object.assign({}, root.planned);
        delete next.screens;
        root.planned = next;
        root.save();
    }

    Connections {
        target: Monitors

        function onOutputsChanged(): void {
            root.carryScreens();
        }

        function onFailed(output: string, said: string): void {
            root.refused(`${output} was not changed · ${said}`, "");
        }
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            root.adopt();
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
                const stored = data.planned ?? {};
                root.planned = root.withoutRetired(stored);
                if (Object.keys(root.planned).length !== Object.keys(stored).length)
                    saver.restart();
                root.ui = data.ui ?? {};
                root.changes = (data.changes ?? []).map(c => root.upgradedChange(c));
            } catch (e) {
                console.warn(`SettingsState: ${root.path} is not valid, starting fresh`);
            }
            root.loaded = true;
            root.adopt();
            root.carryScreens();
        }

        onLoadFailed: root.loaded = true
    }
}
