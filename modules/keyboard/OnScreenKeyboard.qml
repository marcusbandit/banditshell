pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real originX

    required property int inset

    readonly property bool open: root.shown
    property bool shown: false

    readonly property Item maskItem: panel

    property string page: plan.base

    property var latched: []

    Layouts {
        id: plan
    }

    readonly property real panelWidth: root.width - root.originX
    readonly property real panelHeight: Math.round(root.height * Config.values.tablet.height)

    readonly property var rows: root.placed
    readonly property int rowCount: root.rows.length

    readonly property real boardWidth: root.panelWidth - Appearance.padding.large * 2
    readonly property real boardHeight: root.panelHeight - Appearance.padding.large * 2 - root.inset

    readonly property real pitch: root.boardWidth / plan.units
    readonly property real rowPitch: root.rowCount > 0 ? root.boardHeight / root.rowCount : 0
    readonly property real seam: Math.round(root.pitch * Config.values.tablet.seam)

    readonly property var placed: {
        const rows = plan.layers[root.page] ?? [];
        return rows.map((row, r) => {
            let at = 0;
            const cells = row.map(key => {
                const units = key.units ?? 1;
                const cell = {
                    key: key,
                    at: at,
                    units: units
                };
                at += units;
                return cell;
            });

            if (Math.abs(at - plan.units) > 0.001)
                console.warn(`OnScreenKeyboard: page "${root.page}" row ${r} is ${at} units, expected ${plan.units}.`);
            return cells;
        });
    }

    readonly property real slide: (root.panelHeight + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property var blobs: reveal.value <= 0.001 ? [] : [
        {
            x: root.originX,
            y: root.height - root.panelHeight + root.slide,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    function show(): void {
        root.shown = true;
    }

    function hide(): void {
        root.shown = false;

        root.latched = [];
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function follow(): void {
        if (Tablet.folded) {
            if (Config.values.tablet.autoKeyboard)
                root.show();
        } else {
            root.hide();
        }
    }

    Connections {
        target: Tablet

        function onFoldedChanged(): void {
            root.follow();
        }
    }

    Component.onCompleted: root.follow()

    function capOf(key: var): string {
        if (key.icon)
            return "";
        if (key.cap)
            return key.cap;
        if (root.latched.includes("shift"))
            return key.up ?? key.lo ?? "";
        return key.lo ?? "";
    }

    readonly property int reserveHeight: Math.round(root.panelHeight)

    function armed(key: var): bool {
        if (key.mod)
            return root.latched.includes(key.mod);
        if (key.act === "dock")
            return Tablet.docked;
        return false;
    }

    function toneOf(key: var): string {
        if (key.tone)
            return key.tone;
        if (key.lo !== undefined && key.lo !== " ")
            return "letter";
        return "function";
    }

    function toggleMod(mod: string): void {
        if (root.latched.includes(mod))
            root.latched = root.latched.filter(m => m !== mod);
        else
            root.latched = [...root.latched, mod];
    }

    function fire(key: var): void {
        if (key.mod) {
            root.toggleMod(key.mod);
            return;
        }

        if (key.act === "hide") {
            root.hide();
            return;
        }

        if (key.act === "dock") {
            Tablet.setDocked(!Tablet.docked);
            return;
        }

        if (key.act === "page") {
            root.page = key.to;
            return;
        }

        const mods = root.latched;

        if (key.sym) {
            Keystrokes.press(key.sym, mods);
        } else {
            const chord = mods.filter(m => m !== "shift");
            if (chord.length) {

                Keystrokes.type(key.lo, mods);
            } else {

                Keystrokes.type(root.latched.includes("shift") ? (key.up ?? key.lo) : key.lo, []);
            }
        }

        if (root.latched.length)
            root.latched = [];
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

    Item {
        id: panel

        x: root.originX
        y: root.height - root.panelHeight + root.slide
        width: root.panelWidth
        height: root.panelHeight
        visible: reveal.value > 0.001
        enabled: root.open

        Item {
            id: board

            x: Appearance.padding.large
            y: Appearance.padding.large
            width: root.boardWidth
            height: root.boardHeight

            Repeater {
                model: root.rows

                Item {
                    id: line

                    required property int index
                    required property var modelData

                    y: line.index * root.rowPitch
                    width: board.width
                    height: root.rowPitch

                    Repeater {
                        model: line.modelData

                        TabletKey {
                            required property var modelData

                            x: modelData.at * root.pitch

                            units: modelData.units
                            pitch: root.pitch
                            rowPitch: root.rowPitch
                            seam: root.seam

                            label: root.capOf(modelData.key)
                            icon: modelData.key.icon ?? ""
                            tone: root.toneOf(modelData.key)
                            latched: root.armed(modelData.key)
                            repeats: modelData.key.repeats ?? false

                            onFired: root.fire(modelData.key)
                        }
                    }
                }
            }
        }
    }
}
