pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string title: ""
    property var accepted: null
    property var check: null
    property string verb: "OK"

    readonly property string refusal: root.up && root.check ? root.check(field.text.trim()) : ""

    property bool up: false

    signal dismissed

    function ask(question: string, initial: string, select: int, onAccept: var, check: var, verb: string): void {
        root.title = question;
        root.accepted = onAccept;
        root.check = check ?? null;
        root.verb = verb || "OK";
        field.text = initial;
        root.up = true;

        Qt.callLater(() => {
            field.forceActiveFocus();

            if (select > 0)
                field.select(0, select);
            else
                field.selectAll();
        });
    }

    function close(): void {
        root.up = false;
        root.accepted = null;
        root.check = null;
        root.dismissed();
    }

    function commit(): void {
        if (root.refusal)
            return;
        const answer = field.text.trim();
        const run = root.accepted;
        root.close();
        if (answer && run)
            run(answer);
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

        Column {
            id: body

            anchors.centerIn: parent
            width: parent.width - Appearance.padding.large * 2
            spacing: Appearance.padding.normal

            StyledText {
                width: parent.width

                text: root.title
                font.pixelSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            SquircleRect {
                width: parent.width
                implicitHeight: field.implicitHeight + Appearance.padding.normal * 2

                radius: Appearance.rounding.small
                color: Appearance.colour.fill
                stroke: root.refusal ? Appearance.colour.alarm : "transparent"
                strokeWidth: Appearance.stroke.ring

                TextInput {
                    id: field

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Appearance.padding.normal
                    clip: true

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText
                    selectByMouse: true
                    renderType: Text.NativeRendering

                    Keys.onReturnPressed: root.commit()
                    Keys.onEnterPressed: root.commit()
                    Keys.onEscapePressed: root.close()
                }
            }

            StyledText {
                width: parent.width
                visible: root.refusal !== ""

                text: root.refusal
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.alarm
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            KeyHints {
                width: parent.width

                keys: root.refusal ? [["Esc", "cancel"]] : [["Enter", root.verb], ["Esc", "cancel"]]
            }
        }
    }
}
