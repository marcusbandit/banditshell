pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property string current: "buttons"

    readonly property var entries: [
        {
            key: "buttons",
            title: "Buttons",
            icon: "smart_button",
            section: "Buttons",
            status: "draft"
        },
        {
            key: "segmented-buttons",
            title: "Segmented buttons",
            icon: "view_week",
            section: "Buttons",
            status: "draft"
        },
        {
            key: "switch",
            title: "Switch",
            icon: "toggle_on",
            section: "Selection",
            status: "draft"
        },
        {
            key: "sliders",
            title: "Sliders",
            icon: "tune",
            section: "Input",
            status: "draft"
        }
    ]

    readonly property var sections: {
        const out = [];
        for (const e of root.entries) {
            let s = out.find(o => o.name === e.section);
            if (!s) {
                s = {
                    name: e.section,
                    entries: []
                };
                out.push(s);
            }
            s.entries.push(e);
        }
        return out;
    }

    function entryFor(key: string): var {
        return root.entries.find(e => e.key === key) ?? null;
    }

    function pageUrl(key: string): url {
        const name = key.split("-").map(p => p[0].toUpperCase() + p.slice(1)).join("") + "Page.qml";
        return Qt.resolvedUrl(`pages/${name}`);
    }
}
