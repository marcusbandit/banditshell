import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property string phase: Obs.phase
    readonly property string said: {
        switch (root.phase) {
        case "idle":
            return "comes up with streamer mode";
        case "unset":
            return "obs websocket is off in obs";
        case "ready":
            return Obs.scene ? `obs · scene ${Obs.scene.toLowerCase()}` : "obs · connected";
        case "refused":
            return "obs said no to the password";
        }
        return "not connected";
    }

    width: parent ? parent.width : 0

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "radio_button_checked"
        label: "OBS"
        detail: root.said
        detailColour: root.phase === "refused" ? Appearance.colour.alarm : Appearance.colour.textFaint
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            style: root.phase === "ready" ? "tonal" : "filled"
            text: root.phase === "ready" ? "Let go" : root.phase === "refused" ? "Again" : "Connect"
            onClicked: {
                if (root.phase === "ready")
                    return Obs.forget();
                if (root.phase === "idle")
                    return SettingsState.set("stream", true);
                if (root.phase === "unset")
                    return Obs.launch();
                Obs.sync();
            }
        }
    }

    MenuLayer {
        width: root.width
        open: true

        SettingsRowFrame {
            width: parent.width
            interactive: false
            icon: "dns"
            label: "Address"
            onPointed: SettingsView.hovered = root.row

            SettingsField {
                anchors.verticalCenter: parent.verticalCenter
                text: `localhost:${Obs.server?.server_port ?? 4455}`
                onCommitted: SettingsView.drop("obs keeps its address in its own settings", "info")
            }
        }

        SettingsRowFrame {
            width: parent.width
            interactive: false
            icon: "key"
            label: "Password"
            onPointed: SettingsView.hovered = root.row

            SettingsSecret {
                anchors.verticalCenter: parent.verticalCenter
                text: Obs.server?.server_password ?? ""
                alarm: root.phase === "refused"
            }
        }
    }
}
