import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: Files.zoomed(Appearance.padding.large)
        width: Math.min(parent.width * 0.7, Files.zoomed(520))

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter

            name: "build"
            size: Files.zoomed(Appearance.icon.hero)
            color: Appearance.colour.textFaint
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: "The browser's helpers have not been built."
            font.pixelSize: Files.zoomed(Appearance.font.size.normal)
            wrapMode: Text.Wrap
        }

        SquircleRect {
            anchors.horizontalCenter: parent.horizontalCenter

            implicitWidth: command.implicitWidth + Files.zoomed(Appearance.padding.large) * 2
            implicitHeight: command.implicitHeight + Files.zoomed(Appearance.padding.normal) * 2

            radius: Appearance.rounding.small
            color: Appearance.colour.fill

            StyledText {
                id: command

                anchors.centerIn: parent

                text: "banditshell dev build"
                font.pixelSize: Files.zoomed(Appearance.font.size.small)
                color: Appearance.colour.accent
            }
        }
    }
}
