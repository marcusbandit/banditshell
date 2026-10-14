pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var list: SettingsState.kbLayouts
    readonly property var pool: [["danish", "dk"], ["english (us)", "us"], ["english (uk)", "gb"], ["german", "de"], ["norwegian", "no"], ["swedish", "se"], ["french", "fr"], ["colemak", "us(colemak)"]]

    width: parent ? parent.width : 0

    function save(next: var): void {
        SettingsState.plan("layouts", next);
    }

    Repeater {
        model: root.list

        delegate: SettingsRowFrame {
            id: lay

            required property var modelData
            required property int index

            width: root.width
            interactive: false
            label: lay.modelData.name
            detail: lay.index ? "super + space" : "leads"
            onPointed: SettingsView.hovered = root.row
            lead: Component {
                KeyCaps {
                    combo: lay.modelData.code
                }
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: lay.index > 0
                icon: "vertical_align_top"
                tip: "lead with it"
                onClicked: {
                    const next = root.list.slice();
                    const first = next[0];
                    next[0] = next[lay.index];
                    next[lay.index] = first;
                    root.save(next);
                    SettingsView.drop(`${next[0].name} leads now`, "keyboard");
                }
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                tip: "drop it"
                enabled: root.list.length > 1
                onClicked: {
                    const next = root.list.slice();
                    const gone = next.splice(lay.index, 1)[0];
                    const at = lay.index;
                    root.save(next);
                    SettingsView.drop(`dropped ${gone.name}`, "keyboard", {
                        label: "undo",
                        run: () => {
                            const back = root.list.slice();
                            back.splice(at, 0, gone);
                            root.save(back);
                        }
                    });
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "add"
        label: "Add a layout"
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: "Add"
            onClicked: {
                const next = root.pool.find(p => !root.list.some(l => l.code === p[1]));
                if (next)
                    root.save(root.list.concat([{
                            name: next[0],
                            code: next[1]
                        }]));
            }
        }
    }
}
