import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property string machine: [Device.vendor, Device.product].filter(Boolean).join(" ") || Device.hostname || "this machine"
    readonly property string summary: [root.machine, Device.cpu, Device.memoryTotalGb ? `${Math.round(Device.memoryTotalGb)} GB` : "", Device.os, Device.kernel, Device.compositorVersion ? `Hyprland ${Device.compositorVersion}` : ""].filter(Boolean).join(", ")

    width: parent ? parent.width : 0

    Component.onCompleted: Device.watch(true)
    Component.onDestruction: Device.watch(false)

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "deployed_code"
        label: `BanditShell ${SettingsState.version}`
        detail: [Device.quickshellVersion ? `quickshell ${Device.quickshellVersion}` : "", Device.compositorVersion ? `hyprland ${Device.compositorVersion}` : ""].filter(Boolean).join(" · ")
        onPointed: SettingsView.hovered = root.row

        SettingsTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "description"
            tip: "design notes"
            onClicked: Quickshell.execDetached(["xdg-open", `${Device.shellDir}/DESIGN.md`])
        }

        SettingsTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "code"
            tip: "source"
            onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/marcusbandit/banditshell"])
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "laptop"
        label: "This machine"
        detail: [Device.os, Device.kernel].filter(Boolean).join(" · ").toLowerCase()
        onPointed: SettingsView.hovered = root.row

        SettingsTool {
            anchors.verticalCenter: parent.verticalCenter
            icon: "content_copy"
            tip: "copy the details"
            onClicked: {
                Quickshell.execDetached(["wl-copy", root.summary]);
                SettingsView.drop("device details copied", "content_copy");
            }
        }
    }
}
