import QtQuick
import qs.config
import qs.components
import qs.modules.settings

SettingsRowFrame {
    id: root

    property var row: ({})

    readonly property bool started: SettingsState.managerStarting === "started"
    readonly property bool failed: SettingsState.managerStarting === "failed"

    width: parent ? parent.width : 0
    interactive: false
    notice: !root.started && !root.failed
    icon: root.started ? "check_circle" : root.failed ? "warning" : "info"
    iconFill: root.started || root.failed ? 1 : 0
    iconColour: root.failed ? Appearance.colour.warning : Appearance.colour.text
    label: root.started ? "Started" : root.failed ? "Did not start" : SettingsState.networkMissing
    detail: root.started ? "Restart the shell to use NetworkManager. Your open windows stay open." : root.failed ? `NetworkManager could not start: ${SettingsState.managerStartTrouble}. Its log may say why.` : ""
    detailColour: root.failed ? Appearance.colour.warning : Appearance.colour.textDim
    detailLines: 4
    onPointed: SettingsView.hovered = root.row
    Component.onCompleted: SettingsState.recheckManager()

    Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.started
        size: 0
        style: "accent"
        text: "Restart"
        onClicked: SettingsState.restartShell()
    }

    Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.failed
        size: 0
        text: "Open the log"
        onClicked: SettingsState.openManagerLog()
    }
}
