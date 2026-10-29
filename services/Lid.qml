pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "lid.js" as Logic

Singleton {
    id: root

    property bool sensed: false
    property bool closed: false
    property bool known: false

    property int monitorDelay: root.quickestRestart
    property int inhibitorDelay: root.quickestRestart

    readonly property int quickestRestart: 1000
    readonly property int slowestRestart: 60000

    readonly property bool present: Logic.hasLid(root.sensed, Monitors.outputs)

    readonly property bool takesOver: Config.ready && root.present && SessionControl.logind && Logic.differsFromLogind(root.actions)

    readonly property var actions: ({
            onBattery: Config.values.power.lid.onBattery,
            pluggedIn: Config.values.power.lid.pluggedIn,
            docked: Config.values.power.lid.docked
        })

    function observe(closed: bool): void {
        const was = root.closed;
        root.closed = closed;
        if (root.known && closed && !was)
            root.act();
        root.known = true;
    }

    function act(): void {
        const action = Logic.chooseAction({
            onBattery: Battery.onBattery,
            external: Logic.externalScreens(Monitors.outputs)
        }, root.actions);
        Suspension.perform(action);
    }

    function engage(): void {
        monitor.running = root.takesOver;
        inhibitor.running = root.takesOver;
        if (root.takesOver)
            query.running = true;
    }

    onTakesOverChanged: root.engage()

    Component.onCompleted: root.engage()

    function hear(line: string): void {
        const closed = Logic.closedFrom(line);
        if (closed === null)
            query.running = true;
        else if (closed !== undefined)
            root.observe(closed);
    }

    Process {
        id: detect

        running: true
        command: ["sh", "-c", "ls /proc/acpi/button/lid 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.sensed = text.trim() !== ""
        }
    }

    Process {
        id: query

        command: ["busctl", "--json=short", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "LidClosed"]

        stdout: StdioCollector {
            onStreamFinished: {
                const closed = Logic.closedFromProperty(text);
                if (closed !== undefined)
                    root.observe(closed);
            }
        }
    }

    Process {
        id: monitor

        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]

        stdout: SplitParser {
            onRead: line => root.hear(line)
        }

        onRunningChanged: if (!monitor.running && root.takesOver)
            monitorRestart.restart()
    }

    Timer {
        id: monitorRestart

        interval: root.monitorDelay
        onTriggered: {
            root.monitorDelay = Math.min(root.monitorDelay * 2, root.slowestRestart);
            monitor.running = true;
            query.running = true;
        }
    }

    Timer {
        running: monitor.running
        interval: root.slowestRestart
        onTriggered: root.monitorDelay = root.quickestRestart
    }

    Process {
        id: inhibitor

        command: ["systemd-inhibit", "--what=handle-lid-switch", "--mode=block", "--who=banditshell", "--why=closing the lid is handled by the shell", "cat"]
        stdinEnabled: true

        onRunningChanged: if (!inhibitor.running && root.takesOver)
            inhibitorRestart.restart()
    }

    Timer {
        id: inhibitorRestart

        interval: root.inhibitorDelay
        onTriggered: {
            root.inhibitorDelay = Math.min(root.inhibitorDelay * 2, root.slowestRestart);
            inhibitor.running = true;
        }
    }

    Timer {
        running: inhibitor.running
        interval: root.slowestRestart
        onTriggered: root.inhibitorDelay = root.quickestRestart
    }
}
