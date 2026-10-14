import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

SettingsRowFrame {
    id: root

    property var row: ({})

    readonly property string phase: Update.checking ? "checking" : Update.state

    readonly property var look: {
        switch (root.phase) {
        case "checking":
            return ["sync", "Looking", `on ${Update.branch}`, "Look now", false, "", ""];
        case Update.available:
            return ["system_update_alt", `${Update.behind} new on ${Update.branch}`, Update.remoteHead ? `up to ${Update.remoteHead.slice(0, 7)}` : "ready to get", "Get it", true, "filled", Appearance.colour.updateAvailable];
        case Update.downloading:
            return ["cloud_download", "Getting it", "a moment", "Get it", false, "", Appearance.colour.updateAvailable];
        case Update.downloaded:
            return ["download_done", "It is here", "windows stay open", "Restart", true, "filled", Appearance.colour.updateReady];
        case Update.failed:
            return ["sync_problem", "Could not look", Update.error || "the remote did not answer", "Again", true, "", Appearance.colour.updateFailed];
        }
        return ["sync", "Up to date", `${SettingsState.version} · looked at ${TimeFormat.time(Update.checkedAt, false)}`, "Look now", true, "", ""];
    }

    width: parent ? parent.width : 0
    interactive: false
    icon: root.look[0]
    iconFill: 1
    iconColour: root.look[6] || Appearance.colour.textDim
    label: root.look[1]
    detail: root.look[2]
    onPointed: SettingsView.hovered = root.row

    Button {
        anchors.verticalCenter: parent.verticalCenter
        size: 0
        style: root.look[5] || "tonal"
        text: root.look[3]
        interactive: root.look[4]
        onClicked: {
            if (root.phase === Update.available)
                Update.download();
            else if (root.phase === Update.downloaded)
                Update.restart();
            else
                Update.check();
        }
    }
}
