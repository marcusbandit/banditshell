pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    width: parent ? parent.width : 0

    Repeater {
        model: Apps.folderKeys

        delegate: SettingsRowFrame {
            id: folder

            required property string modelData

            readonly property var apps: Apps.folderApps(folder.modelData)

            width: root.width
            interactive: false
            icon: "folder"
            label: Apps.folders[folder.modelData]?.name ?? folder.modelData
            detail: folder.apps.length ? folder.apps.map(e => (e.name ?? "").toLowerCase()).join(" · ") : "empty"
            onPointed: SettingsView.hovered = root.row

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "folder_off"
                tip: "undo the folder"
                onClicked: {
                    const name = folder.label;
                    Apps.dissolveFolder(folder.modelData);
                    SettingsView.drop(`${name} is gone · its apps are loose again`, "folder_off");
                }
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "create_new_folder"
        label: "New folder"
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: "Make"
            onClicked: {
                Apps.createFolder("new folder");
                SettingsView.drop("folder made · drag apps onto it in the launcher", "create_new_folder");
            }
        }
    }
}
