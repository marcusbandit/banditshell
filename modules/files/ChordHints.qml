pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string held: ""

    onHeldChanged: settle.elapsed = false

    readonly property var shown: {
        if (root.held === "")
            return [];
        const prefix = `${root.held}+`;
        const out = [];
        for (const chord in Files.chords)
            if (chord.startsWith(prefix))
                out.push({chord: chord, action: Files.chords[chord]});
        return out;
    }

    readonly property var labels: ({
            "terminal": "terminal",
            "preview": "preview panel",
            "hidden": "hidden files",
            "back": "back",
            "forward": "forward",
            "parent": "parent folder",
            "home": "home",
            "focus:grid": "focus files",
            "focus:preview": "focus preview",
            "focus:terminal": "focus terminal"
        })

    visible: opacity > 0
    opacity: root.held !== "" && settle.elapsed ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutQuad
        }
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.huge

        implicitWidth: list.implicitWidth + Appearance.padding.large * 2
        implicitHeight: list.implicitHeight + Appearance.padding.normal * 2

        G2Rect {
            anchors.fill: parent

            radius: Appearance.rounding.large
            color: Appearance.colour.surface
            stroke: Appearance.colour.separator
            strokeWidth: Appearance.font.stem
        }

        Grid {
            id: list

            anchors.centerIn: parent

            readonly property int perColumn: 5

            columns: Math.max(1, Math.ceil(root.shown.length / list.perColumn))
            rows: Math.ceil(root.shown.length / list.columns)
            flow: Grid.TopToBottom

            columnSpacing: Appearance.padding.huge
            rowSpacing: Appearance.padding.small

            Repeater {
                model: root.shown

                delegate: Row {
                    id: hint

                    required property var modelData

                    spacing: Appearance.padding.normal

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter

                        text: hint.modelData.chord.split("+").pop()
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter

                        text: root.labels[hint.modelData.action] ?? hint.modelData.action
                        color: Appearance.colour.textDim
                    }
                }
            }
        }
    }

    Timer {
        id: settle

        property bool elapsed: false

        interval: Appearance.anim.settle
        running: root.held !== ""

        onTriggered: settle.elapsed = true
    }
}
