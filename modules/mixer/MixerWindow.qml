pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

FloatingWindow {
    id: win

    readonly property string windowTitle: "banditshell-mixer"
    readonly property int wide: Math.round(Appearance.sizes.launcherWidth * 1.15)
    readonly property int tall: Math.round(Appearance.sizes.launcherWidth * 0.85)

    title: win.windowTitle
    color: Appearance.colour.surfaceSolid

    implicitWidth: win.wide
    implicitHeight: win.tall

    visible: Mixer.windowOpen

    onVisibleChanged: {
        if (!win.visible && Mixer.windowOpen)
            Mixer.hide();
        if (win.visible)
            body.forceActiveFocus();
    }

    readonly property var rules: [
        {
            lua: "float = true",
            legacy: "float on"
        },
        {
            lua: `size = { ${win.wide}, ${win.tall} }`,
            legacy: `size ${win.wide} ${win.tall}`
        },
        {
            lua: "center = true",
            legacy: "center on"
        }
    ]

    function installRules(): void {
        Hypr.windowRule(win.windowTitle, win.rules);
    }

    Component.onCompleted: win.installRules()

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            win.installRules();
        }

        function onParserKnownChanged(): void {
            win.installRules();
        }
    }

    Item {
        id: body

        anchors.fill: parent
        focus: true

        Keys.onPressed: event => {
            if (sheet.open) {
                sheet.key(event);
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_Escape) {
                Mixer.hide();
                event.accepted = true;
                return;
            }
            event.accepted = view.claimKey(event);
        }

        MixerView {
            id: view

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            live: win.visible
            showsSelection: false

            onAsks: (item, actions, x, y) => {
                const at = item.mapToItem(sheet, x, y);
                sheet.popup(at.x, at.y, actions);
            }
        }

        ActionSheet {
            id: sheet

            anchors.fill: parent
            z: 10

            onClosed: body.forceActiveFocus()
        }
    }
}
