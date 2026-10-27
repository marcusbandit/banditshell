import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""
    property string glyph: ""
    property color tone: Appearance.colour.accent
    property string title: ""
    property string subtitle: ""

    signal closed

    readonly property real gap: Appearance.padding.normal
    readonly property real inset: badge.width + root.gap

    implicitHeight: Math.max(badge.height, titles.implicitHeight, shut.implicitHeight)

    Icon {
        id: badge

        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        glyph: root.glyph
        size: Appearance.font.line.large + Appearance.padding.small * 2
        fill: 1
        color: root.tone
    }

    Column {
        id: titles

        anchors.left: badge.right
        anchors.leftMargin: root.gap
        anchors.right: shut.left
        anchors.rightMargin: root.gap
        anchors.verticalCenter: parent.verticalCenter

        StyledText {
            width: parent.width
            text: root.title
            font.pixelSize: Appearance.font.size.large
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: !!root.subtitle
            text: root.subtitle
            color: Appearance.colour.textDim
            elide: Text.ElideRight
        }
    }

    Button {
        id: shut

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        icon: "close"
        style: "bare"
        onClicked: root.closed()
    }
}
