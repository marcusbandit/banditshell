pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    required property var sheet

    readonly property string bareName: "NO MODIFIER"

    readonly property var bareParts: [
        {
            text: root.bareName,
            glyph: "",
            cells: root.bareName.length
        }
    ]

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: root.width
        spacing: Appearance.padding.normal

        StyledText {
            width: parent.width
            elide: Text.ElideRight
            visible: root.sheet.rows.length === 0

            text: root.sheet.reading ? `reading ${root.sheet.source}…` : `no binds in ${root.sheet.source}`
            color: Appearance.colour.textGhost
        }

        Repeater {
            model: root.sheet.sections

            delegate: Column {
                id: section

                required property var modelData
                required property int index

                width: list.width
                spacing: Appearance.padding.small

                readonly property var headParts: root.sheet.chordParts(section.modelData.mask, "")

                Item {
                    width: parent.width
                    height: Appearance.padding.normal
                    visible: section.index > 0

                    Separator {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                    }
                }

                Item {
                    width: parent.width
                    height: section.modelData.woven ? wovenHead.implicitHeight : heading.implicitHeight

                    Chord {
                        id: heading

                        visible: !section.modelData.woven

                        parts: section.headParts.length > 0 ? section.headParts : root.bareParts
                        advance: root.sheet.advance
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        id: wovenHead

                        anchors.verticalCenter: parent.verticalCenter

                        visible: section.modelData.woven

                        text: "woven in the source"
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        x: (section.modelData.woven ? wovenHead.implicitWidth : heading.implicitWidth) + Appearance.padding.small
                        width: Math.max(0, parent.width - (section.modelData.woven ? wovenHead.implicitWidth : heading.implicitWidth) - Appearance.padding.small)
                        elide: Text.ElideRight
                        visible: !!section.modelData.submap

                        text: section.modelData.submap ? `(${section.modelData.submap})` : ""
                        color: Appearance.colour.textFaint
                    }
                }

                Repeater {
                    model: section.modelData.rows

                    delegate: Item {
                        id: line

                        required property var modelData

                        width: section.width
                        height: chord.implicitHeight

                        Chord {
                            id: chord

                            width: Math.min(root.sheet.chordWidth, line.width)

                            clip: root.sheet.chordWidth > line.width

                            parts: root.sheet.rowParts(line.modelData)
                            advance: root.sheet.advance
                        }

                        StyledText {
                            x: root.sheet.chordWidth + root.sheet.gutter
                            width: Math.max(0, line.width - root.sheet.chordWidth - root.sheet.gutter)
                            elide: Text.ElideRight

                            text: line.modelData.action
                            color: Appearance.colour.textDim
                        }
                    }
                }
            }
        }
    }
}
