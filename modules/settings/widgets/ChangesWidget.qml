pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var items: {
        const out = [];
        for (const e of WhatsNew.entries) {
            for (const c of e.changes ?? []) {
                const whole = String(c.text ?? "");
                const cut = /[.!?:]\s/.exec(whole);
                const first = (cut ? whole.slice(0, cut.index) : whole).replace(/[.!?]$/, "");
                out.push({
                    icon: c.type === "bugs" ? "build" : c.severity === "major" ? "new_releases" : "auto_awesome",
                    text: first,
                    date: e.date
                });
                if (out.length >= 4)
                    return out;
            }
        }
        return out;
    }

    width: parent ? parent.width : 0

    Repeater {
        model: root.items

        delegate: SettingsRowFrame {
            required property var modelData

            width: root.width
            interactive: false
            icon: modelData.icon
            label: modelData.text
            detail: modelData.date
            onPointed: SettingsView.hovered = root.row
        }
    }
}
