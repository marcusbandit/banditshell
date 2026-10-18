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
            return ["system_update_alt", `${Update.behind} new on ${Update.branch}`, Update.summaryText || (Update.remoteHead ? `up to ${Update.remoteHead.slice(0, 7)}` : "ready to get"), Update.buttonText, true, "accent", Appearance.colour.updateAvailable];
        case Update.downloading:
        case Update.verifying:
        case Update.restarting:
            return ["cloud_download", Update.phaseText || "Getting it", "a moment", "Working", false, "", Appearance.colour.updateAvailable];
        case Update.updated:
            return ["download_done", "Updated", Update.resultText, "Look now", true, "", Appearance.colour.updateReady];
        case Update.rolledback:
            return ["sync_problem", "Went back", Update.resultText, "Look now", true, "", Appearance.colour.updateFailed];
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
        style: root.look[5] || "plate"
        text: root.look[3]
        interactive: root.look[4]
        onClicked: {
            if (root.phase === Update.available)
                Update.apply();
            else
                Update.check();
        }
    }
}
