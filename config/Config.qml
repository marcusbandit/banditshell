pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, backed by ~/.config/myshell/config.json.
//
// Edit that file and the shell follows live, no restart. Delete it and it is
// written back from the defaults below. A settings menu will just call
// `Config.set("sidebar.width", 90)`; nothing else has to change for it to exist.
//
// `defaults` IS the schema. A key that is not in it is not a setting, and a key
// that is in it always resolves, so a half-written config.json still boots.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.config/myshell`
    readonly property string path: `${dir}/config.json`

    readonly property var defaults: ({
            // Name from Themes.qml. Try "slate".
            theme: "greensteel",

            // Every scale is a BASE and a list of multipliers. The list length is
            // the number of tiers, so the shell never hardcodes a size: it asks
            // for tier 0/1/2 and the maths does the rest.
            font: {
                family: "Monocraft",
                // Icons. Separate from the text face on purpose: swap this for a
                // pixel icon font when one exists and nothing else changes.
                icon: "Material Symbols Rounded",
                base: 16,
                // Three tiers, and three is the limit on purpose.
                scale: [0.75, 1.0, 1.75]
            },

            // Material.
            //
            // Panels are a translucent material that the compositor blurs, not a
            // painted colour, and everything ON them is the palette's light end
            // at an opacity tier. That is the whole system: depth comes from
            // transparency and layering, never from bevels, gradients or
            // engraved lines, which read as cheap.
            material: {
                // Opacity of a panel. The rest is whatever is behind it, blurred.
                surfaceAlpha: 0.72,
                // Label tiers: primary, secondary, tertiary.
                label: [0.92, 0.58, 0.32],
                // Fills, for hover and selection. Same light end, far quieter.
                fill: [0.07, 0.12, 0.18],
                // Hairline separators and panel edges.
                separator: 0.1
            },
            // Take rounding, corner smoothing and the edge gap from the running
            // compositor instead of the values below, so the shell agrees with
            // the windows without being told twice. Hyprland and niri.
            // Falls back to the manual values if the compositor can't be read.
            compositor: {
                follow: true
            },

            rounding: {
                // Ignored while compositor.follow finds a compositor.
                base: 15,
                scale: [0.55, 1.0, 1.6],
                // Corner smoothing: 0 = plain circular arc, 0.6 = iOS squircle,
                // 1 = maximum. Anything above 0 is G2.
                smoothing: 0.6
            },
            padding: {
                base: 10,
                scale: [0.6, 1.0, 1.8, 3.0]
            },
            anim: {
                base: 220,
                scale: [0.68, 1.0, 1.45],
                // Exponential-smoothing rate for things that track a target.
                // Higher is snappier.
                trackSpeed: 14
            },

            // Which stop of the theme's ramp each role uses. The ramp runs 0
            // (darkest) to 10 (lightest), so these are portable across themes:
            // a new palette supplies colours, not decisions.
            colour: {
                // Which stop the panel material is tinted with. High enough that
                // the theme still reads through the translucency: too low and a
                // frosted panel is just grey, which is nobody's palette.
                surface: 3,
                // Which saturated colour is "the accent": dim, mid or bright.
                accent: "mid"
            },

            edge: {
                // Width of the invisible interaction ring. Ignored while
                // compositor.follow is finding gaps_out.
                border: 10,

                // Round the outer edges of the display: four black pieces at the
                // physical screen corners, so the desktop reads as a framed
                // panel rather than a rectangle that happens to end.
                roundOuter: true,
                // Which rounding tier the frame uses. 1 is the same radius as a
                // window corner, which is usually what "correct" means here.
                outerTier: 1,
                // The frame colour. Black is the point, but it is a setting.
                outerColour: "#000000"
            },

            sidebar: {
                width: 84,
                // Rounding tier used for the concave corners that meet the
                // screen edges.
                flareTier: 2,
                workspaces: {
                    // Slots always shown, even when empty.
                    persistent: 5,
                    slot: 32,
                    gap: 10
                },
                status: {
                    slot: 34,
                    gap: 8
                }
            }
        })

    property var values: defaults

    // Read one setting by dotted path, e.g. get("sidebar.width").
    function get(key: string): var {
        return key.split(".").reduce((node, k) => node?.[k], root.values);
    }

    // Write one setting by dotted path and persist it. This is the whole API a
    // settings menu needs.
    function set(key: string, value: var): void {
        const keys = key.split(".");
        const next = JSON.parse(JSON.stringify(root.values));

        let node = next;
        for (let i = 0; i < keys.length - 1; i++) {
            node = node[keys[i]];
            if (typeof node !== "object" || node === null)
                return console.warn(`Config: no such setting "${key}"`);
        }
        if (!(keys[keys.length - 1] in node))
            return console.warn(`Config: no such setting "${key}"`);

        node[keys[keys.length - 1]] = value;
        root.values = next;
        root.save();
    }

    function save(): void {
        file.setText(JSON.stringify(root.values, null, 4) + "\n");
    }

    // Overlay the user's file on the defaults, key by key, so a partial or
    // outdated config.json still yields a complete settings object. Arrays are
    // replaced wholesale: a scale is one value, not a set to merge into.
    function merge(base: var, over: var): var {
        if (over === undefined || base === null || typeof base !== "object" || Array.isArray(base))
            return over === undefined ? base : over;

        const out = {};
        for (const k in base)
            out[k] = merge(base[k], over[k]);
        return out;
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            try {
                root.values = root.merge(root.defaults, JSON.parse(text()));
            } catch (e) {
                console.warn(`Config: ${root.path} is not valid JSON, keeping previous values.`, e);
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
        }
    }

    // First run: make the directory, then write the defaults out so there is
    // something to edit.
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: root.save()
    }
}
