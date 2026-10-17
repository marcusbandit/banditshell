pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Item {
    id: root

    readonly property var sections: [
        {title: "Places", rows: Files.places},
        {title: "Drives", rows: Files.drives}
    ]

    property string receiving: ""

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.small

        spacing: Appearance.padding.normal

        Repeater {
            model: root.sections

            delegate: Column {
                id: section

                required property var modelData

                width: parent.width
                spacing: 0

                visible: section.modelData.rows.length > 0

                StyledText {
                    text: section.modelData.title.toUpperCase()
                    font.pixelSize: Files.zoomed(Appearance.font.size.small)
                    font.letterSpacing: Files.zoomed(Appearance.font.size.small) * 0.12
                    color: Appearance.colour.textGhost

                    leftPadding: Appearance.padding.normal
                    bottomPadding: Appearance.padding.hair
                    topPadding: Appearance.padding.small
                }

                Repeater {
                    model: section.modelData.rows

                    delegate: Item {
                        id: place

                        required property var modelData

                        objectName: place.modelData.path

                        readonly property bool here: Files.cwd === place.modelData.path

                        readonly property var usage: place.modelData.usage ?? null

                        width: section.width

                        height: Appearance.sizes.filesRow * (place.usage ? 1.5 : 1)

                        SquircleRect {
                            anchors.fill: parent
                            anchors.rightMargin: Appearance.padding.small

                            radius: Appearance.rounding.small
                            color: root.receiving === place.modelData.path ? Appearance.colour.accentFill : place.here ? Appearance.colour.fillStrong : hover.hovered ? Appearance.colour.fill : "transparent"
                            stroke: root.receiving === place.modelData.path ? Appearance.colour.accent : "transparent"
                            strokeWidth: root.receiving === place.modelData.path ? Appearance.stroke.ring : 0
                        }

                        Icon {
                            id: glyph

                            anchors.left: parent.left
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.verticalCenter: place.usage ? undefined : parent.verticalCenter
                            anchors.top: place.usage ? parent.top : undefined
                            anchors.topMargin: place.usage ? Appearance.padding.hair : 0

                            name: place.modelData.icon
                            size: Files.zoomed(Appearance.font.iconSize)
                            color: place.here ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        StyledText {
                            anchors.left: glyph.right
                            anchors.leftMargin: Appearance.padding.small
                            anchors.right: detail.left
                            anchors.rightMargin: Appearance.padding.small
                            anchors.verticalCenter: glyph.verticalCenter

                            text: place.modelData.name
                            font.pixelSize: Files.zoomed(Appearance.font.size.small)
                            elide: Text.ElideRight
                            color: place.here ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        StyledText {
                            id: detail

                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.verticalCenter: glyph.verticalCenter

                            text: place.modelData.detail ?? ""
                            font.pixelSize: Files.zoomed(Appearance.font.size.small)
                            color: Appearance.colour.textGhost
                        }

                        Item {
                            visible: !!place.usage

                            anchors.left: glyph.left
                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Appearance.padding.small

                            implicitHeight: Appearance.font.stem * 2

                            SquircleRect {
                                anchors.fill: parent

                                radius: height / 2
                                color: Appearance.colour.fill
                            }

                            SquircleRect {
                                width: Math.max(parent.height, parent.width * (place.usage ? place.usage.fraction : 0))
                                height: parent.height

                                radius: height / 2
                                color: place.usage && place.usage.fraction > 0.9 ? Appearance.colour.alarm : hover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
                            }
                        }

                        HoverTip {
                            id: hover

                            text: place.usage ? `${Files.humanSize(place.usage.used)} of ${Files.humanSize(place.usage.size)} used  ·  ${Math.round(place.usage.fraction * 100)}%` : place.modelData.path
                        }

                        TapHandler {
                            onTapped: Files.go(place.modelData.path)
                        }
                    }
                }
            }
        }
    }

    function pathAt(position: point): string {
        if (position.x < 0 || position.x > root.width || position.y < 0 || position.y > root.height)
            return "";

        const local = column.mapFromItem(root, position.x, position.y);
        const section = column.childAt(local.x, local.y);
        if (!section)
            return "";

        const inner = section.mapFromItem(column, local.x, local.y);
        const row = section.childAt(inner.x, inner.y);
        return row ? row.objectName : "";
    }
}
