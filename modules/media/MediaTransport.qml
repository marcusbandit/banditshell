pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    readonly property real glyph: Appearance.font.iconSize * root.zoom
    readonly property real ring: (Appearance.font.iconSize + Appearance.padding.normal * 2) * root.zoom

    property real zoom: 1.0

    implicitWidth: row.implicitWidth
    implicitHeight: root.ring

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.padding.large * root.zoom

        Repeater {
            model: [
                {
                    icon: "skip_previous",
                    action: "previous",
                    enabled: !!Media.active?.canGoPrevious
                },
                {
                    icon: Media.playing ? "pause" : "play_arrow",
                    action: "toggle",
                    enabled: true,
                    primary: true
                },
                {
                    icon: "skip_next",
                    action: "next",
                    enabled: !!Media.active?.canGoNext
                }
            ]

            delegate: Item {
                id: button

                required property var modelData

                width: root.ring
                height: root.ring

                scale: press.pressed ? 0.94 : press.containsMouse ? 1.12 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }

                G2Rect {
                    anchors.fill: parent
                    visible: !!button.modelData.primary
                    radius: width / 2
                    color: "transparent"
                    stroke: Appearance.colour.text
                    strokeWidth: Appearance.font.stem
                }

                Icon {
                    anchors.centerIn: parent
                    size: root.glyph
                    name: button.modelData.icon
                    color: button.modelData.enabled ? Appearance.colour.text : Appearance.colour.textFaint
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (button.modelData.action === "toggle")
                            Media.toggle();
                        else if (button.modelData.action === "next")
                            Media.next();
                        else
                            Media.previous();
                    }
                }
            }
        }
    }
}
