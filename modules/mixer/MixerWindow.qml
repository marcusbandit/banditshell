pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
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
        if (!Compositor.isHyprland || !Hypr.parserKnown)
            return;
        const title = `^(${win.windowTitle})$`;
        if (Hypr.lua) {
            ruler.exec(["hyprctl", "eval", `hl.window_rule({ name = "${win.windowTitle}", match = { title = "${title}" }, ${win.rules.map(r => r.lua).join(", ")} })`]);
            return;
        }
        ruler.exec(["hyprctl", "--batch", win.rules.map(r => `keyword windowrule ${r.legacy}, match:title ${title}`).join(" ; ")]);
    }

    Component.onCompleted: win.installRules()

    Process {
        id: ruler
    }

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
