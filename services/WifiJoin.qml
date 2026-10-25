pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import "wifilist.js" as WifiList

Singleton {
    id: root

    property string pending: ""
    property string screenName: ""

    readonly property string wrongPassword: "That password did not work"

    signal failed(string name, string kind, string message)

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
            Network.join(n, "");
            root.pending = name;
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
                Network.join(target, secret);
                root.pending = name;
            }
        });
    }

    function asksAgain(n: var, kind: string): bool {
        return kind === "password" && !!n && Network.secured(n) && !Network.enterprise(n);
    }

    function retry(name: string, kind: string): void {
        const n = Network.find(name);
        if (!n || n.connected)
            return;
        if (root.asksAgain(n, kind))
            root.askFor(name, root.wrongPassword);
        else
            root.join(name, Hypr.focusedScreen || root.screenName);
    }

    Connections {
        target: Network

        function onJoinFailed(name: string, kind: string): void {
            const asked = root.pending === name;
            if (asked)
                root.pending = "";
            if (asked && root.asksAgain(Network.find(name), kind))
                root.askFor(name, root.wrongPassword);
            else
                root.failed(name, kind, WifiList.failureMessage(name, kind));
        }

        function onTryingChanged(): void {
            root.pending = "";
        }
    }
}
