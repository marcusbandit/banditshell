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
        case "missing":
            return "reaching obs needs qt6-websockets";
        case "unset":
            return Obs.installed ? "obs websocket is off in obs" : "obs is not installed here";
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
            visible: root.phase !== "missing"
            size: 0
            style: root.phase === "ready" ? "plate" : "accent"
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
            detail: Obs.endpoint.addressHere ? "set here · clear it to follow obs" : "from obs"
            onPointed: SettingsView.hovered = root.row

            SettingsField {
                id: address

                anchors.verticalCenter: parent.verticalCenter
                text: Obs.endpoint.label
                placeholder: "localhost:4455"
                onCommitted: t => {
                    if (Obs.setAddress(t))
                        return;
                    address.clear();
                    SettingsView.drop("that is not an address · try host:port", "error");
                }
            }
        }

        SettingsRowFrame {
            width: parent.width
            interactive: false
            icon: "key"
            label: "Password"
            detail: Obs.endpoint.passwordHere ? "set here · clear it to follow obs" : "from obs"
            onPointed: SettingsView.hovered = root.row

            SettingsSecret {
                id: password

                property var draft: null

                function commit(): void {
                    if (password.draft === null)
                        return;
                    Obs.setPassword(password.draft);
                    password.draft = null;
                }

                anchors.verticalCenter: parent.verticalCenter
                text: Obs.password
                alarm: root.phase === "refused"
                onEdited: t => password.draft = t
                onAccepted: password.commit()
                onEditingChanged: if (!editing)
                    password.commit()
            }
        }
    }
}
