import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import qs.modules.settings

Column {
    id: root

    readonly property string ssid: SettingsView.pin?.id ?? ""
    readonly property var n: Network.networks.find(x => x.name === root.ssid) ?? null
    readonly property bool on: !!root.n?.connected
    readonly property bool secured: !!root.n && Network.secured(root.n)
    readonly property bool saved: !!root.n?.known
    readonly property bool busy: Network.connectingName === root.ssid
    readonly property int sig: root.n ? Network.bars(root.n) : 0
    readonly property string failed: Network.failedName === root.ssid ? Network.failureLabel() : ""
    property string password: ""
    property string error: ""

    spacing: Appearance.padding.card

    onOnChanged: Network.share(root.on && root.secured)
    Component.onCompleted: Network.share(root.on && root.secured)
    Component.onDestruction: Network.share(false)

    function join(): void {
        if (!root.n)
            return;
        if (root.secured && !root.saved) {
            if (root.password.length < 8) {
                root.error = root.password ? "wi-fi passwords are 8 or more" : `needs the password for ${root.ssid}`;
                return;
            }
            root.error = "";
            Network.clearFailure(root.ssid);
            root.n.connectWithPsk(root.password);
            return;
        }
        root.error = "";
        root.n.connect();
    }

    Item {
        width: parent.width
        height: 160

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.fill
        }

        Column {
            anchors.centerIn: parent
            spacing: Appearance.padding.normal

            SettingsBars {
                anchors.horizontalCenter: parent.horizontalCenter
                lit: root.sig
                barWidth: 12
                step: 14
                round: 4
                spacing: 8
                colour: Appearance.colour.text
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${["", "weak", "fair", "good", "strong"][Math.max(0, Math.min(4, root.sig))]}${root.secured ? " · locked" : " · open"}`
                color: Appearance.colour.textDim
            }
        }
    }

    SettingsFacts {
        width: parent.width
        visible: root.on
        facts: [["signal", `${root.n ? Network.percent(root.n) : 0}%`], ["security", root.n ? Network.securityLabel(root.n) : ""], ["reach", SettingsState.reach]]
    }

    Item {
        width: parent.width
        height: code.height + note.height + Appearance.padding.card * 2 + Appearance.padding.small
        visible: root.on && root.secured && Network.card !== ""

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.fill
        }

        QrCode {
            id: code

            anchors.horizontalCenter: parent.horizontalCenter
            y: Appearance.padding.card
            width: 180
            height: 180
            text: Network.card
            colourful: false
        }

        StyledText {
            id: note

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: code.bottom
            anchors.topMargin: Appearance.padding.small
            text: "point a phone camera here"
            color: Appearance.colour.textFaint
        }
    }

    Column {
        width: parent.width
        spacing: Appearance.padding.small
        visible: !root.on && root.secured && !root.saved

        StyledText {
            text: "password"
        }

        SettingsSecret {
            boxWidth: parent.width - 38
            text: root.password
            alarm: root.error !== "" || root.failed !== ""
            onEdited: t => root.password = t
            onAccepted: root.join()
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: root.error || root.failed
            color: Appearance.colour.alarm
            wrapMode: Text.WordWrap
        }
    }

    Flow {
        width: parent.width
        spacing: Appearance.padding.small

        Button {
            visible: root.on && Network.captive
            size: 0
            style: "filled"
            text: "Sign in"
            onClicked: Network.openPortal()
        }

        Button {
            visible: root.on
            size: 0
            text: "Leave"
            onClicked: {
                root.n?.disconnect();
                SettingsView.drop(`left ${root.ssid}`, "wifi_off");
            }
        }

        Button {
            visible: !root.on
            size: 0
            style: "filled"
            text: root.busy ? "Joining" : "Join"
            interactive: !root.busy
            onClicked: root.join()
        }

        Button {
            visible: root.saved
            size: 0
            style: "outlined"
            alarm: true
            text: "Forget"
            onClicked: {
                Network.forget(root.n);
                SettingsView.unpin();
                SettingsView.drop(`forgot ${root.ssid}`, "delete");
            }
        }
    }
}
