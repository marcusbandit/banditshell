pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config

Item {
    id: root

    readonly property int navWidth: 250
    readonly property int knobWidth: 300
    readonly property int inset: Appearance.padding.normal

    property bool navCollapsed: false
    readonly property real navSpan: navCollapsed ? 0 : navWidth + inset * 2
    property bool showKnobs: false
    readonly property real knobSpan: showKnobs ? knobWidth + inset * 2 : inset

    readonly property var entry: Registry.entryFor(Registry.current) ?? Registry.entries[0]

    function statusColour(status: string): color {
        if (status === "done")
            return Appearance.colour.accent;
        if (status === "draft")
            return Appearance.colour.spectrum[1];
        return Appearance.colour.textGhost;
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: root.navCollapsed = !root.navCollapsed
    }

    Item {
        id: nav

        x: root.inset
        y: root.inset
        width: navGlide.value
        height: parent.height - root.inset * 2
        clip: true

        opacity: navFade.value

        Follow {
            id: navGlide

            target: root.navSpan - root.inset * 2
            speed: Appearance.animation.trackSpeed
            startsAtTarget: true
        }

        Follow {
            id: navFade

            target: root.navCollapsed ? 0 : 1
            speed: Appearance.animation.trackSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        Column {
            id: navHead

            width: parent.width

            StyledText {
                text: "banditshell"
                font.pixelSize: Appearance.font.size.normal
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

                                SquircleRect {
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

                                        elide: Text.ElideRight
                                    }
                                }

                                SquircleRect {
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

    Separator {
        visible: !root.navCollapsed
        x: root.inset + root.navSpan
        y: root.inset
        width: 1
        height: parent.height - root.inset * 2
    }

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

                SquircleRect {
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
        }

        SquircleRect {
            id: stage

            anchors.top: head.bottom
            anchors.topMargin: root.inset
            anchors.bottom: parent.bottom
            width: parent.width
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            Loader {
                id: demo

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal
                source: root.entry ? Registry.pageUrl(root.entry.key) : ""
            }
        }
    }

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
