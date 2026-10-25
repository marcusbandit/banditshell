pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string mode: "ask"
    property string title: ""
    property string payoff: ""
    property string ask: ""
    property string away: ""
    property string chord: ""
    property string pointing: ""
    property int number: 1
    property int count: 5
    property bool offersButton: false

    signal passed
    signal quit
    signal finished
    signal showMe
    signal closed

    readonly property real pad: Appearance.padding.card
    readonly property bool asking: root.mode === "ask"
    readonly property bool stepping: root.mode === "ask" || root.mode === "seen"

    implicitWidth: Appearance.sizes.notificationWidth
    implicitHeight: body.implicitHeight + root.pad * 2

    readonly property string arrow: ({
            right: "arrow_back",
            rightTop: "arrow_back",
            rightBottom: "arrow_back",
            left: "arrow_forward",
            leftTop: "arrow_forward",
            leftBottom: "arrow_forward",
            above: "arrow_downward",
            below: "arrow_upward"
        })[root.pointing] ?? ""

    function marked(text: string): string {
        const safe = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        if (!root.chord || text.indexOf(root.chord) < 0)
            return safe(text);
        const at = text.indexOf(root.chord);
        return `${safe(text.slice(0, at))}<font color="${Appearance.colour.accent}">${safe(root.chord)}</font>${safe(text.slice(at + root.chord.length))}`;
    }

    DropShadow {
        anchors.fill: parent
        radius: Appearance.rounding.large
        blur: Appearance.padding.large
        offset.y: Math.round(Appearance.padding.small / 2)
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colour.island
        stroke: Appearance.colour.fillStrong
        strokeWidth: Appearance.stroke.line
    }

    Column {
        id: body

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: Appearance.padding.normal

        Item {
            width: body.width
            height: Math.max(pips.height, shut.height)

            Row {
                id: pips

                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.padding.hair
                visible: root.stepping

                Repeater {
                    model: root.count

                    SquircleRect {
                        required property int index

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
                visible: root.stepping
                text: `${root.number} of ${root.count}`
                color: Appearance.colour.textFaint
            }

            Button {
                id: shut

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                style: "bare"
                size: 0
                visible: root.mode !== "parting"

                onClicked: root.mode === "finished" ? root.finished() : root.quit()
            }
        }

        Row {
            width: body.width
            spacing: Appearance.padding.small

            Icon {
                id: mark

                anchors.verticalCenter: parent.verticalCenter
                name: root.mode === "seen" ? "check_circle" : root.mode === "finished" ? "flag" : root.arrow
                fill: root.mode === "seen" ? 1 : 0
                size: Appearance.icon.large
                color: Appearance.colour.accent
                visible: name !== ""
            }

            StyledText {
                width: body.width - (mark.visible ? mark.width + parent.spacing : 0)
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                font.pixelSize: Appearance.font.size.large
                wrapMode: Text.WordWrap
            }
        }

        StyledText {
            width: body.width
            text: root.payoff
            font.pixelSize: Appearance.font.size.normal
            color: Appearance.colour.textDim
            wrapMode: Text.WordWrap
        }

        StyledText {
            width: body.width
            text: root.marked(root.mode === "seen" ? root.away : root.ask)
            textFormat: Text.StyledText
            font.pixelSize: Appearance.font.size.normal
            wrapMode: Text.WordWrap
            visible: text !== ""
        }

        Item {
            width: body.width
            height: Appearance.padding.hair
        }

        Item {
            width: body.width
            height: buttons.height
            visible: root.mode !== "parting"

            Button {
                id: leave

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Skip the tour"
                style: "bare"
                size: 0
                visible: root.stepping && leave.implicitWidth + Appearance.padding.small + buttons.width <= parent.width

                onClicked: root.quit()
            }

            Row {
                id: buttons

                anchors.right: parent.right
                spacing: Appearance.padding.small

                Button {
                    text: "Skip this step"
                    style: "bare"
                    size: 0
                    visible: root.asking

                    onClicked: root.passed()
                }

                Button {
                    text: "Show me"
                    style: "accent"
                    size: 0
                    visible: root.asking && root.offersButton

                    onClicked: root.showMe()
                }

                Button {
                    text: "Next"
                    style: "accent"
                    size: 0
                    visible: root.mode === "seen"

                    onClicked: root.passed()
                }

                Button {
                    text: "Done"
                    style: "accent"
                    size: 0
                    visible: root.mode === "finished"

                    onClicked: root.finished()
                }
            }
        }
    }

    TapHandler {
        enabled: root.mode === "parting"
        onTapped: root.closed()
    }
}
