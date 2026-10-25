pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    readonly property var question: FilesPaste.question
    readonly property bool up: root.question !== null
    readonly property bool canReplace: !!root.question && !root.question.holds
    readonly property int others: Math.max(0, FilesPaste.waiting - 1)
    readonly property string folder: !root.question ? "" : root.question.dir === "/" ? "/" : root.question.dir.slice(root.question.dir.lastIndexOf("/") + 1)

    readonly property var choices: root.canReplace ? ["skip", "both", "replace"] : ["skip", "both"]
    property int selected: 1
    property bool all: false

    signal dismissed

    onUpChanged: {
        if (root.up) {
            Qt.callLater(root.forceActiveFocus);
        } else {
            root.all = false;
            root.dismissed();
        }
    }

    onQuestionChanged: root.selected = 1

    function choose(choice: string): void {
        FilesPaste.answer(choice, root.all && root.others > 0);
    }

    visible: root.up || fade.value > 0
    opacity: fade.value
    focus: root.up

    Keys.onPressed: event => {
        event.accepted = true;
        switch (event.key) {
        case Qt.Key_Escape:
            FilesPaste.cancel();
            return;
        case Qt.Key_Left:
            root.selected = Math.max(0, root.selected - 1);
            return;
        case Qt.Key_Right:
        case Qt.Key_Tab:
            root.selected = Math.min(root.choices.length - 1, root.selected + 1);
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.choose(root.choices[root.selected]);
            return;
        case Qt.Key_S:
            root.choose("skip");
            return;
        case Qt.Key_K:
            root.choose("both");
            return;
        case Qt.Key_R:
            if (root.canReplace)
                root.choose("replace");
            return;
        case Qt.Key_A:
        case Qt.Key_Space:
            if (root.others > 0)
                root.all = !root.all;
            return;
        }
    }

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
            onClicked: FilesPaste.cancel()
        }
    }

    SquircleRect {
        anchors.centerIn: parent

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, 520)
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

            StyledText {
                width: parent.width

                text: root.question ? `${root.question.name} is already in ${root.folder}` : ""
                font.pixelSize: Appearance.font.size.normal
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width

                text: root.canReplace ? "Replace puts the one there in the trash" : "It holds what you are pasting, so it stays"
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                wrapMode: Text.WordWrap
            }

            Item {
                width: parent.width
                height: allToggle.height
                visible: root.others > 0

                Toggle {
                    id: allToggle

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.all

                    onToggled: root.all = !root.all
                }

                StyledText {
                    anchors.left: allToggle.right
                    anchors.right: parent.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    text: root.others === 1 ? "Do the same for the other one" : `Do the same for the other ${root.others}`
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight

                    TapHandler {
                        onTapped: root.all = !root.all
                    }
                }
            }

            Item {
                width: parent.width
                height: buttons.height

                Button {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    text: "Cancel"
                    style: "bare"

                    onClicked: FilesPaste.cancel()
                }

                Row {
                    id: buttons

                    anchors.right: parent.right
                    spacing: Appearance.padding.small

                    Repeater {
                        model: root.choices

                        Button {
                            required property string modelData
                            required property int index

                            text: modelData === "skip" ? "Skip" : modelData === "both" ? "Keep both" : "Replace"
                            style: index === root.selected ? "accent" : "plate"

                            onClicked: root.choose(modelData)
                        }
                    }
                }
            }
        }
    }
}
