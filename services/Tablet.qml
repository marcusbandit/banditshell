pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool hinge: false

    property bool lidClosed: false

    property bool lidKnown: false
    property string lidSource: "default"

    readonly property bool folding: root.hinge && !root.lidClosed

    property bool folded: false

    onFoldingChanged: {
        if (root.folding) {
            settle.restart();
        } else {
            settle.stop();
            root.folded = false;
        }
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: root.folded = root.folding
    }

    property bool known: false

    property string source: "default"

    property bool docked: Config.values.tablet.docked

    function setDocked(value: bool): void {
        root.docked = value;
    }

    function setFolded(value: bool, from: string): void {
        root.known = true;
        root.source = from;
        root.hinge = value;
    }

    function setLidClosed(value: bool, from: string): void {
        root.lidKnown = true;
        root.lidSource = from;
        root.lidClosed = value;
    }

    function apply(verb: string, from: string): string {
        if (verb === "on")
            root.setFolded(true, from);
        else if (verb === "off")
            root.setFolded(false, from);
        else if (verb === "toggle")
            root.setFolded(!root.hinge, from);
        else
            return `not a tablet verb: ${verb}`;

        return root.folding ? "folded" : "flat";
    }

    function applyLid(verb: string, from: string): string {
        if (verb === "closed")
            root.setLidClosed(true, from);
        else if (verb === "open")
            root.setLidClosed(false, from);
        else if (verb === "toggle")
            root.setLidClosed(!root.lidClosed, from);
        else
            return `not a lid verb: ${verb}`;
        return root.lidClosed ? "closed" : "open";
    }

    Component.onCompleted: {
        probe.running = true;
        lidProbe.running = true;
    }

    Process {
        id: probe

        command: ["python3", Quickshell.shellPath("scripts/tablet-state.py")]

        stdout: SplitParser {
            onRead: line => {
                const word = line.trim();
                if (word === "folded" || word === "flat") {

                    root.setFolded(word === "folded", "probe");
                } else if (word === "unknown") {

                    root.source = "default";
                }
            }
        }

        stderr: SplitParser {

            onRead: line => console.warn("Tablet:", line)
        }
    }

    Process {
        id: lidProbe

        command: ["python3", Quickshell.shellPath("scripts/tablet-state.py"), "--lid"]

        stdout: SplitParser {
            onRead: line => {
                const word = line.trim();
                if (word === "closed" || word === "open")
                    root.setLidClosed(word === "closed", "probe");
                else if (word === "unknown")
                    root.lidSource = "default";
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn("Tablet(lid):", line)
        }
    }
}
