import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string text: ""
    property string tip: ""
    property bool adder: false

    signal removed
    signal clicked

    implicitWidth: row.implicitWidth + (root.adder ? Appearance.padding.small + Appearance.padding.normal : Appearance.padding.normal + 4)
    implicitHeight: 32

    SquircleRect {
        anchors.fill: parent
        radius: height / 2
        cornerPower: 2
        color: root.adder ? "transparent" : Appearance.colour.fill
        stroke: root.adder ? Appearance.colour.fillStrong : "transparent"
        strokeWidth: root.adder ? Appearance.stroke.ring : 0
    }

    Row {
        id: row

        x: root.adder ? Appearance.padding.small : Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.adder
            name: "add"
            color: hover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.adder ? (hover.hovered ? Appearance.colour.text : Appearance.colour.textFaint) : Appearance.colour.textDim
        }

        SettingsTool {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.adder
            size: 28
            icon: "close"
            tip: root.tip
            onClicked: root.removed()
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        visible: root.adder
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
