pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

Item {
    id: page

    property string tab: "color"

    component Marker: Item {
        id: marker

        property string label: ""
        property color base: Appearance.colour.text

        width: Appearance.sizes.minTarget
        height: width

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: marker.base
        }

        InkText {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: inkOffsetX
            anchors.verticalCenterOffset: inkOffsetY
            text: marker.label
            color: Appearance.colour.ink
        }
    }

    component LegendRow: Row {
        id: leg

        property string mark: ""
        property string label: ""
        property color tint: Appearance.colour.text

        spacing: Appearance.padding.small

        Marker {
            label: leg.mark
            base: leg.tint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: leg.label
            color: leg.tint
        }
    }

    component StateCell: Item {
        id: cell

        property string style: "plate"
        property string wordOff: ""
        property string wordOn: ""
        property bool latched: false
        property bool live: true

        width: btn.implicitWidth
        height: btn.implicitHeight

        Button {
            id: btn

            text: cell.latched ? cell.wordOn : cell.wordOff
            style: cell.style
            checkable: true
            checked: cell.latched
            interactive: cell.live
            onToggled: cell.latched = !cell.latched
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Appearance.padding.normal

        Segments {
            anchors.horizontalCenter: parent.horizontalCenter
            options: ["color", "states"]
            current: ["color", "states"].indexOf(page.tab)

            onPicked: index => page.tab = ["color", "states"][index]
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.tab === "color"
            spacing: Appearance.padding.normal

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "color"
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.textFaint
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.padding.huge

                Column {
                    spacing: Appearance.padding.small

                    LegendRow {
                        mark: "A"
                        label: "Accent"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "B"
                        label: "Plate"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "C"
                        label: "Ring"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "D"
                        label: "Bare"
                        tint: Appearance.colour.spectrum[1]
                    }
                }

                Column {
                    spacing: Appearance.padding.small

                    LegendRow {
                        mark: "1"
                        label: "Default"
                    }
                    LegendRow {
                        mark: "2"
                        label: "Toggle: unselected"
                    }
                    LegendRow {
                        mark: "3"
                        label: "Toggle: selected"
                    }
                }
            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 4
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                spacing: Appearance.padding.normal

                Item {
                    width: Appearance.sizes.minTarget
                    height: Appearance.sizes.minTarget
                }

                Marker {
                    label: "1"
                }

                Marker {
                    label: "2"
                }

                Marker {
                    label: "3"
                }

                Marker {
                    label: "A"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Accent button"
                    style: "accent"
                }

                StateCell {
                    wordOff: "Accent off"
                    wordOn: "Accent on"
                    style: "accent"
                }
                StateCell {
                    wordOff: "Accent off"
                    wordOn: "Accent on"
                    style: "accent"
                    latched: true
                }

                Marker {
                    label: "B"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Plate button"
                    style: "plate"
                }

                StateCell {
                    wordOff: "Plate off"
                    wordOn: "Plate on"
                    style: "plate"
                }
                StateCell {
                    wordOff: "Plate off"
                    wordOn: "Plate on"
                    style: "plate"
                    latched: true
                }

                Marker {
                    label: "C"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Ring button"
                    style: "ring"
                }

                StateCell {
                    wordOff: "Ring off"
                    wordOn: "Ring on"
                    style: "ring"
                }
                StateCell {
                    wordOff: "Ring off"
                    wordOn: "Ring on"
                    style: "ring"
                    latched: true
                }

                Marker {
                    label: "D"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Bare button"
                    style: "bare"
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.tab === "states"
            spacing: Appearance.padding.normal

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "states"
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.textFaint
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.padding.huge

                Column {
                    spacing: Appearance.padding.small

                    LegendRow {
                        mark: "A"
                        label: "Default"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "B"
                        label: "Selected"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "C"
                        label: "Unselected"
                        tint: Appearance.colour.spectrum[1]
                    }
                }

                Column {
                    spacing: Appearance.padding.small

                    LegendRow {
                        mark: "1"
                        label: "Enabled"
                    }
                    LegendRow {
                        mark: "2"
                        label: "Disabled"
                    }
                    LegendRow {
                        mark: "3"
                        label: "Hovered"
                    }
                    LegendRow {
                        mark: "4"
                        label: "Focused"
                    }
                    LegendRow {
                        mark: "5"
                        label: "Pressed"
                    }
                }
            }

            Grid {
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 6
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                spacing: Appearance.padding.normal

                Item {
                    width: Appearance.sizes.minTarget
                    height: Appearance.sizes.minTarget
                }

                Marker {
                    label: "1"
                }

                Marker {
                    label: "2"
                }

                Marker {
                    label: "3"
                }

                Marker {
                    label: "4"
                }

                Marker {
                    label: "5"
                }

                Marker {
                    label: "A"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Enabled"
                }

                Button {
                    text: "Disabled"
                    interactive: false
                }

                Button {
                    text: "Hovered"
                }

                Button {
                    text: "Focused"
                }

                Button {
                    text: "Pressed"
                }

                Marker {
                    label: "A"
                    base: Appearance.colour.spectrum[1]
                }

                StateCell {
                    wordOff: "Enabled"
                    wordOn: "Enabled"
                    latched: true
                }

                StateCell {
                    wordOff: "Disabled"
                    wordOn: "Disabled"
                    live: false
                }

                StateCell {
                    wordOff: "Hovered"
                    wordOn: "Hovered"
                    latched: true
                }

                StateCell {
                    wordOff: "Focused"
                    wordOn: "Focused"
                    latched: true
                }

                StateCell {
                    wordOff: "Pressed"
                    wordOn: "Pressed"
                    latched: true
                }

                Marker {
                    label: "B"
                    base: Appearance.colour.spectrum[1]
                }

                StateCell {
                    wordOff: "Enabled"
                    wordOn: "Enabled"
                }

                StateCell {
                    wordOff: "Disabled"
                    wordOn: "Disabled"
                    live: false
                }

                StateCell {
                    wordOff: "Hovered"
                    wordOn: "Hovered"
                }

                StateCell {
                    wordOff: "Focused"
                    wordOn: "Focused"
                }

                StateCell {
                    wordOff: "Pressed"
                    wordOn: "Pressed"
                }
            }
        }
    }
}
