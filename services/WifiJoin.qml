pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    property string pending: ""
    property string screenName: ""

    function join(name: string, screenName: string): void {
        const n = Network.find(name);
        if (!n || n.connected)
            return;
        Network.clearFailure(name);
        Network.clearEnroll(name);
        root.screenName = screenName;
        if (Network.enterprise(n) && !n.known) {
            Panels.open("settings", {
                screen: screenName,
                page: "wifi"
            });
            return;
        }
        if (n.known || !Network.secured(n)) {
            root.pending = name;
            n.connect();
            return;
        }
        root.askFor(name, "");
    }

    function askFor(name: string, warning: string): void {
        const n = Network.find(name);
        if (!n)
            return;
        root.pending = "";
        PasswordRequest.ask({
            title: `Join ${name}`,
            message: `${Network.securityLabel(n).toUpperCase()} network`,
            placeholder: "Wi-Fi password",
            continueLabel: "join",
            warning: warning,
            screenName: root.screenName,
            take: secret => {
                const target = Network.find(name);
                if (!target || !secret)
                    return;
                Network.clearFailure(name);
                root.pending = name;
                target.connectWithPsk(secret);
            }
        });
    }

    Connections {
        target: Network

        function onFailedNameChanged(): void {
            Qt.callLater(root.checkFailure);
        }

        function onActiveNameChanged(): void {
            if (root.pending && Network.activeName === root.pending)
                root.pending = "";
        }
    }

    function checkFailure(): void {
        if (!root.pending || Network.failedName !== root.pending)
            return;
        const name = root.pending;
        root.pending = "";
        const n = Network.find(name);
        if (Network.failedReason === ConnectionFailReason.NoSecrets && n && Network.secured(n) && !Network.enterprise(n))
            root.askFor(name, "That password did not work");
    }
}
