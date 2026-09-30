pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string title: ""
    property var accepted: null

    property bool up: false

    signal dismissed

    function ask(question: string, initial: string, select: int, onAccept: var): void {
        root.title = question;
        root.accepted = onAccept;
        field.text = initial;
        root.up = true;
        root.opacity = 1;

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
        root.opacity = 0;
        root.accepted = null;
        root.dismissed();
    }

    function commit(): void {
        const answer = field.text.trim();
        const run = root.accepted;
        root.close();
        if (answer && run)
            run(answer);
    }

    visible: root.up || root.opacity > 0
    opacity: 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutQuad
        }
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
        strokeWidth: Appearance.font.stem

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

                text: "Enter to confirm  ·  Escape to cancel"
                color: Appearance.colour.textFaint
            }
        }
    }
}
