pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "ports.js" as Logic

Singleton {
    id: root

    property bool found: false
    property bool probed: false
    property int asked: 0

    function want(port: int): void {
        root.asked = port;
        if (root.probed)
            root.lookup.want(port > 0 && root.found ? String(port) : "");
    }

    function listenersOn(port: int): var {
        return root.lookup.answerFor(String(port));
    }

    function failedOn(port: int): bool {
        return root.lookup.failedOn(String(port));
    }

    function stop(pid: int, force: bool): void {
        if (pid <= 0)
            return;
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)]);
        root.recheck.restart();
    }

    property Timer recheck: Timer {
        interval: 600
        onTriggered: if (root.lookup.wanted)
            root.lookup.again(root.lookup.wanted)
    }

    property Lookup lookup: Lookup {
        delay: 250
        keep: 16
        freshFor: 2000
        retryAfter: 2000
        commandFor: key => ["ss", "-H", "-l", "-t", "-u", "-n", "-p", "sport", "=", `:${key}`]
        read: text => Logic.readListeners(text)
    }

    Process {
        id: prober

        command: ["sh", "-c", "command -v ss >/dev/null && echo ss; true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.found = text.trim() === "ss";
                root.probed = true;
                root.want(root.asked);
            }
        }
    }
}
