import QtQuick
import qs.config
import qs.components

Item {
    id: root

    required property var answer

    property string typed: ""
    property bool holds: false
    property bool offersSymbols: false
    property bool symbolsOpen: false

    signal copied
    signal symbols

    readonly property string question: root.answer?.question ?? root.typed
    readonly property string asked: root.answer?.asked ?? ""
    readonly property string said: root.answer?.text ?? ""
    readonly property string told: root.answer?.detail ?? ""
    readonly property bool captioned: root.asked !== "" || root.told !== ""
    readonly property real half: (card.width - Appearance.padding.large * 4 - arrow.width) / 2

    visible: !!root.answer
    implicitHeight: visible ? head.height + Appearance.padding.small + card.height : 0
    height: implicitHeight

    Item {
        id: head

        width: parent.width
        height: Math.max(Appearance.font.line.small, symbolsButton.visible ? symbolsButton.height : 0)

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            text: root.answer?.section ?? (root.answer?.money ? "Currency" : root.answer?.swatch ? "Colour" : root.answer?.icon === "event" ? "Date" : "Calculator")
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.normal

            Button {
                id: symbolsButton

                visible: root.offersSymbols && !root.answer?.money && !root.answer?.icon && !root.answer?.section
                anchors.verticalCenter: parent.verticalCenter
                icon: "function"
                text: "Symbols"
                style: "ring"
                size: 0
                checkable: true
                checked: root.symbolsOpen
                onToggled: root.symbols()
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Enter copies"
                font.pixelSize: Appearance.font.size.small
                color: hint.value

                FollowColour {
                    id: hint

                    target: root.holds ? Appearance.colour.accent : Appearance.colour.textFaint
                    speed: Appearance.animation.revealSpeed
                }
            }
        }
    }

    SquircleRect {
        id: card

        y: head.height + Appearance.padding.small
        width: parent.width
        height: Appearance.padding.large * 2 + Appearance.font.line.large * 1.5 + (root.captioned ? Appearance.padding.normal + Appearance.font.line.small + Appearance.padding.small * 2 : 0)
        radius: Appearance.rounding.normal
        color: plate.value

        FollowColour {
            id: plate

            target: root.holds ? Appearance.colour.fillStrong : press.containsMouse ? Appearance.colour.fill : Appearance.colour.tile
            speed: Appearance.animation.revealSpeed
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: Appearance.padding.normal
            anchors.bottomMargin: Appearance.padding.normal
            width: Appearance.stroke.line
            color: Appearance.colour.separator
        }

        Item {
            id: arrow

            anchors.centerIn: parent
            width: Appearance.icon.large
            height: width

            SquircleRect {
                anchors.fill: parent
                pill: "object"
                color: plate.value
            }

            Icon {
                anchors.centerIn: parent
                name: "arrow_forward"
                size: Appearance.icon.normal
                color: Appearance.colour.textDim
            }
        }

        Repeater {
            model: [
                {
                    big: root.question,
                    caption: root.asked,
                    swatch: "",
                    dim: true
                },
                {
                    big: root.said,
                    caption: root.told,
                    swatch: root.answer?.swatch ?? "",
                    dim: false
                }
            ]

            delegate: Column {
                id: side

                required property var modelData
                required property int index

                x: side.index === 0 ? Appearance.padding.large : card.width - Appearance.padding.large - root.half
                anchors.verticalCenter: parent.verticalCenter
                width: root.half
                spacing: Appearance.padding.normal

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.padding.normal

                    SquircleRect {
                        visible: side.modelData.swatch !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.font.size.display
                        height: width
                        radius: Appearance.rounding.small
                        color: side.modelData.swatch || "transparent"
                        stroke: Appearance.colour.seam
                        strokeWidth: Appearance.stroke.line
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, side.width - (side.modelData.swatch ? Appearance.font.size.display + Appearance.padding.normal : 0))
                        text: side.modelData.big
                        font.pixelSize: Appearance.font.size.display
                        font.weight: Font.DemiBold
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: Appearance.font.size.large
                        horizontalAlignment: Text.AlignHCenter
                        color: side.modelData.dim ? Appearance.colour.textDim : Appearance.colour.text
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                Item {
                    visible: side.modelData.caption !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(side.width, captionText.implicitWidth + Appearance.padding.normal * 2)
                    height: captionText.implicitHeight + Appearance.padding.small * 2

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: Appearance.colour.fill
                    }

                    StyledText {
                        id: captionText

                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, side.width - Appearance.padding.normal * 2)
                        horizontalAlignment: Text.AlignHCenter
                        text: side.modelData.caption
                        font.pixelSize: Appearance.font.size.small
                        color: Appearance.colour.textDim
                        elide: Text.ElideRight
                    }
                }
            }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.copied()
        }
    }
}
