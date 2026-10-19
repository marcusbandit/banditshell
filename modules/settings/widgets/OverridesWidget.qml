pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var patterns: Object.keys(Config.values.apps.icons ?? {})
    property bool adding: false
    property var chosen: null

    width: parent ? parent.width : 0

    function label(pattern: string): string {
        return pattern.replace(/^\^|\$$/g, "").replace(/\\\./g, ".").toLowerCase();
    }

    function write(next: var): void {
        Config.set("apps.icons", next);
    }

    Repeater {
        model: root.patterns

        delegate: SettingsRowFrame {
            id: ovr

            required property string modelData

            readonly property string value: Config.values.apps.icons[ovr.modelData]

            width: root.width
            interactive: false
            icon: ovr.value.indexOf("/") < 0 ? ovr.value : "image"
            label: root.label(ovr.modelData)
            detail: ovr.value.startsWith(`${System.home}/`) ? `~${ovr.value.slice(System.home.length)}` : ovr.value
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "restart_alt"
                tip: "its own icon"
                onClicked: {
                    const next = Object.assign({}, Config.values.apps.icons);
                    delete next[ovr.modelData];
                    root.write(next);
                    SettingsView.drop(`${ovr.label} wears its own icon again`, "restart_alt");
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "image"
        label: "Another icon"
        detail: root.chosen ? `for ${root.chosen.name.toLowerCase()}` : "for any app"
        onPointed: SettingsView.hovered = root.row

        SettingsField {
            anchors.verticalCenter: parent.verticalCenter
            visible: !!root.chosen
            placeholder: "symbol or file"
            onCommitted: t => {
                if (!t.trim() || !root.chosen)
                    return;
                const next = Object.assign({}, Config.values.apps.icons);
                next[`^${root.chosen.id.replace(/\./g, "\\.")}$`] = t.trim();
                root.write(next);
                root.chosen = null;
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.chosen
            size: 0
            text: "Pick"
            onClicked: {
                root.adding = !root.adding;
                if (root.adding)
                    Qt.callLater(picker.take);
            }
        }
    }

    MenuLayer {
        width: root.width
        open: root.adding

        AppPicker {
            id: picker

            onPicked: entry => {
                root.chosen = entry;
                root.adding = false;
            }
        }
    }
}
