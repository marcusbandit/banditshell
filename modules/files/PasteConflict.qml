pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/files-conflicts.js" as Conflicts

Item {
    id: root

    readonly property var question: FilesPaste.question
    readonly property bool up: root.question !== null
    readonly property bool canReplace: !!root.question && !root.question.holds
    readonly property var later: root.question ? Conflicts.clashes(FilesPaste.items, FilesPaste.chosen, FilesPaste.asking) : []
    readonly property string folder: root.question ? Conflicts.folderName(root.question.dir, Files.home) : ""
    readonly property string source: root.question ? Conflicts.folderName(Files.parentOf(root.question.from), Files.home) : ""
    readonly property string newer: root.question ? Conflicts.newer(root.question) : ""
    readonly property string larger: root.question ? Conflicts.larger(root.question) : ""
    readonly property string called: !root.question ? "" : root.question.name.length <= 30 ? root.question.name : root.question.folder ? "folder" : "file"
    readonly property bool picture: !!root.question && !root.question.folder && Conflicts.picture(root.question.name)

    readonly property var choices: root.canReplace ? ["replace", "skip", "both"] : ["skip", "both"]
    property string selected: "both"
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

    onQuestionChanged: {
        root.selected = "both";
        root.all = false;
    }

    function choose(choice: string): void {
        FilesPaste.answer(choice, root.all && root.later.length > 0);
    }

    function step(by: int): void {
        const at = root.choices.indexOf(root.selected);
        root.selected = root.choices[Math.max(0, Math.min(root.choices.length - 1, at + by))];
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
        case Qt.Key_Backtab:
            root.step(-1);
            return;
        case Qt.Key_Right:
        case Qt.Key_Tab:
            root.step(1);
            return;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.choose(root.selected);
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
            if (root.later.length > 0)
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

        implicitWidth: Math.min(root.width - Appearance.padding.huge * 2, 560)
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

            Column {
                id: sides

                width: parent.width
                spacing: Appearance.padding.small

                ConflictSide {
                    width: sides.width

                    label: `Already in ${root.folder}`
                    path: root.question?.to ?? ""
                    name: root.question?.name ?? ""
                    folder: root.question?.folder ?? false
                    picture: root.picture
                    facts: root.question?.there ?? null
                    tags: (root.newer === "there" ? ["Newer"] : []).concat(root.larger === "there" ? ["Larger"] : [])
                }

                ConflictSide {
                    width: sides.width

                    label: `Pasting from ${root.source}`
                    path: root.question?.from ?? ""
                    name: root.question?.name ?? ""
                    folder: root.question?.folder ?? false
                    picture: root.picture
                    facts: root.question?.coming ?? null
                    tags: (root.newer === "coming" ? ["Newer"] : []).concat(root.larger === "coming" ? ["Larger"] : [])
                }
            }

            Repeater {
                model: root.choices

                StyledText {
                    required property string modelData

                    width: body.width

                    text: !root.question ? "" : modelData === "replace" ? `Replace moves the ${root.called} already in ${root.folder} to the trash` : modelData === "skip" ? `Skip leaves the ${root.called} in ${root.folder} as it is` : `Keep both saves the new one as ${Conflicts.keptName(root.question)}`
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                }
            }

            StyledText {
                width: parent.width
                visible: !root.canReplace

                text: root.question ? `The ${root.called} in ${root.folder} holds what you are pasting, so it cannot be replaced` : ""
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            Item {
                width: parent.width
                height: Math.max(allToggle.height, allLabel.implicitHeight)
                visible: root.later.length > 0

                Toggle {
                    id: allToggle

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.all

                    onToggled: root.all = !root.all
                }

                StyledText {
                    id: allLabel

                    anchors.left: allToggle.right
                    anchors.right: parent.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    text: `Do the same for ${Conflicts.clashLabel(root.later)}`
                    font.pixelSize: Appearance.font.size.small
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere

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

                    text: "Stop pasting"
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

                            readonly property bool chosen: modelData === root.selected
                            readonly property bool destructive: modelData === "replace"

                            text: modelData === "skip" ? "Skip" : modelData === "both" ? "Keep both" : "Replace"
                            style: destructive ? "ring" : chosen ? "accent" : "plate"
                            alarm: destructive
                            paint: destructive && chosen ? Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.alarm, 0.22) : undefined

                            onClicked: root.choose(modelData)
                        }
                    }
                }
            }

            KeyHints {
                width: parent.width

                keys: [["Enter", root.selected === "replace" ? "replace" : root.selected === "skip" ? "skip" : "keep both"], ["S", "skip"]].concat(root.canReplace ? [["R", "replace"]] : []).concat(root.later.length > 0 ? [["A", "all"]] : []).concat([["Esc", "stop pasting, nothing is pasted yet"]])
            }
        }
    }
}
