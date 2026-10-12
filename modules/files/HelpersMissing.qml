import QtQuick
import qs.config
import qs.components

Item {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: Appearance.padding.large
        width: Math.min(parent.width * 0.7, 520)

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter

            name: "build"
            size: Appearance.font.iconSize * 3
            color: Appearance.colour.textFaint
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: "The browser's helpers have not been built."
            font.pixelSize: Appearance.font.size.normal
            wrapMode: Text.Wrap
        }

        SquircleRect {
            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: command.implicitWidth + Appearance.padding.large * 2
            implicitHeight: command.implicitHeight + Appearance.padding.normal * 2

            radius: Appearance.rounding.small
            color: Appearance.colour.fill

            StyledText {
                id: command

                anchors.centerIn: parent

                text: "banditshell build"
                color: Appearance.colour.accent
            }
        }
    }
}
