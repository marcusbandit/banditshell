pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components

Item {
    id: root

    property string file: ""

    signal accepted

    function open(): void {
        root.visible = true;
        root.forceActiveFocus();
    }

    function close(): void {
        root.visible = false;
    }

    visible: false

    Keys.onEscapePressed: root.close()

    MouseArea {
        anchors.fill: parent
        enabled: root.visible

        Rectangle {
            anchors.fill: parent
            color: Appearance.colour.scrim
        }

        onClicked: root.close()
    }

    G2Rect {
        anchors.centerIn: parent
        width: Math.min(parent.width - Appearance.padding.huge * 2, 560)
        height: body.implicitHeight + Appearance.padding.normal * 2
        radius: Appearance.rounding.normal + Appearance.padding.small
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: Appearance.font.stem

        Column {
            id: body

            width: parent.width - Appearance.padding.normal * 2
            x: Appearance.padding.normal
            y: Appearance.padding.normal
            spacing: Appearance.padding.small

            StyledText {
                width: parent.width
                text: "Edits write the config file"
                font.pixelSize: Appearance.font.size.small
                font.letterSpacing: Appearance.font.stem
            }

            StyledText {
                width: parent.width
                wrapMode: Text.Wrap
                color: Appearance.colour.textDim
                text: root.file ? `Changes on this page are written straight into ${root.file} -- the file is yours, and this window edits it as you press. A change that would not parse is put back before the compositor reloads; one that would is live. This asks once.` : ""
            }

            Row {
                anchors.right: parent.right
                spacing: Appearance.padding.small

                Button {
                    text: "Leave it be"
                    style: "text"

                    onClicked: root.close()
                }

                Button {
                    text: "Edit the file"
                    style: "filled"

                    onClicked: {
                        root.accepted();
                        root.close();
                    }
                }
            }
        }
    }
}
