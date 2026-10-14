pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import "idle.js" as Plan

Singleton {
    id: root

    property bool handledElsewhere: false

    property bool idle: false

    property double idleSince: 0

    property bool screensOff: false

    readonly property int presenceSeconds: 60

    readonly property int handlerRecheckMs: 60 * 1000

    readonly property var minutes: ({
            lock: Config.values.idle.lock,
            screensOff: Config.values.idle.screensOff,
            sleep: Config.values.idle.sleep
        })

    readonly property var steps: root.handledElsewhere ? [] : Plan.plan(root.minutes, Battery.onBattery)

    function run(name: string): void {
        if (name === "lock")
            Lock.lock();
        else if (name === "screensOff")
            root.switchScreens(false);
        else if (name === "sleep" && Battery.onBattery)
            Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function resume(name: string): void {
        if (name === "screensOff")
            root.switchScreens(true);
    }

    function switchScreens(on: bool): void {
        if (root.screensOff === !on)
            return;
        root.screensOff = !on;
        Hypr.send(`hl.dsp.dpms({ action = "${on ? "on" : "off"}" })`, `dpms ${on ? "on" : "off"}`);
    }

    function recheck(): void {
        if (!handler.running)
            handler.running = true;
    }

    IdleMonitor {
        timeout: root.presenceSeconds
        respectInhibitors: true

        onIsIdleChanged: {
            root.idle = isIdle;
            if (isIdle)
                root.idleSince = Date.now() - root.presenceSeconds * 1000;
        }
    }

    Instantiator {
        model: root.steps

        delegate: IdleMonitor {
            required property var modelData

            timeout: modelData.seconds
            respectInhibitors: true

            onIsIdleChanged: {
                if (isIdle)
                    root.run(modelData.name);
                else
                    root.resume(modelData.name);
            }
        }

        onObjectRemoved: (index, object) => {
            if (object.modelData.name === "screensOff")
                root.resume("screensOff");
        }
    }

    Process {
        id: handler

        running: true
        command: ["pgrep", "-x", "hypridle"]

        stdout: StdioCollector {
            id: handlerOutput
        }

        onExited: root.handledElsewhere = Plan.handledBy(handlerOutput.text)
    }

    Timer {
        interval: root.handlerRecheckMs
        running: true
        repeat: true
        onTriggered: root.recheck()
    }
}
