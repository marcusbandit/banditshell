pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.config/banditshell`
    readonly property string path: `${dir}/config.json`

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

                scale: [2, 2, 3, 4, 5],
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

                perScreen: {},

                flareTier: 2,
                workspaces: {

                    style: "plates",

                    iconMode: "colour",

                    iconScale: 1.25,

                    specials: [],

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
                status: {
                    slot: 29,
                    gap: 4
                },

                tray: {
                    slot: 29,
                    gap: 4,

                    iconScale: 1.0,

                    max: 8
                }
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
                icons: ({}),

                claude: ["claude", "-p", "--permission-mode", "acceptEdits"]
            },

            launcher: {
                width: 840,

                iconSize: 36,

                halfLifeDays: 14,

                concept: "list",

                hidden: ({}),

                starred: ({}),

                folders: ({}),

                niagara: {
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

            usage: {

                capHours: 10
            },

            notifications: {

                timeout: 5000,

                maxPopups: 4,

                maxHistory: 50,

                width: 400,

                badge: 40,

                cornerZone: 120
            },

            notch: {

                trackWidth: 288
            },

            media: {

                stroke: 4,

                waveLength: 28,

                waveAmplitude: 4,

                waveSpeed: 24,

                wheelSeek: 5,

                panelWidth: 560,

                seekSmall: 5,
                seekLarge: 30
            },

            audio: {
                speakers: "",
                headphones: ""
            },

            volume: {

                step: 0.05,

                railWidth: 10,

                meterGlyphs: 3,

                linger: 1200,

                grabFraction: 0.3
            },

            network: {

                checkForInternet: true,

                keepListFresh: true,

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

                text: 15,

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

                symbols: false
            },

            tablet: {

                autoKeyboard: true,

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

                minSize: 160
            },

            lock: {

                fieldWidth: 360,

                blur: 0.8,

                dim: 0.8,

                desaturate: 0.45,

                dotScale: 0.5,

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

    function get(key: string): var {
        return key.split(".").reduce((node, k) => node?.[k], root.values);
    }

    function set(key: string, value: var): void {
        root.setMany([[key, value]]);
    }

    function setMany(pairs: var): void {
        const next = JSON.parse(JSON.stringify(root.values));

        for (const [key, value] of pairs) {
            const keys = key.split(".");
            let node = next;
            for (let i = 0; i < keys.length - 1; i++) {
                node = node[keys[i]];
                if (typeof node !== "object" || node === null)
                    return console.warn(`Config: no such setting "${key}"`);
            }
            if (!(keys[keys.length - 1] in node))
                return console.warn(`Config: no such setting "${key}"`);

            node[keys[keys.length - 1]] = value;
        }

        root.values = next;
        root.save();
    }

    function save(): void {
        file.setText(JSON.stringify(root.values, null, 4) + "\n");
    }

    readonly property var opaque: ["files.keys", "files.grid"]

    function merge(base: var, over: var, path: string): var {

        if (root.opaque.includes(path))
            return over && typeof over === "object" ? over : base;

        if (Array.isArray(base))
            return Array.isArray(over) && (base.length === 0 || over.length === base.length) ? over : base;

        if (base && typeof base === "object" && !Object.keys(base).length)
            return over && typeof over === "object" ? over : base;
        if (over === undefined || base === null || typeof base !== "object")
            return over === undefined ? base : over;

        const out = {};
        for (const k in base)
            out[k] = merge(base[k], over[k], path ? `${path}.${k}` : k);
        return out;
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            let parsed;
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                return console.warn(`Config: ${root.path} is not valid JSON, keeping previous values.`, e);
            }

            root.values = root.merge(root.defaults, parsed, "");

            root.loaded = true;

            if (JSON.stringify(root.values) !== JSON.stringify(parsed)) {
                console.log("Config: schema changed, updating config.json (your values are kept).");

                Qt.callLater(root.save);
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
        }
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: {
            root.save();
            root.loaded = true;
        }
    }
}
