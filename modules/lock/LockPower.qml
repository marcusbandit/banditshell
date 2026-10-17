pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string family: Appearance.font.lock

    property bool open: false

    readonly property var choices: [
        {
            key: "suspend",
            icon: "bedtime",
            label: "sleep"
        },
        {
            key: "reboot",
            icon: "restart_alt",
            label: "restart"
        },
        {
            key: "poweroff",
            icon: "power_settings_new",
            label: "shut down"
        }
    ]

    readonly property real bubble: Appearance.font.line.small + Appearance.padding.normal * 2
    readonly property real ringWidth: Math.max(2, Math.round(root.bubble / 16))

    property int pointed: -1
    property int held: -1

    readonly property string hint: {
        const pick = root.choices[root.held >= 0 ? root.held : root.pointed];
        if (!pick)
            return "";
        return root.held >= 0 ? `keep holding to ${pick.label}` : `hold to ${pick.label}`;
    }

    property string shownHint: ""

    onHintChanged: if (root.hint !== "")
        root.shownHint = root.hint

    function run(key: string): void {
        if (key === "suspend") {
            Suspension.perform("suspend");
            return;
        }
        const entry = Power.actions.find(action => action.key === key);
        if (entry)
            Power.run(entry);
    }

    implicitWidth: row.implicitWidth
    implicitHeight: label.implicitHeight + Appearance.padding.normal + root.bubble

    Follow {
        id: rise

        target: root.open || root.held >= 0 ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
    }

    Follow {
        id: telling

        target: root.hint !== "" ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.004
    }

    Item {
        anchors.fill: parent

        opacity: rise.value
        visible: rise.value > 0.01

        transform: Translate {
            y: (1 - rise.value) * root.bubble
        }

        Text {
            id: label

            anchors.horizontalCenter: parent.horizontalCenter
            text: root.shownHint
            color: Appearance.colour.textDim
            opacity: telling.value
            font.family: root.family
            font.pixelSize: Math.round(Appearance.font.size.small * 0.9)
            renderType: Text.NativeRendering
        }

        Row {
            id: row

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.large

            Repeater {
                model: root.choices

                delegate: Item {
                    id: choice

                    required property var modelData
                    required property int index

                    property bool fired: false

                    readonly property real filled: Math.min(1, hold.value / 0.95)

                    width: root.bubble
                    height: root.bubble

                    scale: squeeze.value

                    Follow {
                        id: squeeze

                        target: press.pressed ? Appearance.press.ring : press.containsMouse ? 1.06 : 1
                        speed: Appearance.animation.trackSpeed
                        epsilon: 0.002
                    }

                    Follow {
                        id: hold

                        target: press.pressed ? 1 : 0
                        speed: press.pressed ? 3.5 : Appearance.animation.revealSpeed

                        onValueChanged: {
                            if (press.pressed && !choice.fired && hold.value >= 0.95) {
                                choice.fired = true;
                                root.run(choice.modelData.key);
                            }
                        }
                    }

                    SquircleRect {
                        anchors.fill: parent
                        anchors.margins: -root.ringWidth
                        radius: width / 2
                        cornerPower: 2
                        color: Appearance.colour.ink
                    }

                    SquircleRect {
                        anchors.fill: parent
                        radius: width / 2
                        cornerPower: 2
                        color: press.containsMouse ? Appearance.colour.surfaceSolid : Qt.rgba(Appearance.colour.ink.r, Appearance.colour.ink.g, Appearance.colour.ink.b, 0.85)
                        stroke: Appearance.colour.seam
                        strokeWidth: Appearance.stroke.line
                    }

                    ProgressRing {
                        anchors.centerIn: parent
                        visible: choice.filled > 0.005
                        size: root.bubble - root.ringWidth
                        thickness: root.ringWidth
                        track: "transparent"
                        colour: choice.modelData.key === "poweroff" ? Appearance.colour.alarm : Appearance.colour.accent
                        value: choice.filled
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: choice.modelData.icon
                        size: Math.round(root.bubble * 0.42)
                        color: press.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    MouseArea {
                        id: press

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onContainsMouseChanged: root.pointed = press.containsMouse ? choice.index : (root.pointed === choice.index ? -1 : root.pointed)
                        onPressed: {
                            choice.fired = false;
                            root.held = choice.index;
                        }
                        onReleased: root.held = -1
                        onCanceled: root.held = -1
                    }
                }
            }
        }
    }
}
