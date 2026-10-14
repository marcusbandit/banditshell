pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var list: SettingsState.v("startup")
    property bool adding: false

    width: parent ? parent.width : 0

    function change(request: var): void {
        SettingsState.set("startup", request);
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
            detail: app.modelData.note
            onPointed: SettingsView.hovered = root.row
            lead: Component {
                AppMark {
                    spec: app.modelData.mark
                    color: Appearance.colour.textDim
                }
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: !!app.modelData.on
                onToggled: root.change({
                    id: app.modelData.id,
                    on: !app.modelData.on
                })
            }

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                visible: app.modelData.removable
                icon: "close"
                tip: "take it off"
                onClicked: {
                    const gone = app.modelData;
                    root.change({
                        id: gone.id,
                        remove: true
                    });
                    SettingsView.drop(`${gone.name.toLowerCase()} stays shut at startup`, "remove_circle", {
                        label: "undo",
                        run: () => root.change({
                            restore: {
                                path: gone.row.path,
                                text: gone.row.text
                            }
                        })
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
        detail: StartupApps.summary
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

            exclude: StartupApps.claimed
            onPicked: entry => {
                root.change({
                    add: {
                        id: entry.id,
                        name: entry.name,
                        exec: entry.execString,
                        icon: entry.icon,
                        terminal: entry.runInTerminal
                    }
                });
                root.adding = false;
            }
        }
    }
}
