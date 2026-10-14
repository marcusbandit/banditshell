pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "suspension.js" as Logic

Singleton {
    id: root

    property bool hibernatePossible: false

    function perform(action: string): void {
        const chosen = Logic.resolve(action, root.hibernatePossible);
        if (chosen === "lock") {
            Lock.lock();
            return;
        }
        const command = Logic.commandFor(chosen);
        if (command.length === 0)
            return;
        sleeper.command = command;
        sleeper.running = true;
    }

    Process {
        id: sleeper
    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", "cat /sys/power/state 2>/dev/null; echo ---; cat /proc/swaps 2>/dev/null; echo ---; busctl --json=short call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.hibernatePossible = Logic.parseHibernate(text)
        }
    }

    Timer {
        interval: 10 * 60 * 1000
        running: true
        repeat: true
        onTriggered: probe.running = true
    }
}
