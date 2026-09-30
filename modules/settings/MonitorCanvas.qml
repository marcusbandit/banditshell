pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    implicitHeight: 240

    property string selected: ""

    signal picked(string name)
    signal placed(string name, int x, int y)

    readonly property real pad: Appearance.padding.normal
    readonly property real zoom: 0.85
    readonly property real reach: 12

    readonly property var rects: Monitors.outputs.filter(m => !m.disabled).map(m => ({
            name: m.name,
            x: m.x,
            y: m.y,
            w: Monitors.layoutOf(m).w,
            h: Monitors.layoutOf(m).h
        }))

    readonly property var bounds: {
        let minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
        for (const r of root.rects) {
            minx = Math.min(minx, r.x);
            miny = Math.min(miny, r.y);
            maxx = Math.max(maxx, r.x + r.w);
            maxy = Math.max(maxy, r.y + r.h);
        }
        return {
            minx,
            miny,
            maxx,
            maxy
        };
    }

    readonly property real fitScale: {
        const bw = Math.max(1, root.bounds.maxx - root.bounds.minx);
        const bh = Math.max(1, root.bounds.maxy - root.bounds.miny);
        return root.zoom * Math.min((root.width - root.pad * 2) / bw, (root.height - root.pad * 2) / bh);
    }

    readonly property real originX: (root.width + root.pad * 2 - (root.bounds.maxx - root.bounds.minx) * root.fitScale) / 2
    readonly property real originY: (root.height + root.pad * 2 - (root.bounds.maxy - root.bounds.miny) * root.fitScale) / 2

    function mapX(layoutX: real): real {
        return root.originX + (layoutX - root.bounds.minx) * root.fitScale;
    }

    function mapY(layoutY: real): real {
        return root.originY + (layoutY - root.bounds.miny) * root.fitScale;
    }

    function unmapX(canvasX: real): real {
        return root.bounds.minx + (canvasX - root.originX) / root.fitScale;
    }

    function unmapY(canvasY: real): real {
        return root.bounds.miny + (canvasY - root.originY) / root.fitScale;
    }

    property bool dragging: false
    property string who: ""
    property real startX: 0
    property real startY: 0
    property real baseX: 0
    property real baseY: 0
    property real liveX: 0
    property real liveY: 0

    function snap(candidate: real, span: real, others: var): real {
        const t = root.reach / root.fitScale;
        let best = candidate;
        let bestD = t;
        const myEdges = [candidate, candidate + span, candidate + span / 2];
        for (const o of others) {
            const theirEdges = [o.x, o.x + o.w, o.x + o.w / 2];
            for (const mine of myEdges)
                for (const theirs of theirEdges) {
                    const d = theirs - mine;
                    if (Math.abs(d) < Math.abs(bestD)) {
                        bestD = d;
                        best = candidate + d;
                    }
                }
        }
        return best;
    }

    function collides(x: real, y: real, w: real, h: real, others: var): bool {
        for (const o of others)
            if (x < o.x + o.w - 1 && x + w > o.x + 1 && y < o.y + o.h - 1 && y + h > o.y + 1)
                return true;
        return false;
    }

    Repeater {
        model: root.rects

        delegate: SquircleRect {
            id: rect

            required property var modelData

            readonly property bool isDrag: root.dragging && root.who === rect.modelData.name
            readonly property bool isSelected: root.selected === rect.modelData.name

            x: root.mapX(isDrag ? root.liveX : rect.modelData.x)
            y: root.mapY(isDrag ? root.liveY : rect.modelData.y)
            width: Math.max(Appearance.font.stem * 8, rect.modelData.w * root.fitScale)
            height: Math.max(Appearance.font.stem * 8, rect.modelData.h * root.fitScale)
            radius: Appearance.rounding.small

            color: isSelected ? Appearance.colour.accentFill : Appearance.colour.surface
            stroke: isSelected ? Appearance.colour.accent : Appearance.colour.textGhost
            strokeWidth: isSelected ? Appearance.font.stem : 1

            Column {
                anchors.centerIn: parent

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: rect.modelData.name
                    color: rect.isSelected ? Appearance.colour.text : Appearance.colour.textDim
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: {
                        const m = Monitors.outputs.find(o => o.name === rect.modelData.name);
                        return m ? `${m.width}×${m.height}` : "";
                    }
                    color: Appearance.colour.textFaint
                }
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                onPressed: mouse => {
                    root.dragging = true;
                    root.who = rect.modelData.name;
                    root.startX = mouse.x;
                    root.startY = mouse.y;
                    root.baseX = rect.modelData.x;
                    root.baseY = rect.modelData.y;
                    root.liveX = rect.modelData.x;
                    root.liveY = rect.modelData.y;
                }

                onPositionChanged: mouse => {
                    if (!root.dragging || root.who !== rect.modelData.name)
                        return;

                    const others = root.rects.filter(r => r.name !== rect.modelData.name);

                    let cx = root.baseX + (mouse.x - root.startX) / root.fitScale;
                    let cy = root.baseY + (mouse.y - root.startY) / root.fitScale;

                    cx = root.snap(cx, rect.modelData.w, others);
                    cy = root.snap(cy, rect.modelData.h, others);

                    const w = rect.width;
                    const h = rect.height;
                    const mx = Math.max(0, Math.min(root.width - w, root.mapX(cx)));
                    const my = Math.max(0, Math.min(root.height - h, root.mapY(cy)));

                    if (!root.collides(cx, root.liveY, rect.modelData.w, rect.modelData.h, others))
                        root.liveX = root.unmapX(mx);
                    if (!root.collides(root.liveX, cy, rect.modelData.w, rect.modelData.h, others))
                        root.liveY = root.unmapY(my);
                }

                onReleased: {
                    const moved = Math.abs(root.liveX - root.baseX) > 0.5 || Math.abs(root.liveY - root.baseY) > 0.5;
                    const who = root.who;
                    const x = Math.round(root.liveX);
                    const y = Math.round(root.liveY);
                    root.dragging = false;
                    root.who = "";
                    if (moved)
                        root.placed(who, x, y);
                }

                onClicked: root.picked(rect.modelData.name)
            }
        }
    }
}
