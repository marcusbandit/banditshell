pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

Item {
    id: page

    property bool shown: true
    property bool checked: true
    property int taken: 1

    readonly property var knobs: [
        {
            kind: "toggle",
            prop: "shown",
            label: "focused",
            initial: true
        }
    ]

    component Tile: SquircleRect {
        id: tile

        property bool picked: false
        property bool focused: false
        property string caption: ""

        width: Appearance.sizes.filesTile
        height: Math.round(width * 1.18)
        color: tile.picked ? Appearance.colour.fillStrong : "transparent"

        Icon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -Appearance.padding.normal
            name: "image"
            size: Appearance.icon.large
            color: Appearance.colour.textDim
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Appearance.padding.small
            text: tile.caption
            color: tile.picked || tile.focused ? Appearance.colour.text : Appearance.colour.textDim
        }

        FocusMark {
            shown: tile.focused
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Appearance.padding.huge

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.huge

            Button {
                anchors.verticalCenter: parent.verticalCenter
                style: "accent"
                icon: "check"
                text: "Set"

                FocusMark {
                    pill: "object"
                    shown: page.shown
                }
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                icon: "shuffle"

                FocusMark {
                    pill: "object"
                    shown: page.shown
                }
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: page.checked
                onToggled: page.checked = !page.checked

                FocusMark {
                    pill: "place"
                    shown: page.shown
                }
            }

            Segments {
                anchors.verticalCenter: parent.verticalCenter
                options: ["Hour", "Day", "Week"]
                current: page.taken
                onPicked: index => page.taken = index

                FocusMark {
                    pill: "place"
                    shown: page.shown
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.small

            Tile {
                caption: "selected"
                picked: true
            }

            Tile {
                caption: "both"
                picked: true
                focused: page.shown
            }

            Tile {
                caption: "focused"
                focused: page.shown
            }

            Tile {
                caption: "neither"
            }
        }
    }
}
