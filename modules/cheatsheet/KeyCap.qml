pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

Item {
    id: root

    property real units: 1
    property real span: 1
    property real pitch: 0
    property real seam: 0
    property real margin: Appearance.padding.small

    property real foot: 0

    property string label: ""
    property string glyph: ""

    property bool blocked: false

    property bool lit: false
    property bool latched: false
    property bool selected: false

    signal tapped

    readonly property bool stepped: root.foot > 0 && root.span > 1

    readonly property real headHeight: root.stepped ? root.pitch - root.seam : root.span * root.pitch - root.seam
    readonly property real legWidth: root.foot * root.pitch - root.seam

    readonly property real radius: Appearance.rounding.small

    readonly property color fill: root.blocked ? "transparent" : root.latched ? Appearance.colour.accentFill : root.lit ? Appearance.colour.fillStronger : Appearance.colour.fill
    readonly property color ink: root.latched || root.lit ? Appearance.colour.text : Appearance.colour.textGhost

    readonly property color edge: root.selected ? Appearance.colour.accent : root.blocked ? Appearance.colour.separator : "transparent"
    readonly property real edgeWidth: root.selected || root.blocked ? Appearance.font.stem : 0

    property color paint: root.fill

    Behavior on paint {
        ColorAnimation {
            duration: Appearance.animation.fast
        }
    }

    function steppedPath(w: real, h: real, head: real, leg: real, r: real, inset: real): string {
        const points = [[inset, inset], [w - inset, inset], [w - inset, h - inset], [w - leg + inset, h - inset], [w - leg + inset, head - inset], [inset, head - inset]];
        const bend = Math.max(0, Math.min(r, leg / 2, head / 2, (h - head) / 2));
        const toward = (from, to) => {
            const dx = to[0] - from[0];
            const dy = to[1] - from[1];
            const len = Math.hypot(dx, dy) || 1;
            return [from[0] + dx / len * bend, from[1] + dy / len * bend];
        };
        const n = points.length;
        const start = toward(points[0], points[1]);
        let out = `M ${start[0]} ${start[1]}`;
        for (let i = 1; i <= n; i++) {
            const at = points[i % n];
            const enter = toward(at, points[i - 1]);
            const leave = toward(at, points[(i + 1) % n]);
            out += ` L ${enter[0]} ${enter[1]} Q ${at[0]} ${at[1]} ${leave[0]} ${leave[1]}`;
        }
        return `${out} Z`;
    }

    width: root.units * root.pitch - root.seam
    height: root.span * root.pitch - root.seam

    SquircleRect {
        anchors.fill: parent
        visible: !root.stepped

        radius: root.radius

        color: root.paint
        stroke: root.edge
        strokeWidth: root.edgeWidth
    }

    Shape {
        anchors.fill: parent
        visible: root.stepped

        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.paint
            strokeColor: root.edge
            strokeWidth: root.edgeWidth

            PathSvg {
                path: root.stepped ? root.steppedPath(root.width, root.height, root.headHeight, root.legWidth, root.radius, root.edgeWidth / 2) : ""
            }
        }
    }

    Item {
        id: head

        width: parent.width
        height: root.headHeight

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: root.margin
            anchors.rightMargin: root.margin
            visible: !root.glyph

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            elide: Text.ElideRight

            text: root.label
            color: root.ink
            font.strikeout: root.blocked
        }

        Icon {
            anchors.centerIn: parent
            visible: !!root.glyph && !root.label

            glyph: root.glyph
            size: Appearance.font.size.small
            color: root.ink
        }

        Item {
            id: pair

            readonly property real gap: Appearance.padding.small / 2

            anchors.centerIn: parent
            width: Math.min(sigil.implicitWidth + pair.gap + word.implicitWidth, head.width - root.margin * 2)
            height: head.height
            visible: !!root.glyph && !!root.label

            Icon {
                id: sigil

                anchors.verticalCenter: parent.verticalCenter

                glyph: root.glyph
                size: Appearance.font.size.small
                color: root.ink
            }

            StyledText {
                id: word

                anchors.verticalCenter: parent.verticalCenter
                x: sigil.implicitWidth + pair.gap
                width: Math.max(0, pair.width - word.x)

                elide: Text.ElideRight

                text: root.label
                color: root.ink
                font.strikeout: root.blocked
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }

    MouseArea {
        x: parent.width - width
        y: root.headHeight
        width: root.legWidth
        height: parent.height - root.headHeight
        visible: root.stepped

        cursorShape: Qt.PointingHandCursor
        onClicked: root.tapped()
    }
}
