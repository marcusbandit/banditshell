pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property bool starred: root.row.list === "starred"
    readonly property var ids: Object.keys(root.starred ? Apps.starred : Apps.hidden)
    property bool adding: false

    width: parent ? parent.width : 0

    function nameOf(id: string): string {
        return (Apps.entryById(id)?.name ?? id).toLowerCase();
    }

    function drop(id: string): void {
        const entry = Apps.entryById(id) ?? {
            id
        };
        if (root.starred)
            Apps.setStarred(entry, false);
        else
            Apps.setHidden(entry, false);
        SettingsView.drop(root.starred ? `unstarred ${root.nameOf(id)}` : `${root.nameOf(id)} shows again`, root.starred ? "star" : "visibility", {
            label: "undo",
            run: () => root.starred ? Apps.setStarred(entry, true) : Apps.setHidden(entry, true)
        });
    }

    SettingsRowFrame {
        width: root.width
        minHeight: 0
        interactive: false
        icon: root.starred ? "star" : "visibility_off"
        label: root.starred ? "Starred" : "Hidden"
        detail: root.starred ? "always on top" : "never listed"
        onPointed: SettingsView.hovered = root.row
    }

    Flow {
        x: Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        spacing: Appearance.padding.small
        bottomPadding: Appearance.padding.small

        Repeater {
            model: root.ids

            delegate: SettingsChip {
                required property string modelData

                text: root.nameOf(modelData)
                tip: root.starred ? "unstar" : "show it"
                onRemoved: root.drop(modelData)
            }
        }

        SettingsChip {
            adder: true
            text: "add"
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

            exclude: root.ids
            onPicked: entry => {
                if (root.starred)
                    Apps.setStarred(entry, true);
                else
                    Apps.setHidden(entry, true);
                root.adding = false;
            }
        }
    }
}
