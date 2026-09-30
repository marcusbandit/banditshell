pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property var actions: []

    property real labelSize: Appearance.font.size.small
    property bool interactive: true

    signal triggered(int index)

    implicitWidth: row.width
    implicitHeight: Math.max(Appearance.sizes.minTarget, Math.round(labelSize * 4 / 3) + Appearance.padding.small * 2)
    width: implicitWidth
    height: implicitHeight

    opacity: root.interactive ? 1 : 0.45

    SquircleRect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fillStrong
    }

    Row {
        id: row

        Repeater {
            model: root.actions

            delegate: Item {
                id: member

                required property var modelData
                required property int index

                readonly property bool hasText: (modelData.text ?? "") !== ""
                readonly property bool hasIcon: (modelData.icon ?? "") !== ""
                readonly property real markSpan: member.hasIcon ? root.labelSize + (member.hasText ? Appearance.padding.small : 0) : 0

                readonly property bool hovered: root.interactive && press.containsMouse
                readonly property bool pressed: root.interactive && press.pressed

                TextMetrics {
                    id: ink

                    font.family: Appearance.font.family
                    font.pixelSize: root.labelSize
                    text: member.hasText ? member.modelData.text : ""
                }

                width: (member.hasText ? Math.ceil(ink.width) : 0) + member.markSpan + Appearance.padding.normal * 2
                height: root.height

                SquircleRect {
                    anchors.fill: parent
                    visible: member.hovered || member.pressed
                    radius: height / 2
                    topLeftRadius: member.index === 0 ? height / 2 : 0
                    bottomLeftRadius: member.index === 0 ? height / 2 : 0
                    topRightRadius: member.index === root.actions.length - 1 ? height / 2 : 0
                    bottomRightRadius: member.index === root.actions.length - 1 ? height / 2 : 0
                    color: Appearance.colour.fillStronger
                }

                scale: member.pressed ? 0.96 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: member.hasText && member.hasIcon ? Appearance.padding.small : 0

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: member.hasIcon
                        name: member.hasIcon ? member.modelData.icon : ""
                        size: root.labelSize
                        color: Appearance.colour.text
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: member.hasText
                        text: member.hasText ? member.modelData.text : ""
                        font.pixelSize: root.labelSize
                        color: Appearance.colour.text
                    }
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.triggered(member.index)
                }
            }
        }
    }
}
