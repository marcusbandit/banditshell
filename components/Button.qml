pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property string text: ""
    property string detail: ""
    property string icon: ""
    property real iconFill: 0
    property string style: "plate"
    property int size: 1
    property bool checkable: false
    property bool checked: false
    signal toggled

    signal clicked

    property bool interactive: true

    property bool keyed: false

    readonly property bool keyable: root.interactive

    function press(): void {
        if (root.checkable)
            root.toggled();
        else
            root.clicked();
    }

    property bool alarm: false

    readonly property bool hovered: root.interactive && !root.keyed && pointer.containsMouse
    readonly property bool pressed: root.interactive && pointer.pressed

    readonly property real labelSize: root.size < 2 ? Appearance.font.size.small : root.size < 3 ? Appearance.font.size.normal : Appearance.font.size.large
    readonly property real padX: Appearance.button.padX(root.size)
    readonly property real markSize: Appearance.button.iconSize(root.size)
    readonly property real markGap: Appearance.button.iconGap(root.size)

    readonly property bool hasText: root.text !== ""
    readonly property bool hasIcon: root.icon !== ""
    readonly property real markSpan: root.hasIcon ? markSize + (root.hasText ? markGap : 0) : 0
    readonly property real detailSpan: root.hasText && root.detail !== "" ? detailLabel.implicitWidth : 0

    opacity: root.interactive ? 1 : Appearance.opacity.disabled

    readonly property var skins: ({
            accent: {
                bg: Appearance.colour.accent,
                fg: Appearance.colour.accentText,
                ring: "transparent",
                ringW: 0
            },
            plate: {
                bg: Appearance.colour.accentFill,
                fg: Appearance.colour.text,
                ring: "transparent",
                ringW: 0
            },
            ring: {
                bg: "transparent",
                fg: Appearance.colour.text,
                ring: Appearance.colour.fillStrong,
                ringW: Appearance.stroke.ring
            },
            bare: {
                bg: "transparent",
                fg: Appearance.colour.text,
                ring: "transparent",
                ringW: 0
            }
        })

    readonly property var skin: {
        const own = root.skins[root.style] ?? root.skins.plate;
        if (!root.checkable)
            return own;
        if (root.checked)
            return root.skins.accent;
        return own === root.skins.accent ? root.skins.plate : own;
    }

    property var paint
    readonly property color bg: {
        const base = root.paint ?? root.skin.bg;

        if (!root.interactive)
            return base;

        const layer = root.pressed ? Appearance.colour.fillStrong : root.hovered ? Appearance.colour.fill : null;

        if (!layer)
            return base;
        if (base.a === 0)
            return layer;
        return Appearance.blend(base, root.fg, layer.a);
    }

    property real radiusLeft: -1
    property real radiusRight: -1

    readonly property color fg: root.alarm ? Appearance.colour.alarm : root.skin.fg
    readonly property color ring: root.skin.ring
    readonly property real ringW: root.skin.ringW

    readonly property real pillRadius: height / 2

    implicitWidth: root.hasText ? label.implicitWidth + markSpan + detailSpan + padX * 2 : implicitHeight
    implicitHeight: Math.max(Appearance.sizes.minTarget, Appearance.button.height(root.size))
    width: implicitWidth
    height: implicitHeight

    SquircleRect {
        id: plate

        anchors.fill: parent
        pill: "object"
        topLeftRadius: root.radiusLeft >= 0 ? root.radiusLeft : root.pillRadius
        bottomLeftRadius: root.radiusLeft >= 0 ? root.radiusLeft : root.pillRadius
        topRightRadius: root.radiusRight >= 0 ? root.radiusRight : root.pillRadius
        bottomRightRadius: root.radiusRight >= 0 ? root.radiusRight : root.pillRadius
        color: tone.value
        stroke: root.ring
        strokeWidth: root.ringW
    }

    FocusMark {
        id: focusRing

        shown: root.activeFocus
        pill: "object"
        topLeftRadius: plate.topLeftRadius + focusRing.reach
        bottomLeftRadius: plate.bottomLeftRadius + focusRing.reach
        topRightRadius: plate.topRightRadius + focusRing.reach
        bottomRightRadius: plate.bottomRightRadius + focusRing.reach
    }

    scale: pressGlide.value

    Follow {
        id: pressGlide

        target: root.pressed ? Appearance.press.plate : 1
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    FollowColour {
        id: tone

        target: root.bg
        speed: Appearance.animation.revealSpeed
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.hasText && root.hasIcon ? root.markGap : 0

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasIcon
            name: root.icon
            fill: root.iconFill
            size: root.markSize
            color: root.fg
        }

        StyledText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasText
            width: visible ? Math.min(implicitWidth, root.width - root.padX * 2 - root.markSpan - root.detailSpan) : 0
            text: root.text
            font.pixelSize: root.labelSize
            color: root.fg
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        StyledText {
            id: detailLabel

            anchors.verticalCenter: parent.verticalCenter
            visible: root.detailSpan > 0
            text: `\u00a0${root.detail}`
            font.pixelSize: root.labelSize
            color: root.fg
            opacity: 0.6
            verticalAlignment: Text.AlignVCenter
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.press()
    }
}
