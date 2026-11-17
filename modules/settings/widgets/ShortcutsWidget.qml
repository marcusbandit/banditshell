pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../../../services/chords.js" as Chords

Column {
    id: root

    property var row: ({})

    readonly property bool aliases: root.row.list === "aliases"
    readonly property var map: root.aliases ? Config.values.launcher.aliases : Config.values.launcher.hotkeys
    property int shown: 0

    readonly property var everyName: Object.keys(root.map)
    readonly property var names: root.everyName.filter(n => root.shown === 0 || (root.shown === 1) === !root.map[n].off)
    readonly property int disabledCount: root.everyName.filter(n => root.map[n].off).length

    width: parent ? parent.width : 0

    function textOf(name: string): string {
        const item = root.map[name];
        return root.aliases ? `${name} · ${(item.label || item.id).toLowerCase()}` : `${Chords.chordText(item.chord).toLowerCase()} · ${(item.label || name).toLowerCase()}`;
    }

    function toggle(name: string): void {
        const next = Object.assign({}, root.map);
        next[name] = Object.assign({}, root.map[name], {
            off: !root.map[name].off
        });
        Config.set(root.aliases ? "launcher.aliases" : "launcher.hotkeys", next);
    }

    function drop(name: string): void {
        const item = root.map[name];
        const next = Object.assign({}, root.map);
        delete next[name];
        Config.set(root.aliases ? "launcher.aliases" : "launcher.hotkeys", next);
        SettingsView.drop(root.aliases ? `${name} is no longer an alias` : `${Chords.chordText(item.chord).toLowerCase()} is free again`, root.aliases ? "label" : "keyboard", {
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
        detail: root.everyName.length ? (root.disabledCount ? `${root.everyName.length} set, ${root.disabledCount} off` : `${root.everyName.length} set`) : "none yet"
        onPointed: SettingsView.hovered = root.row

        Segments {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.everyName.length > 0
            width: 200
            height: implicitHeight
            options: ["All", "On", "Off"]
            current: root.shown
            onPicked: i => root.shown = i
        }
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
                toggles: true
                dimmed: !!root.map[modelData]?.off
                onClicked: root.toggle(modelData)
                onRemoved: root.drop(modelData)
            }
        }
    }
}
