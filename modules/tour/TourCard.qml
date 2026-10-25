pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "../../services/tour.js" as Logic

Item {
    id: root

    property string mode: "ask"
    property string title: ""
    property string intro: ""
    property string line: ""
    property string after: ""
    property string chord: ""
    property string primary: ""
    property string secondary: ""
    property string tailEdge: ""
    property real tailAt: 0
    property int number: 1
    property int count: 5

    signal primaryPressed
    signal secondaryPressed
    signal quit
    signal closed

    readonly property real pad: Appearance.padding.card
    readonly property bool stepping: root.mode === "ask" || root.mode === "seen"
    readonly property real tailSize: Appearance.padding.huge

    implicitWidth: Math.ceil(glyph.advanceWidth * 32 + root.pad * 2)
    implicitHeight: body.implicitHeight + root.pad * 2

    TextMetrics {
        id: glyph

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.normal
        text: "M"
    }

    component Words: Flow {
        id: words

        property string text: ""
        property color colour: Appearance.colour.text

        spacing: 0

        TextMetrics {
            id: space

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.normal
            text: " "
        }

        Repeater {
            model: Logic.tokens(words.text, root.chord)

            Item {
                id: token

                required property var modelData

                readonly property bool typed: token.modelData.kind === "typed"

                readonly property real lead: front.text !== "" ? front.width + space.advanceWidth : 0

                width: token.lead + piece.width + rest.width + (token.typed ? Appearance.padding.hair : 0) + space.advanceWidth
                height: piece.height

                StyledText {
                    id: front

                    text: token.modelData.before ?? ""
                    font.pixelSize: Appearance.font.size.normal
                    color: words.colour
                }

                SquircleRect {
                    visible: token.typed
                    x: token.lead - Appearance.padding.hair
                    width: piece.width + Appearance.padding.hair * 2
                    height: piece.height
                    pill: "place"
                    color: Appearance.colour.fillStrong
                }

                StyledText {
                    id: piece

                    x: token.lead
                    text: token.modelData.text
                    font.pixelSize: Appearance.font.size.normal
                    color: token.modelData.kind === "key" ? Appearance.colour.accent : token.typed ? Appearance.colour.text : words.colour
                }

                StyledText {
                    id: rest

                    x: token.lead + piece.width + (token.typed ? Appearance.padding.hair : 0)
                    text: token.modelData.after
                    font.pixelSize: Appearance.font.size.normal
                    color: words.colour
                }
            }
        }
    }

    DropShadow {
        anchors.fill: parent
        radius: Appearance.rounding.large
        blur: Appearance.padding.large
        offset.y: Math.round(Appearance.padding.small / 2)
    }

    SquircleRect {
        visible: root.tailEdge !== ""
        width: root.tailSize
        height: root.tailSize
        radius: Appearance.padding.hair
        rotation: 45
        color: Appearance.colour.island
        x: root.tailEdge === "left" ? -root.tailSize / 2 : root.tailEdge === "right" ? root.width - root.tailSize / 2 : root.tailAt - root.tailSize / 2
        y: root.tailEdge === "top" ? -root.tailSize / 2 : root.tailEdge === "bottom" ? root.height - root.tailSize / 2 : root.tailAt - root.tailSize / 2
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colour.island
    }

    Column {
        id: body

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Appearance.padding.normal

        Item {
            width: body.width
            height: Math.max(pips.height, leave.height)
            visible: root.stepping

            Row {
                id: pips

                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.padding.hair

                Repeater {
                    model: root.count

                    SquircleRect {
                        required property int index

                        anchors.verticalCenter: parent.verticalCenter
                        pill: "object"
                        width: index + 1 === root.number ? Appearance.padding.large : Appearance.padding.small
                        height: Appearance.padding.small
                        color: index + 1 < root.number || (index + 1 === root.number && root.mode === "seen") ? Appearance.colour.accent : index + 1 === root.number ? Appearance.colour.text : Appearance.colour.fillStronger
                    }
                }
            }

            StyledText {
                anchors.left: pips.right
                anchors.leftMargin: Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter
                text: `${root.number} of ${root.count}`
                color: Appearance.colour.textFaint
            }

            StyledText {
                id: leave

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Skip the tour"
                color: tint.value

                FollowColour {
                    id: tint

                    target: leaveHover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
                }

                HoverHandler {
                    id: leaveHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: root.quit()
                }
            }
        }

        Row {
            width: body.width
            spacing: Appearance.padding.small

            Icon {
                id: mark

                anchors.verticalCenter: parent.verticalCenter
                name: "check_circle"
                fill: 1
                size: Appearance.icon.large
                color: Appearance.colour.accent
                visible: root.mode === "seen"
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: body.width - (mark.visible ? mark.width + parent.spacing : 0)
                text: root.title
                font.pixelSize: Appearance.font.size.large
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            width: body.width
            text: root.intro
            font.pixelSize: Appearance.font.size.normal
            color: Appearance.colour.textDim
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        Words {
            width: body.width
            text: root.line
            visible: root.line !== ""
        }

        Words {
            width: body.width
            text: root.after
            colour: Appearance.colour.textDim
            visible: root.after !== ""
        }

        Item {
            width: body.width
            height: Appearance.padding.hair
        }

        Row {
            anchors.right: parent.right
            spacing: Appearance.padding.small
            visible: root.primary !== "" || root.secondary !== ""

            Button {
                anchors.verticalCenter: parent.verticalCenter
                text: root.secondary
                style: "bare"
                size: 0
                visible: root.secondary !== ""

                onClicked: root.secondaryPressed()
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                text: root.primary
                style: "accent"
                size: 1
                visible: root.primary !== ""

                onClicked: root.primaryPressed()
            }
        }
    }

    TapHandler {
        enabled: root.mode === "parting"
        onTapped: root.closed()
    }
}
