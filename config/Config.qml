pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "configuration.js" as Configuration

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/banditshell`
    readonly property string path: `${dir}/config.json`

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/banditshell`
    readonly property string cacheDir: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/banditshell`

    readonly property var defaults: ({

            theme: "slate",

            themeFromWallpaper: false,

            font: {
                family: "Monocraft",

                icon: "Material Symbols Rounded",

                brand: "Symbols Nerd Font",

                iconScale: 1.1,

                base: 9,
                scale: [2, 3, 4]
            },

            material: {

                surfaceAlpha: 0.88,

                label: [0.92, 0.58, 0.45, 0.16],

                fill: [0.07, 0.145, 0.18],

                separator: 0.1,

                accentFill: 0.2,

                accentDull: 0.65
            },

            compositor: {
                follow: true,

                pushBorders: true
            },

            rounding: {

                base: 15,

                scale: [0.6, 1.0, 1.6],

                power: 5.0
            },
            padding: {

                base: 4,
                scale: [2, 3, 4, 6, 8]
            },
            button: {

                heights: [32, 40, 56, 96, 136],
                padX: [12, 16, 24, 48, 64],
                iconSizes: [20, 20, 24, 32, 40],
                iconGaps: [4, 8, 8, 12, 16]
            },
            anim: {
                base: 220,
                scale: [0.68, 1.0, 1.45],

                trackSpeed: 14,

                revealSpeed: 18,

                railSpeed: 7,

                resizeSpeed: 14,

                scrollSpeed: 15,

                grace: 180,

                dwell: 250,

                tooltip: 450,

                settle: 250
            },

            colour: {

                surface: 3,

                accent: "mid"
            },

            edge: {

                border: 10,

                bare: false,

                roundOuter: true,
                outerExtra: 0,

                outerColour: "#000000"
            },

            sidebar: {

                width: 52,

                enabled: true,

                update: "new",

                perScreen: {},

                flareTier: 2,
                workspaces: {

                    style: "plates",

                    iconMode: "colour",

                    iconScale: 1.25,

                    specials: [],

                    rack: true,

                    persistent: 5,

                    slot: 32,

                    gap: 12,

                    windowPitch: 1.0,

                    emptyReach: 0.28,

                    busyReach: 0.62,

                    hover: 0.09,

                    mapBar: 5,
                    mapGap: 3,

                    block: 9,
                    blockGap: 3
                },
                clock: {
                    style: "stacked",
                    date: "day and month"
                },

                status: {
                    slot: 29,
                    gap: 4,

                    sound: true,
                    network: true,
                    bluetooth: true,
                    battery: true
                },

                tray: {
                    enabled: true,

                    slot: 29,
                    gap: 4,

                    iconScale: 1.0,

                    max: 8
                }
            },

            obs: {

                host: "",

                port: 0,

                password: ""
            },

            stream: {

                enabled: false,

                screen: "",

                height: 400
            },

            wallpaper: {

                enabled: true,

                dir: "~/Pictures/Wallpapers",

                fit: 1.25,

                current: "~/Pictures/Wallpapers/shaded_landscape.png",

                perScreen: {},

                animate: true,

                reveal: 900,

                audio: false
            },

            sourceEdits: {
                acknowledged: false,
            },

            blob: {

                melt: 34,

                feather: 1.0
            },

            picker: {
                dir: "~/Pictures/Screenshots",

                editor: "swappy -f",
                outline: 2
            },

            apps: {
                icons: ({})
            },

            launcher: {
                width: 840,

                iconSize: 36,

                halfLifeDays: 14,

                concept: "list",

                hidden: ({}),

                starred: ({}),

                folders: ({}),

                alphabet: {
                    width: 760,

                    icon: 48,

                    rail: 44,

                    favourites: 7,

                    bow: 340,
                    bowSpread: 9,

                    badge: 72,

                    moveDelay: 80
                },

                claimMs: 15000,

                opening: {

                    graceMs: 220,

                    assumeMs: 2500,

                    learn: 0.4,

                    giveUpMs: 20000,
                    giveUpFactor: 4,

                    landedMs: 700,
                    lostMs: 5000
                }
            },

            clipboard: {

                width: 980,

                preview: 132,

                previewLines: 4,

                iconScale: 1.4,

                record: true,

                maxEntries: 400,

                maxText: 1048576,
                maxBlob: 33554432,

                importClipse: true
            },

            calendar: {

                rightGoesForward: true
            },

            clock: {

                snoozeMinutes: 9,

                ringMinutes: 15,

                catchUpMinutes: 60,

                timerMax: 3,
                alarmMax: 8,

                cloud: ["claude", "-p"],

                cloudSeconds: 120,
                cloudReplyChars: 240
            },

            usage: {

                capHours: 10,
                greyAtCap: false,
                breaks: false,
                breakEvery: 50
            },

            idle: {
                lock: 0,
                screensOff: 0,
                sleep: 0
            },

            startup: {
                runAutostart: false
            },

            battery: {

                holdCharge: true,

                holdAt: 80,

                warnAt: 15,

                nearlyEmpty: "nothing"
            },

            power: {

                lid: {

                    onBattery: "suspend",

                    pluggedIn: "suspend",

                    docked: "nothing"
                }
            },

            notifications: {

                timeout: 5000,

                maxPopups: 4,

                maxHistory: 50,

                width: 400,

                badge: 40,

                cornerZone: 120,

                placement: "corner",

                quiet: false,

                quietUntil: 0,

                letAlarms: true,

                nightly: false,

                nightFrom: "22:00",

                nightTo: "07:30",

                rules: {}
            },

            sound: {

                alerts: false,

                alertSet: "soft",

                alertVolume: 0.5
            },

            island: {

                width: 440,

                glanceSeconds: 6,

                downloads: true,

                nowPlaying: true
            },

            packages: {

                interval: 360,

                upgrade: "sudo pacman -Syu"
            },

            media: {

                stroke: 4,

                waveLength: 28,

                waveAmplitude: 4,

                waveSpeed: 24,

                wheelSeek: 5,

                panelWidth: 560,

                seekSmall: 5,
                seekLarge: 30,

                lyrics: true,
                lyricsLead: 0.15
            },

            audio: {
                speakers: "",
                headphones: ""
            },

            volume: {
                step: 0.05,

                boost: true
            },

            screen: {

                warmth: 3000,

                level: 100,

                warmest: 2000,

                neutral: 6500,

                linger: 1200,

                grabFraction: 0.3,

                sliderWidth: 180,

                valueWidth: 52,

                schedule: "off",

                warmFrom: "21:00",
                warmTo: "07:00",

                easeMinutes: 5
            },

            access: {

                lessMotion: false,

                largerText: false,

                moreContrast: false,

                largerBase: 11,

                contrastLabel: [0.96, 0.8, 0.68, 0.24],

                stillMs: 1
            },

            region: {

                clock24: true,

                dateFormat: "words",

                autoZone: false
            },

            network: {

                checkForInternet: true,

                keepListFresh: false,

                portalUri: ""
            },

            session: {

                button: 72,

                iconScale: 1.7
            },

            settings: {

                width: 1280,
                height: 820,

                rail: 264,

                railRow: 36,

                gutter: 32,

                pane: 400
            },

            files: {

                width: 1200,
                height: 760,

                tile: 96,

                zoom: 1.0,

                sidebar: 200,

                preview: 420,

                thumbnail: 256,

                textMax: 2000000,

                hidden: false,

                markdown: "rendered",

                view: "icons",

                sort: "name",

                terminal: {

                    font: "CaskaydiaCove Nerd Font Mono",

                    rows: 16,

                    scrollback: 5000,

                    palette: ["#282c34", "#e06c75", "#98c379", "#e5c07b", "#61afef", "#c678dd", "#56b6c2", "#abb2bf", "#5c6370", "#ef7681", "#a6d189", "#efcb8b", "#74bdff", "#d68fe8", "#66c4d0", "#d7dae0"]
                },

                keys: {
                    "Ctrl+J": "terminal",
                    "Ctrl+1": "focus:grid",
                    "Ctrl+2": "focus:preview",
                    "Ctrl+3": "focus:terminal",
                    "Ctrl+4": "preview",
                    "Ctrl+5": "hidden",

                    "Ctrl+B": "sidebar",

                    "Ctrl+,": "settings",
                    "Alt+Left": "back",
                    "Alt+Right": "forward",
                    "Alt+Up": "parent",
                    "Alt+Home": "home"
                },

                grid: {
                    "h": "left",
                    "j": "down",
                    "k": "up",
                    "l": "right",
                    "g": "first",
                    "G": "last",
                    "/": "search",
                    " ": "preview",
                    ".": "hidden",
                    "v": "view",
                    "Ctrl+=": "zoomin",
                    "Ctrl++": "zoomin",
                    "Ctrl+-": "zoomout",
                    "Ctrl+0": "zoomreset",
                    "y": "copypath",
                    "-": "parent",

                    "Ctrl+A": "all",
                    "Ctrl+C": "copy",
                    "Ctrl+X": "cut",
                    "Ctrl+V": "paste",
                    "Ctrl+N": "newfolder",
                    "Ctrl+Shift+N": "newfile",
                    "Ctrl+L": "path",
                    "Ctrl+I": "properties",
                    "F2": "rename",
                    "Delete": "trash",
                    "Shift+Delete": "destroy"
                }
            },

            corner: {

                iconScale: 1.6
            },

            cheatsheet: {

                board: false,

                keyboard: "",

                keymap: "",

                shape: "iso",

                blocked: {}
            },

            tablet: {

                autoKeyboard: true,

                repeat: true,

                docked: true,

                height: 0.38,

                seam: 0.08,

                repeatDelay: 500,
                repeatInterval: 45
            },

            pen: {

                enabled: true,

                device: "wacom-intuos-pro-m-pen",

                pad: "Wacom Intuos Pro M Pad",

                grabPad: true,

                surface: {
                    width: 224,
                    height: 148
                },

                toggleButton: 256,

                aspectButton: 257,

                centreButton: 258,

                aspectLock: true,

                minSize: 160,

                lowerButton: "right click",

                upperButton: "middle click"
            },

            lock: {

                fieldWidth: 360,

                blur: 0.8,

                dim: 0.8,

                desaturate: 0.45,

                dotScale: 0.5,

                font: "Adwaita Sans",

                clockShare: 0.065,

                clockLayout: "row",

                verdict: 300,

                restAfter: 10,

                revealSpeed: 9
            },

            control: {

                minTarget: 24,

                wheelRows: 5,

                coastMs: 190,

                dragDismissFraction: 0.2,

                dragResistance: 0.5,

                dragThreshold: 6,

                pullSlack: 12,

                pullCommit: 0.25,

                pullReversal: 3,

                flickVelocity: 4,

                pullAngleCorner: 40,

                pullAngleEdge: 60,

                pullTravel: 0.12,

                touchEdges: true,

                signalBands: 4,
                deviceListMax: 7,

                rowHeight: 42,
                sliderHeight: 6,
                toggleWidth: 34,
                toggleHeight: 18
            },

            windows: {

                edge: true,

                grab: 0,

                settle: 120,

                hold: 260,

                holdSlop: 14,

                travel: 0.18,

                fling: 0.9,

                scale: 0.4,

                plate: 0.15,

                mode: "move",

                follow: false
            },

            menu: {

                width: 400,

                minHeight: 200,

                maxHeight: 1000
            },

            cli: {

                bindsDeclined: false
            },

            updates: {

                branch: "main",

                remote: "origin",

                interval: 30,

                seen: "",

                availableColour: "#ff5252",
                failedColour: "#ffb454",
                readyColour: "#4da3ff"
            }
        })

    property var values: defaults

    property bool loaded: false

    property bool unreadable: false

    property bool fresh: false

    readonly property bool writable: root.loaded && !root.unreadable

    property string lastWritten: ""

    property bool rewatch: false

    readonly property var opaque: ["files.keys", "files.grid", "notifications.rules"]

    readonly property var literals: ({
            "files.terminal.palette": ["theme"]
        })

    function get(key: string): var {
        return Configuration.lookup(root.values, key);
    }

    function set(key: string, value: var): void {
        root.setMany([[key, value]]);
    }

    function upgrade(values: var): var {
        return Configuration.upgrade(values);
    }

    function upgradeValue(key: string, value: var): var {
        return Configuration.upgradeValue(key, value);
    }

    function accepts(key: string, value: var): bool {
        return !Configuration.assign(root.values, [[key, value]], root.literals).refused;
    }

    function setMany(pairs: var): void {
        const result = Configuration.assign(root.values, pairs, root.literals);
        if (result.refused)
            return console.warn(`Config: no such setting "${result.refused}"`);

        const keys = pairs.map(pair => pair[0]).join(", ");
        if (!root.loaded)
            return console.warn(`Config: dropped ${keys}, because ${root.path} has not been read yet`);

        if (JSON.stringify(result.values) === JSON.stringify(root.values))
            return;
        root.values = result.values;

        if (root.unreadable)
            return console.warn(`Config: ${keys} not saved, because ${root.path} could not be read and is left untouched`);
        root.save();
    }

    function save(): void {
        if (!root.writable)
            return;
        root.lastWritten = JSON.stringify(root.values, null, 4) + "\n";
        file.setText(root.lastWritten);
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            const raw = text();
            if (root.writable && raw === root.lastWritten)
                return;

            let parsed = null;
            let problem = "not an object";
            try {
                parsed = JSON.parse(raw);
            } catch (e) {
                problem = e.message;
            }

            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
                root.unreadable = true;
                return console.warn(`Config: ${root.path} is not valid (${problem}), so it is left untouched and the shell keeps ${root.loaded ? "the values it had" : "the defaults"} until it is fixed.`);
            }

            root.unreadable = false;
            root.values = Configuration.merge(root.defaults, Configuration.upgrade(parsed), "", root.opaque, root.literals);
            root.loaded = true;

            if (JSON.stringify(root.values) !== JSON.stringify(parsed)) {
                console.log("Config: schema changed, updating config.json (your values are kept).");
                Qt.callLater(root.save);
            }
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound) {
                root.unreadable = true;
                return console.warn(`Config: could not read ${root.path} (${FileViewError.toString(err)}), so it is left untouched and the shell keeps ${root.loaded ? "the values it had" : "the defaults"}.`);
            }
            root.unreadable = false;
            root.fresh = true;
            root.loaded = true;
            root.rewatch = true;
            Qt.callLater(root.save);
        }

        onSaved: {
            if (!root.rewatch)
                return;
            root.rewatch = false;
            reload();
        }
    }
}
