pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string name: ""
    property string sentence: ""
    property string verb: ""
    property string icon: ""
    property var accepted: null

    property bool up: false
    property bool confirming: false

    signal dismissed

    function ask(name: string, sentence: string, verb: string, icon: string, onAnswer: var): void {
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

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, 420)
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
