pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var list: SettingsState.planned.startup ?? []
    property bool adding: false

    width: parent ? parent.width : 0

    function save(next: var): void {
        SettingsState.plan("startup", next);
    }

    Repeater {
        model: root.list

        delegate: SettingsRowFrame {
            id: app

            required property var modelData
            required property int index

            width: root.width
            interactive: false
            label: app.modelData.name
            onPointed: SettingsView.hovered = root.row
            lead: Component {
                AppMark {
                    spec: AppIcons.markFor(app.modelData.id, "colour")
                    color: Appearance.colour.textDim
                }
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: !!app.modelData.on
                onToggled: {
                    const next = root.list.slice();
                    next[app.index] = Object.assign({}, app.modelData, {
                        on: !app.modelData.on
                    });
                    root.save(next);
                }
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                tip: "take it off"
                onClicked: {
                    const gone = app.modelData;
                    const at = app.index;
                    const next = root.list.slice();
                    next.splice(at, 1);
                    root.save(next);
                    SettingsView.drop(`${gone.name.toLowerCase()} stays shut at startup`, "remove_circle", {
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
        label: "Add an app"
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: "Add"
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

            exclude: root.list.map(a => a.id)
            onPicked: entry => {
                root.save(root.list.concat([{
                        id: entry.id,
                        name: entry.name,
                        on: true
                    }]));
                root.adding = false;
            }
        }
    }
}
