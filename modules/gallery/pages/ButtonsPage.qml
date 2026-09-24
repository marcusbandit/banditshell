pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// Buttons, by TABS and SECTIONS - the layout is Google's; the look is this
// shell's.
//
// The COLOR tab: the whole emphasis system on one grid, three columns by
// five rows. Long words label the cells themselves; the legend beside it
// spells the markers out.
//
// The STATES tab: a test grid for the state colour sets - five columns
// (enabled, disabled, hovered, focused, pressed) by three rows (the default
// look, the selected toggle, the unselected toggle). Disabled is the one set
// that exists so far beyond enabled: sad colours, same shapes - and a
// disabled latched toggle keeps its square. The hovered, focused and pressed
// cells show the enabled look until their sets are specced.
//
// Every toggle cell is LIVE: press it and it walks its own reading - filled
// walks tonal<->filled; the outlined row fills with its own ring colour and
// drops the ring; the elevated row is shadowed both ways; on dark glass the
// tonal row loses its colour when off and is the tonal colour itself, no
// variation, when on. The text row has no toggle cells: text has nothing
// quieter to fall back to.
Item {
    id: page

    property bool drawn: true

    // Which tab is up.
    property string tab: "color"

    // A marker disc: one character in one colour; the label beside it takes
    // the same.
    component Marker: Item {
        id: marker

        property string label: ""
        property color base: Appearance.colour.text
        property bool square: false

        width: Appearance.sizes.minTarget
        height: width

        G2Rect {
            anchors.fill: parent
            radius: marker.square ? Appearance.rounding.normal : height / 2
            cornerPower: marker.square ? Appearance.rounding.power : 2
            color: marker.base
        }

        StyledText {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: inkOffsetX
            anchors.verticalCenterOffset: inkOffsetY
            text: marker.label
            color: Appearance.colour.ink
        }
    }

    // One legend row: a marker and the word it stands for, in the marker's colour.
    component LegendRow: Row {
        id: leg

        property string mark: ""
        property string label: ""
        property color tint: Appearance.colour.text
        property bool square: false

        spacing: Appearance.padding.small

        Marker {
            label: leg.mark
            base: leg.tint
            square: leg.square
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: leg.label
            color: leg.tint
        }
    }

    // A live latched cell: it owns the one bit of state the button refuses
    // to, and says which reading it is in.
    component StateCell: Item {
        id: cell

        property string style: "tonal"
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

        // ---- the tab switch ----

        Segments {
            anchors.horizontalCenter: parent.horizontalCenter
            options: ["color", "states"]
            current: ["color", "states"].indexOf(page.tab)

            onPicked: index => page.tab = ["color", "states"][index]
        }

        // ---- the color tab ----

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

            // The legend: two vertical lists, side by side.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.padding.huge

                Column {
                    spacing: Appearance.padding.small

                    LegendRow {
                        mark: "A"
                        label: "Elevated"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "B"
                        label: "Filled"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "C"
                        label: "Tonal"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "D"
                        label: "Outlined"
                        tint: Appearance.colour.spectrum[1]
                    }
                    LegendRow {
                        mark: "E"
                        label: "Text"
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
                        square: true
                    }
                }
            }

            // The grid: five emphases by three configurations.
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
                    text: "Elevated button"
                    style: "elevated"
                }

                StateCell {
                    wordOff: "Elevated unselected"
                    wordOn: "Elevated selected"
                    style: "elevated"
                }
                StateCell {
                    wordOff: "Elevated unselected"
                    wordOn: "Elevated selected"
                    style: "elevated"
                    latched: true
                }

                Marker {
                    label: "B"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Filled button"
                    style: "filled"
                }

                StateCell {
                    wordOff: "Filled unselected"
                    wordOn: "Filled selected"
                    style: "filled"
                }
                StateCell {
                    wordOff: "Filled unselected"
                    wordOn: "Filled selected"
                    style: "filled"
                    latched: true
                }

                Marker {
                    label: "C"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Tonal button"
                    style: "tonal"
                }

                StateCell {
                    wordOff: "Tonal unselected"
                    wordOn: "Tonal selected"
                    style: "tonal"
                }
                StateCell {
                    wordOff: "Tonal unselected"
                    wordOn: "Tonal selected"
                    style: "tonal"
                    latched: true
                }

                Marker {
                    label: "D"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Outlined button"
                    style: "outlined"
                }

                StateCell {
                    wordOff: "Outlined unselected"
                    wordOn: "Outlined selected"
                    style: "outlined"
                }
                StateCell {
                    wordOff: "Outlined unselected"
                    wordOn: "Outlined selected"
                    style: "outlined"
                    latched: true
                }

                Marker {
                    label: "E"
                    base: Appearance.colour.spectrum[1]
                }

                Button {
                    text: "Text button"
                    style: "text"
                }
            }
        }

        // ---- the states tab ----

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

            // The legend: the rows (letters) and the columns (numbers).
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

            // The grid: five states by three variant rows.
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
                    label: "B"
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
                    label: "C"
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
