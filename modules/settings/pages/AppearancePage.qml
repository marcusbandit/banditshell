pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// APPEARANCE: which palette the shell wears.
//
// The theme picker, and deliberately nothing else yet. Every other appearance
// decision already lives in config.json behind Appearance's tokens, so the
// page grows a control only when a setting earns one; the theme is first
// because it is the one people actually swap, and because `banditshell set
// theme slate` proving the live re-dress works is exactly the kind of thing
// that deserves a surface with no terminal in it.
//
// Rows come FROM Themes.names, so a palette added to config/Themes.qml appears
// here without this file changing: the page renders data, it does not keep a
// second list of what the data contains.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.small / 2

        // The same quiet eyebrow the icons page opens with, saying the one
        // thing a picker cannot show: there is no apply step. The write goes
        // straight to config.json and the whole shell re-binds.
        StyledText {
            text: `${Themes.names.length} palettes, worn immediately`
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        Repeater {
            model: Themes.names

            delegate: Item {
                id: row

                required property string modelData

                readonly property var theme: Themes.get(row.modelData)
                readonly property bool current: Config.values.theme === row.modelData
                readonly property bool hovered: press.containsMouse

                width: list.width
                // MenuRow's own maximum: the rowHeight floor, grown if the
                // label's line box plus its air ever outgrows it, so a type
                // scale change cannot quietly crop the row it is named in.
                height: Math.max(Appearance.sizes.rowHeight, name.implicitHeight + Appearance.padding.small * 2)

                // The full radius, for MenuRow's reason: at a small radius the
                // G2 ramp has no room to read and renders as the plain arc it
                // exists to replace.
                G2Rect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                    opacity: row.hovered ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // Before the content, MenuRow's lesson: a row-wide target
                // declared last would sit on top of whatever the row grows
                // later and eat its clicks. The swatches take no input today;
                // the order is so that stays a fact about the swatches.
                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Config.set("theme", row.modelData)
                }

                // The active row is marked by its NAME going accent, not by a
                // tinted row. A whole-row tint is the selection treatment, and
                // this is not a selection you are moving through a list: it is
                // a fact about one row, and the accent is the shell's colour
                // for state genuinely worth a colour. It is also self-proving:
                // the accent IS the active theme's, so the mark is drawn in
                // the very paint it is announcing.
                StyledText {
                    id: name

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    text: row.modelData
                    color: row.current ? Appearance.colour.accent : row.hovered ? Appearance.colour.text : Appearance.colour.textDim

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // WHAT THE THEME LOOKS LIKE, said in its own saturated end:
                // dim, mid, bright, the three accents a Theme block supplies,
                // drawn from the theme's data rather than listed by hand so a
                // theme cannot lie about itself here. The ramp is deliberately
                // not swatched: eleven near-neighbour greys in an 18px chip
                // read as dirt, and the accents are where palettes actually
                // differ.
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.padding.small / 2

                    Repeater {
                        model: [row.theme.dim, row.theme.mid, row.theme.bright]

                        delegate: G2Rect {
                            required property color modelData

                            // Sized from the type it sits beside rather than a
                            // number of its own: a swatch here is punctuation
                            // next to the name, not an exhibit.
                            width: Appearance.font.size.small
                            height: width
                            radius: Appearance.rounding.small
                            color: modelData
                        }
                    }
                }
            }
        }
    }
}
