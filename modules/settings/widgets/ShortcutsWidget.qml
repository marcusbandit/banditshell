pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../launcher/search.js" as Search

Column {
    id: root

    property var row: ({})

    readonly property bool aliases: root.row.list === "aliases"
    readonly property var map: root.aliases ? Config.values.launcher.aliases : Config.values.launcher.hotkeys
    readonly property var names: Object.keys(root.map)

    width: parent ? parent.width : 0

    function textOf(name: string): string {
        const item = root.map[name];
        return root.aliases ? `${name} · ${(item.label || item.id).toLowerCase()}` : `${Search.chordText(item.chord).toLowerCase()} · ${(item.label || name).toLowerCase()}`;
    }

    function drop(name: string): void {
        const item = root.map[name];
        const next = Object.assign({}, root.map);
        delete next[name];
        Config.set(root.aliases ? "launcher.aliases" : "launcher.hotkeys", next);
        SettingsView.drop(root.aliases ? `${name} is no longer an alias` : `${Search.chordText(item.chord).toLowerCase()} is free again`, root.aliases ? "label" : "keyboard", {
            label: "undo",
            run: () => {
                const back = Object.assign({}, root.map);
                back[name] = item;
                Config.set(root.aliases ? "launcher.aliases" : "launcher.hotkeys", back);
            }
        });
    }

    SettingsRowFrame {
        width: root.width
        minHeight: 0
        interactive: false
        icon: root.aliases ? "label" : "keyboard"
        label: root.aliases ? "Aliases" : "Hotkeys"
        detail: root.names.length ? `${root.names.length} set` : "none yet"
        onPointed: SettingsView.hovered = root.row
    }

    Flow {
        x: Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        spacing: Appearance.padding.small
        bottomPadding: Appearance.padding.small
        visible: root.names.length > 0

        Repeater {
            model: root.names

            delegate: SettingsChip {
                required property string modelData

                text: root.textOf(modelData)
                tip: "remove"
                onRemoved: root.drop(modelData)
            }
        }
    }
}
