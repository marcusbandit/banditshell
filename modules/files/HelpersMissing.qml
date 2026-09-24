import QtQuick
import qs.config
import qs.components
import qs.services

// The one thing this window cannot do without.
//
// bin/bs-ls and bin/bs-pty are compiled from src/ and deliberately not committed
// (they are ELF for one architecture; see .gitignore), so a fresh clone has
// neither and the browser can neither list a directory nor open a shell. Saying
// so, with the command that fixes it, is the difference between a bug and a
// setup step.
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

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: `A terminal needs a pty and a listing needs readdir, and QML has neither. Both are one small C program in src/, compiled next to their source the way the shaders are.`
            color: Appearance.colour.textFaint
            wrapMode: Text.Wrap
        }

        G2Rect {
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
