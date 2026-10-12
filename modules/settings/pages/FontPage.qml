pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.modules.settings

Item {
    id: root

    implicitHeight: list.implicitHeight

    property var families: []

    Process {
        id: lister

        command: ["fc-list", ":", "family"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const out = [];
                for (const line of text.split("\n")) {
                    const name = line.split(",")[0].trim();
                    if (!name || seen[name])
                        continue;
                    seen[name] = true;
                    out.push(name);
                }
                out.sort((a, b) => a.toLowerCase().localeCompare(b.toLowerCase()));
                root.families = out;
            }
        }
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            title: "Current"

            SettingsRow {
                label: Appearance.font.family
                interactive: false
            }
        }

        SettingsCard {
            title: `Families, ${root.families.length} installed`

            Repeater {
                model: root.families

                delegate: SettingsRow {
                    id: row

                    required property string modelData

                    label: row.modelData
                    selected: Config.values.font.family === row.modelData
                    onActivated: Config.set("font.family", row.modelData)

                    StyledText {
                        text: "Aa Bb 0123"
                        font.family: row.modelData
                        color: Appearance.colour.textDim
                    }
                }
            }
        }
    }
}
