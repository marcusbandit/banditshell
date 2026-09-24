pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

// The gallery's face: the register down the left, the component under the
// light in the middle, the knobs on the right.
//
// It is drawn entirely out of the primitives it showcases - G2Rect plates,
// StyledText, Icon, Separator, Toggle, Segments, Slider - because a gallery
// that had to be drawn in some other idiom would be proving nothing. The
// register is `Registry`, which holds every component the shell means to own;
// this file only ever renders it, and adds no component knowledge of its own.
//
// Three columns, one question each: WHAT is here (nav), HOW DOES IT ANSWER
// (demo), and WHAT CAN I TURN (knobs). The middle is a Loader over the
// register's naming convention, so a page that does not exist yet draws as
// the placeholder instead of as an error, and building a component is
// dropping a file into pages/ and nothing else.
//
// The nav COLLAPSES, on Ctrl+B, inside this window only - the VS Code habit,
// and the pages want the room: a grid of buttons with real words on them is
// wider than three columns can give. The knobs are HIDDEN for now, on
// purpose: the pages are being argued with section by section (colour first,
// then state, then shape morph), and the knob panel comes back when the
// state section does - the plumbing below stays.
Item {
    id: root

    readonly property int navWidth: 250
    readonly property int knobWidth: 300
    readonly property int inset: Appearance.padding.normal

    // The nav's collapse, and the knobs' absence, as one number each: how
    // much room they claim between the window's edges and the content.
    property bool navCollapsed: false
    readonly property real navSpan: navCollapsed ? 0 : navWidth + inset * 2
    property bool showKnobs: false
    readonly property real knobSpan: showKnobs ? knobWidth + inset * 2 : inset

    // The entry on show, and the fallback when `current` names nothing: a
    // register with a typo should open on SOMETHING, not on a blank pane.
    readonly property var entry: Registry.entryFor(Registry.current) ?? Registry.entries[0]

    // The three states a page can be in, as colours straight off the theme.
    // `accent` stays rationed: done earns it, draft takes the middle of the
    // spectrum, planned is a ghost.
    function statusColour(status: string): color {
        if (status === "done")
            return Appearance.colour.accent;
        if (status === "draft")
            return Appearance.colour.spectrum[1];
        return Appearance.colour.textGhost;
    }

    // In-program, window-scoped: not a compositor hotkey, nothing global.
    // The keyboard belongs to whichever surface has it, and this one answers
    // for its own chrome.
    Shortcut {
        sequence: "Ctrl+B"
        onActivated: root.navCollapsed = !root.navCollapsed
    }

    // ---- the register ----

    Item {
        id: nav

        x: root.inset
        y: root.inset
        width: root.navSpan - root.inset * 2
        height: parent.height - root.inset * 2
        clip: true
        // The contents fade while the column folds, so the collapse reads as
        // the register leaving rather than as it being crushed.
        opacity: root.navCollapsed ? 0 : 1

        Behavior on width {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }

        Column {
            id: navHead

            width: parent.width

            StyledText {
                text: "banditshell"
                font.pixelSize: Appearance.font.size.normal
            }

            StyledText {
                text: `${Registry.drawn} of ${Registry.total} drawn`
                color: Appearance.colour.textFaint
            }
        }

        Separator {
            anchors.top: navHead.bottom
            anchors.topMargin: root.inset
            width: parent.width
        }

        Flickable {
            id: navScroll

            anchors.top: navHead.bottom
            anchors.topMargin: root.inset + 1
            anchors.bottom: parent.bottom
            width: parent.width
            contentWidth: width
            contentHeight: navCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Flickable does not answer the wheel on its own here, and the
            // register is 36 rows: a mouse without this stalls on the first
            // screenful. The rows sit ON TOP of this area and take the
            // clicks; the wheel, which none of them wants, falls through.
            MouseArea {
                anchors.fill: parent

                onWheel: wheel => {
                    const dy = wheel.angleDelta.y / 120 * Appearance.padding.huge;
                    navScroll.contentY = Math.max(0, Math.min(Math.max(0, navScroll.contentHeight - navScroll.height), navScroll.contentY - dy));
                }
            }

            Column {
                id: navCol

                width: parent.width

                Repeater {
                    model: Registry.sections

                    // One section: its name, then every entry in it. The
                    // grouping came from the entries themselves (Registry
                    // derives `sections`), so a new section is a new
                    // `section:` value, not a place to register one.
                    delegate: Column {
                        id: section

                        required property var modelData

                        width: navCol.width

                        StyledText {
                            x: Appearance.padding.small
                            y: Appearance.padding.normal
                            text: section.modelData.name
                            color: Appearance.colour.textFaint
                        }

                        Repeater {
                            model: section.modelData.entries

                            delegate: Item {
                                id: row

                                required property var modelData

                                readonly property bool taken: root.entry.key === row.modelData.key

                                width: navCol.width
                                height: Appearance.sizes.minTarget + Appearance.padding.small

                                G2Rect {
                                    anchors.fill: parent
                                    radius: Appearance.rounding.normal
                                    color: Appearance.colour.fill
                                    visible: row.taken
                                }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Appearance.padding.small
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Appearance.padding.small

                                    Icon {
                                        id: navIcon

                                        anchors.verticalCenter: parent.verticalCenter
                                        name: row.modelData.icon
                                        color: row.taken ? Appearance.colour.text : Appearance.colour.textFaint
                                    }

                                    StyledText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: row.width - Appearance.padding.small * 2 - navIcon.implicitWidth - parent.spacing - 12
                                        text: row.modelData.title
                                        color: row.taken ? Appearance.colour.text : Appearance.colour.textDim
                                        // Long names lose characters, not the
                                        // dot at the end of the row.
                                        elide: Text.ElideRight
                                    }
                                }

                                // The status dot, at the far end of the row.
                                G2Rect {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Appearance.padding.small
                                    anchors.verticalCenter: parent.verticalCenter

                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: root.statusColour(row.modelData.status)
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Registry.current = row.modelData.key
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Between nav and content, and again before the knobs: the columns are
    // different materials of one surface, and the hairline marks the join.
    Separator {
        visible: !root.navCollapsed
        x: root.inset + root.navSpan
        y: root.inset
        width: 1
        height: parent.height - root.inset * 2
    }

    // ---- the component under the light ----

    Item {
        id: content

        x: root.inset + root.navSpan + root.inset
        y: root.inset
        width: parent.width - x - root.knobSpan - root.inset
        height: parent.height - root.inset * 2

        Column {
            id: head

            width: parent.width

            Row {
                spacing: Appearance.padding.small

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.entry.title
                    font.pixelSize: Appearance.font.size.large
                }

                G2Rect {
                    anchors.verticalCenter: parent.verticalCenter

                    width: 8
                    height: 8
                    radius: 4
                    color: root.statusColour(root.entry.status)
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.entry.status
                    color: root.statusColour(root.entry.status)
                }
            }

            StyledText {
                width: head.width
                text: root.entry.blurb
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            StyledText {
                width: head.width
                text: `from the list: ${root.entry.checklist}`
                color: Appearance.colour.textGhost
                elide: Text.ElideRight
            }
        }

        G2Rect {
            id: stage

            anchors.top: head.bottom
            anchors.topMargin: root.inset
            anchors.bottom: parent.bottom
            width: parent.width
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            // The page IS the demo: whatever the file puts in itself, in here.
            // Its knobs (if it has any) are read by the panel on the right,
            // which is the only writer to the page's properties.
            Loader {
                id: demo

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                source: root.entry ? Registry.pageUrl(root.entry.key) : ""
            }

            // A page that does not exist yet, or one that exists and has not
            // drawn anything into itself: the same note, either way, because
            // the register is the whole list and the gallery is honest about
            // what is not here.
            Column {
                anchors.centerIn: parent
                spacing: Appearance.padding.small
                visible: !demo.item || !demo.item.drawn

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: root.entry.icon
                    size: Appearance.font.size.large * 2
                    color: Appearance.colour.textGhost
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "not drawn yet"
                    color: Appearance.colour.textDim
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.entry.ref ? `grows from ${root.entry.ref}` : "no primitive behind it yet"
                    color: Appearance.colour.textGhost
                }
            }
        }
    }

    // ---- the knobs (hidden for now; they return with the state section) ----

    Separator {
        visible: root.showKnobs
        x: parent.width - root.knobWidth - root.inset * 2 - 1
        y: root.inset
        width: 1
        height: parent.height - root.inset * 2
    }

    Knobs {
        visible: root.showKnobs
        x: parent.width - root.knobWidth - root.inset
        y: root.inset
        width: root.knobWidth
        height: parent.height - root.inset * 2
        page: demo.item
    }
}
