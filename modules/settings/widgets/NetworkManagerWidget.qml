import QtQuick
import qs.components
import qs.services
import qs.modules.settings

SettingsRowFrame {
    id: root

    property var row: ({})

    readonly property string stage: SettingsState.managerStage
    readonly property bool failed: SettingsState.managerStarting === "failed"

    width: parent ? parent.width : 0
    interactive: false
    notice: true
    icon: "info"
    label: root.stage === "restart" ? "NetworkManager is running" : `NetworkManager is not ${SettingsState.managerInstalled ? "running" : "installed"}`
    detail: {
        if (root.stage === "restart")
            return "Restart the shell to use it.";
        if (root.failed)
            return `Could not start it: ${SettingsState.managerStartTrouble}.`;
        if (root.stage === "start")
            return "Start turns it on now and at every login.";
        if (root.stage === "install")
            return `Install it in a terminal: ${SettingsState.managerInstall}`;
        return SettingsState.managerInstalled ? "Start it the way your system starts services, then restart the shell." : "Install it from your system's packages, then start it.";
    }
    detailLines: 3
    onPointed: SettingsView.hovered = root.row

    Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.stage === "start"
        size: 0
        style: "accent"
        interactive: SettingsState.managerStarting !== "starting"
        text: SettingsState.managerStarting === "starting" ? "Starting…" : "Start"
        onClicked: SettingsState.startManager()
    }

    Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.stage === "restart"
        size: 0
        style: "accent"
        text: "Restart"
        onClicked: SettingsState.restartShell()
    }

    Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.stage === "install"
        size: 0
        text: "Copy"
        onClicked: {
            System.copyText(SettingsState.managerInstall);
            SettingsView.drop("command copied", "content_copy");
        }
    }
}
