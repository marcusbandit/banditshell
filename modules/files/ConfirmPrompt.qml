pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "../../services/files-find.js" as Find

Item {
    id: root

    property string name: ""
    property string sentence: ""
    property string verb: ""
    property string icon: ""
    property var accepted: null
    property var rows: []

    property bool up: false
    property bool confirming: false

    signal dismissed

    function ask(name: string, sentence: string, verb: string, icon: string, onAnswer: var, rows: var): void {
        root.rows = rows ?? [];
        root.name = name;
        root.sentence = sentence;
        root.verb = verb;
        root.icon = icon;
        root.accepted = onAnswer;
        root.confirming = false;
        root.up = true;
        Qt.callLater(() => keys.forceActiveFocus());
    }

    function close(): void {
        root.up = false;
        root.accepted = null;
        root.dismissed();
    }

    function answer(choice: string): void {
        const run = root.accepted;
        root.close();
        if (run)
            run(choice);
    }

    function press(): void {
        if (root.confirming)
            root.answer(root.verb.toLowerCase());
        else
            root.close();
    }

    visible: root.up || fade.value > 0
    opacity: fade.value

    Follow {
        id: fade

        target: root.up ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Rectangle {
        anchors.fill: parent
        color: Appearance.colour.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    SquircleRect {
        anchors.centerIn: parent

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, root.rows.length > 0 ? 760 : 420)
        implicitHeight: body.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.large
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.separator
        strokeWidth: Appearance.stroke.ring

        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: body

            anchors.centerIn: parent
            width: parent.width - Appearance.padding.large * 2
            spacing: Appearance.padding.normal

            Column {
                width: parent.width

                StyledText {
                    width: parent.width

                    text: root.name
                    font.pixelSize: Appearance.font.size.normal
                    elide: Text.ElideMiddle
                }

                Item {
                    id: listing

                    width: parent.width
                    height: table.height + Appearance.padding.normal * 2
                    visible: root.rows.length > 0

                    readonly property real sizeWidth: digit.advanceWidth * 9
                    readonly property real nameWidth: (width - sizeWidth) * 0.42

                    TextMetrics {
                        id: digit

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.small
                        text: "0"
                    }

                    ListView {
                        id: table

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Math.min(table.contentHeight, root.height * 0.45)

                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.rows

                        WheelStep {
                            flick: table
                        }

                        delegate: Item {
                            id: line

                            required property var modelData

                            width: table.width
                            height: Appearance.font.line.small + Appearance.padding.small * 2

                            Row {
                                id: named

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: listing.nameWidth
                                spacing: Appearance.padding.small

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, named.width - (hiddenMark.visible ? hiddenMark.width + named.spacing : 0))
                                    text: line.modelData.name
                                    elide: Text.ElideMiddle
                                }

                                TrashMark {
                                    id: hiddenMark

                                    anchors.verticalCenter: parent.verticalCenter

                                    visible: line.modelData.hidden
                                    icon: "visibility_off"
                                    text: "hidden"
                                }
                            }

                            Row {
                                id: whence

                                anchors.left: named.right
                                anchors.leftMargin: Appearance.padding.normal
                                anchors.right: amount.left
                                anchors.rightMargin: Appearance.padding.normal
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Appearance.padding.small

                                TrashMark {
                                    id: driveMark

                                    anchors.verticalCenter: parent.verticalCenter

                                    visible: line.modelData.drive !== ""
                                    icon: "hard_drive"
                                    text: line.modelData.drive
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    readonly property real room: whence.width - (driveMark.visible ? driveMark.width + whence.spacing : 0)

                                    width: room
                                    text: Find.fitTail(line.modelData.origin, Math.max(1, Math.floor(room / Math.max(1, digit.advanceWidth))))
                                    color: Appearance.colour.textDim
                                }
                            }

                            StyledText {
                                id: amount

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: listing.sizeWidth

                                horizontalAlignment: Text.AlignRight
                                text: line.modelData.size
                                color: Appearance.colour.textDim
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width

                    text: root.sentence
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                    wrapMode: Text.WordWrap
                }
            }

            Row {
                anchors.right: parent.right
                spacing: Appearance.padding.small

                Button {
                    style: "ring"
                    text: "Cancel"

                    onClicked: root.close()

                    FocusMark {
                        pill: "object"
                        shown: !root.confirming
                    }
                }

                Button {
                    icon: root.icon
                    text: root.verb
                    alarm: true
                    paint: Appearance.colour.alarmFill

                    onClicked: root.answer(root.verb.toLowerCase())

                    FocusMark {
                        pill: "object"
                        shown: root.confirming
                    }
                }
            }
        }
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Escape:
                root.close();
                break;
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                root.press();
                break;
            case Qt.Key_Left:
            case Qt.Key_Right:
            case Qt.Key_Tab:
            case Qt.Key_Backtab:
                root.confirming = !root.confirming;
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }
}
