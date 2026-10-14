pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var list: SettingsState.changes.slice(0, 8)

    function ago(t: double): string {
        const s = Math.round((SettingsState.tick - t) / 1000);
        if (s < 60)
            return "just now";
        const m = Math.round(s / 60);
        if (m < 60)
            return `${m} min ago`;
        const h = Math.round(m / 60);
        return h < 24 ? `${h} h ago` : `${Math.round(h / 24)} days ago`;
    }

    width: parent ? parent.width : 0

    StyledText {
        x: Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        visible: root.list.length === 0
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.normal
        text: "nothing changed yet. everything you flip shows up here with a way back."
        color: Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.list

        delegate: SettingsRowFrame {
            id: change

            required property var modelData
            required property int index

            width: root.width
            interactive: false
            icon: "history"
            label: change.modelData.label
            detail: `${change.modelData.from} → ${change.modelData.to} · ${root.ago(change.modelData.t)}`
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "arrow_forward"
                tip: "go there"
                onClicked: SettingsView.go(change.modelData.page)
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "undo"
                tip: "put it back"
                onClicked: {
                    const c = SettingsState.undo(change.index);
                    if (c)
                        SettingsView.drop(`${c.label.toLowerCase()} back to ${c.from}`, "undo");
                }
            }
        }
    }
}
