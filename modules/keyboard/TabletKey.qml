pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property real units: 1
    property real pitch: 0
    property real rowPitch: 0
    property real seam: 0

    property string label: ""
    property string icon: ""

    property string tone: "letter"

    property bool latched: false

    property bool repeats: false

    signal fired

    readonly property bool down: touch.pressed

    readonly property real radius: Appearance.rounding.normal

    readonly property color resting: root.tone === "accent" ? Appearance.colour.accentFill : root.tone === "letter" ? Appearance.colour.fillStrong : Appearance.colour.fill

    readonly property color fill: root.latched ? Appearance.colour.accentFill : root.down ? (root.tone === "accent" ? Appearance.colour.accent : Appearance.colour.fillStronger) : root.resting

    readonly property color ink: Appearance.colour.text

    readonly property int typeSize: root.tone === "letter" ? Appearance.font.size.normal : Appearance.font.size.small

    width: root.units * root.pitch - root.seam
    height: root.rowPitch - root.seam

    SquircleRect {
        id: cap

        anchors.fill: parent

        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius

        color: root.fill

        Behavior on color {
            enabled: !root.down
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            visible: !root.icon

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight

            text: root.label
            color: root.ink
            font.pixelSize: root.typeSize
        }

        Icon {
            anchors.centerIn: parent
            visible: !!root.icon

            name: root.icon

            size: Appearance.font.iconSize
            color: root.ink
        }
    }

    TapHandler {
        id: touch

        gesturePolicy: TapHandler.WithinBounds

        onPressedChanged: {
            if (touch.pressed) {
                root.fired();
                if (root.repeats)
                    delay.restart();
            } else {
                delay.stop();
                again.stop();
            }
        }
    }

    Timer {
        id: delay

        interval: Config.values.tablet.repeatDelay
        onTriggered: again.start()
    }

    Timer {
        id: again

        interval: Config.values.tablet.repeatInterval
        repeat: true
        onTriggered: root.fired()
    }
}
