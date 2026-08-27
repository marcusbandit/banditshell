pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// WHERE YOU KEEP GOING, down the left.
//
// Two lists, and the split between them is the classic one because it is the
// right one: PLACES are directories you chose to care about, DRIVES are hardware
// that happens to be mounted. One is about your work and the other is about the
// machine, and they change for completely different reasons - a place is there
// every day, a drive appears when you plug it in.
//
// Nothing here is user-editable yet. The places are the XDG directories, which
// is what every file manager starts with, and the drives are whatever is
// mounted; pinning an arbitrary folder is the obvious next thing and is
// deliberately not guessed at here.
Item {
    id: root

    readonly property var sections: [
        {title: "Places", rows: Files.places},
        {title: "Drives", rows: Files.drives}
    ]

    // The row something is being dragged over, as a path, or "". A place is a
    // directory like any other, so dropping files on it moves them there.
    property string receiving: ""

    Column {
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
                // A HEADING OVER NOTHING IS NOISE. An empty Drives section on a
                // laptop with nothing plugged in is a permanent reminder that
                // nothing is plugged in.
                visible: section.modelData.rows.length > 0

                StyledText {
                    // The section's name, at the quiet weight and in capitals,
                    // which is how this shell says "label" without spending a
                    // font size on it (~/.claude/rules/type-scale.md).
                    text: section.modelData.title.toUpperCase()
                    font.pixelSize: Appearance.sizes.filesText
                    font.letterSpacing: Appearance.sizes.filesText * 0.12
                    color: Appearance.colour.textGhost

                    leftPadding: Appearance.padding.normal
                    bottomPadding: Appearance.padding.small / 2
                    topPadding: Appearance.padding.small
                }

                Repeater {
                    model: section.modelData.rows

                    delegate: Item {
                        id: place

                        required property var modelData

                        readonly property bool here: Files.cwd === place.modelData.path

                        readonly property var usage: place.modelData.usage ?? null

                        width: section.width
                        // A DRIVE IS A TALLER ROW, because it has a bar under
                        // it. Derived from whether there is a bar rather than
                        // set per section, so a place and a drive that both had
                        // one would both get the room.
                        height: place.usage ? Appearance.sizes.filesRow * 1.5 : Appearance.sizes.filesRow

                        G2Rect {
                            anchors.fill: parent
                            anchors.rightMargin: Appearance.padding.small

                            radius: Appearance.rounding.small
                            color: root.receiving === place.modelData.path ? Appearance.colour.accentFill : place.here ? Appearance.colour.fillStrong : hover.hovered ? Appearance.colour.fill : "transparent"
                            stroke: root.receiving === place.modelData.path ? Appearance.colour.accent : "transparent"
                            strokeWidth: root.receiving === place.modelData.path ? Appearance.font.stem : 0
                        }

                        Icon {
                            id: glyph

                            anchors.left: parent.left
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.verticalCenter: place.usage ? undefined : parent.verticalCenter
                            anchors.top: place.usage ? parent.top : undefined
                            anchors.topMargin: place.usage ? Appearance.padding.small / 2 : 0

                            name: place.modelData.icon
                            size: Appearance.sizes.filesText * 1.2
                            color: place.here ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        StyledText {
                            anchors.left: glyph.right
                            anchors.leftMargin: Appearance.padding.small
                            anchors.right: detail.left
                            anchors.rightMargin: Appearance.padding.small
                            anchors.verticalCenter: glyph.verticalCenter

                            text: place.modelData.name
                            font.pixelSize: Appearance.sizes.filesText
                            elide: Text.ElideRight
                            color: place.here ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        StyledText {
                            id: detail

                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.verticalCenter: glyph.verticalCenter

                            // The size of a drive, and nothing at all for a
                            // place: "how big is Downloads" is not a question
                            // this row is answering.
                            text: place.modelData.detail ?? ""
                            font.pixelSize: Appearance.sizes.filesText
                            color: Appearance.colour.textGhost
                        }

                        // HOW FULL IT IS, as a bar rather than a percentage.
                        //
                        // A number is a thing to read and compare; a bar is a
                        // thing you see without reading, which is what you
                        // actually want from a sidebar you are glancing at on
                        // the way somewhere else. The figures are there on hover
                        // for when the answer matters.
                        //
                        // It goes ACCENT when the drive is nearly full, which is
                        // the one state worth a colour here: a disk at 96% is
                        // about to become somebody's afternoon.
                        Item {
                            visible: !!place.usage

                            anchors.left: glyph.left
                            anchors.right: parent.right
                            anchors.rightMargin: Appearance.padding.normal
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Appearance.padding.small

                            implicitHeight: Appearance.font.stem * 2

                            G2Rect {
                                anchors.fill: parent

                                radius: height / 2
                                color: Appearance.colour.fill
                            }

                            G2Rect {
                                width: Math.max(parent.height, parent.width * (place.usage ? place.usage.fraction : 0))
                                height: parent.height

                                radius: height / 2
                                color: place.usage && place.usage.fraction > 0.9 ? Appearance.colour.alarm : hover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
                            }
                        }

                        // HoverTip IS the hover handler - it is a HoverHandler
                        // with a label on it - so there is only one here rather
                        // than one for the tip and one for the highlight.
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

    // WHICH ROW IS UNDER A POINT, for the same reason the path bar has one:
    // during a drag the ghost is under the cursor and takes every hover with it,
    // so a row cannot know on its own that it is the one being aimed at.
    //
    // Worked out by walking the sections in the order they are drawn rather than
    // by hit-testing items, because that IS the layout - there is no second copy
    // of where things are, so this cannot disagree with what is on screen.
    function pathAt(position: point): string {
        if (position.x < 0 || position.x > root.width || position.y < 0)
            return "";

        const pad = Appearance.padding.small;
        const heading = Math.round(Appearance.sizes.filesText * 4 / 3) + pad + pad / 2;
        let y = pad;

        for (const section of root.sections) {
            if (section.rows.length === 0)
                continue;
            y += heading;
            for (const row of section.rows) {
                if (position.y >= y && position.y < y + Appearance.sizes.filesRow)
                    return row.path;
                y += Appearance.sizes.filesRow;
            }
            y += Appearance.padding.normal;
        }

        return "";
    }
}
