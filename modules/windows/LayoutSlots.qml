pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen

    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    property string heldAddr: ""

    property string mode: "move"

    property real pointX: 0
    property real pointY: 0
    property bool active: false

    property var all: []

    onActiveChanged: if (root.active)
        root.snapshot()

    function snapshot(): void {

        root.landed = false;
        land.snap();

        const out = [];

        for (const client of Hypr.clientsOn(root.screen)) {
            const o = client.lastIpcObject;
            if (!o?.at || !o?.size)
                continue;

            const raw = o.address ?? "";
            const addr = raw.startsWith("0x") ? raw : `0x${raw}`;
            if (!addr)
                continue;

            out.push({
                addr,
                client,
                held: addr === root.heldAddr,
                mark: AppIcons.markFor(Hypr.classOf(client)),
                x: o.at[0] - root.screen.x,
                y: o.at[1] - root.screen.y,
                w: o.size[0],
                h: o.size[1]
            });
        }

        root.all = out;
        root.centre();
    }

    function centre(): void {
        for (const w of root.all) {
            if (!w.held)
                continue;
            const mid = (w.x + w.w / 2 - root.box.x) * root.fitted;
            root.pan = Math.max(0, Math.min(mid - root.holeWidth / 2, root.maxPan));
            return;
        }
        root.pan = 0;
    }

    Timer {
        interval: 16
        repeat: true
        running: root.active && !root.landed && root.maxPan > 0

        onTriggered: {
            const margin = root.holeWidth * 0.18;
            const left = root.holeX + margin - root.pointX;
            const right = root.pointX - (root.holeX + root.holeWidth - margin);
            const push = left > 0 ? -left : right > 0 ? right : 0;
            if (push === 0)
                return;

            const step = root.holeWidth * (interval / 1000) * Math.min(1, Math.abs(push) / margin) * Math.sign(push);
            root.pan = Math.max(0, Math.min(root.pan + step, root.maxPan));
        }
    }

    readonly property rect box: {
        if (root.all.length === 0)
            return Qt.rect(0, 0, root.width, root.height);

        let x0 = Infinity;
        let y0 = Infinity;
        let x1 = -Infinity;
        let y1 = -Infinity;

        for (const w of root.all) {
            x0 = Math.min(x0, w.x);
            y0 = Math.min(y0, w.y);
            x1 = Math.max(x1, w.x + w.w);
            y1 = Math.max(y1, w.y + w.h);
        }

        return Qt.rect(x0, y0, Math.max(1, x1 - x0), Math.max(1, y1 - y0));
    }

    readonly property real fitted: Math.min(root.holeHeight / root.box.height, Appearance.sizes.windowScale)

    property real pan: 0

    readonly property real stripW: root.box.width * root.fitted
    readonly property real maxPan: Math.max(0, root.stripW - root.holeWidth)

    property bool landed: false

    Follow {
        id: land

        target: root.landed ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.002
    }

    readonly property real mapScale: root.fitted

    readonly property real drawScale: root.fitted + (1 - root.fitted) * land.value

    readonly property real mapX: root.holeX + Math.max(0, root.holeWidth - root.stripW) / 2 - root.pan - root.box.x * root.fitted
    readonly property real mapY: root.holeY + (root.holeHeight - root.box.height * root.fitted) / 2 - root.box.y * root.fitted
    readonly property real originX: root.mapX
    readonly property real originY: root.mapY

    function place(w: var): rect {
        return Qt.rect(root.originX + w.x * root.mapScale, root.originY + w.y * root.mapScale, w.w * root.mapScale, w.h * root.mapScale);
    }

    readonly property var windows: root.all.filter(w => !w.held)

    readonly property var columns: {
        const by = {};
        for (const w of root.all) {
            const k = `${w.x}`;
            if (!by[k])
                by[k] = {
                    x: w.x,
                    items: []
                };
            by[k].items.push(w);
        }
        return Object.keys(by).map(k => by[k]).sort((a, b) => a.x - b.x);
    }

    function columnOf(w: var): int {
        for (let i = 0; i < root.columns.length; i++)
            if (root.columns[i].x === w.x)
                return i;
        return -1;
    }

    readonly property int heldColumn: {
        for (const w of root.all)
            if (w.held)
                return root.columnOf(w);
        return -1;
    }

    readonly property int aimColumn: root.over >= 0 ? root.columnOf(root.windows[root.over]) : -1

    readonly property int steps: root.aimColumn >= 0 && root.heldColumn >= 0 ? root.aimColumn - root.heldColumn : 0

    readonly property string aimAddr: root.over >= 0 ? root.windows[root.over].addr : ""

    readonly property var planX: {
        const xs = root.columns.map(c => c.x);
        if (root.aimColumn < 0 || root.heldColumn < 0 || root.mode === "swap")
            return xs;

        const idx = root.columns.map((c, k) => k);
        idx.splice(root.heldColumn, 1);
        idx.splice(root.aimColumn, 0, root.heldColumn);

        const out = new Array(xs.length);
        for (let p = 0; p < idx.length; p++)
            out[idx[p]] = xs[p];
        return out;
    }

    function planned(w: var): var {
        if (root.aimColumn < 0 || root.heldColumn < 0)
            return w;

        if (root.mode === "swap") {
            const aim = root.windows[root.over];
            if (w.held)
                return aim;
            if (w.addr === aim.addr) {
                for (const h of root.all)
                    if (h.held)
                        return h;
            }
            return w;
        }

        const col = root.columnOf(w);
        return {
            x: root.planX[col],
            y: w.y,
            w: w.w,
            h: w.h
        };
    }

    function liveRect(addr: string, fallback: var): rect {
        for (const client of Hypr.clientsOn(root.screen)) {
            const o = client.lastIpcObject;
            if (!o?.at || !o?.size)
                continue;

            const raw = o.address ?? "";
            if ((raw.startsWith("0x") ? raw : `0x${raw}`) !== addr)
                continue;

            return Qt.rect(o.at[0] - root.screen.x, o.at[1] - root.screen.y, o.size[0], o.size[1]);
        }

        return Qt.rect(fallback.x, fallback.y, fallback.w, fallback.h);
    }

    function slotRect(i: int): rect {
        return root.place(root.windows[i]);
    }

    readonly property int over: {
        if (!root.active || root.landed)
            return -1;

        for (let i = 0; i < root.windows.length; i++) {
            const s = root.slotRect(i);
            if (root.pointX >= s.x && root.pointX <= s.x + s.width && root.pointY >= s.y && root.pointY <= s.y + s.height)
                return i;
        }

        return -1;
    }

    Follow {
        id: reveal

        target: root.active ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    readonly property real fade: reveal.value

    visible: reveal.value > 0.01
    opacity: reveal.value

    Item {
        x: root.holeX
        y: root.holeY
        width: root.holeWidth
        height: root.holeHeight
        clip: true

        Item {
            x: -root.holeX
            y: -root.holeY
            width: root.width
            height: root.height

            Repeater {
                model: root.visible ? root.all : []

                delegate: Item {
                    id: slot

                    required property int index
                    required property var modelData

                    readonly property bool aimed: !slot.modelData.held && root.over >= 0 && root.windows[root.over].addr === slot.modelData.addr

                    readonly property real quiet: slot.aimed ? 1 : 0.62

                    opacity: slot.quiet + (1 - slot.quiet) * land.value

                    Behavior on opacity {
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    readonly property rect spot: root.place(root.planned(slot.modelData))

                    readonly property rect home: root.liveRect(slot.modelData.addr, slot.modelData)

                    x: slot.spot.x + (slot.home.x - slot.spot.x) * land.value
                    y: slot.spot.y + (slot.home.y - slot.spot.y) * land.value
                    width: slot.spot.width + (slot.home.width - slot.spot.width) * land.value
                    height: slot.spot.height + (slot.home.height - slot.spot.height) * land.value

                    Behavior on x {

                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on width {
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on height {
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    SquircleRect {
                        anchors.fill: parent
                        visible: slot.modelData.held

                        radius: Appearance.sizes.windowRadius * root.drawScale
                        color: "transparent"
                        stroke: Appearance.colour.separator
                        strokeWidth: Appearance.font.stem
                        opacity: 1 - land.value
                    }

                    SquircleRect {
                        anchors.fill: parent
                        visible: !slot.modelData.held

                        radius: Appearance.sizes.windowRadius * root.drawScale
                        color: slot.aimed ? Appearance.colour.fillStrong : Appearance.colour.fill

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    WindowView {
                        id: shot

                        anchors.fill: parent
                        visible: !slot.modelData.held

                        window: slot.modelData.held ? null : slot.modelData.client
                        radius: Appearance.sizes.windowRadius * root.drawScale
                        live: false
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Appearance.padding.small
                        visible: !slot.modelData.held

                        AppMark {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !shot.ready

                            spec: slot.modelData.mark
                            size: Appearance.sizes.launcherIcon
                            color: slot.aimed ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter

                            name: root.mode === "swap" ? "swap_horiz" : "low_priority"
                            size: Appearance.font.iconSize
                            color: Appearance.colour.text
                            opacity: slot.aimed ? 1 - land.value : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
