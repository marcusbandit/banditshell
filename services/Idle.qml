pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import "idle.js" as Plan

Singleton {
    id: root

    property string handler: ""

    readonly property bool handledElsewhere: root.handler !== ""

    property string handlerConfig: ""

    property var handlerTimes: null

    property bool idle: false

    property bool awake: false

    property double awakeUntil: 0

    property bool napping: false

    property double idleSince: 0

    property bool screensOff: false

    readonly property int presenceSeconds: 60

    readonly property int handlerRecheckMs: 30 * 1000

    readonly property string planText: root.handledElsewhere ? "[]" : JSON.stringify(Plan.plan({
            lock: Config.values.idle.lock,
            screensOff: Config.values.idle.screensOff,
            sleep: Config.values.idle.sleep
        }, Battery.onBattery))

    readonly property var steps: JSON.parse(root.planText)

    function run(name: string): void {
        if (name === "lock")
            SessionControl.requestLock();
        else if (name === "screensOff")
            root.switchScreens(false);
        else if (name === "sleep" && Battery.onBattery)
            Suspension.perform("suspend");
    }

    function resume(name: string): void {
        if (name === "screensOff")
            root.switchScreens(true);
    }

    function stayAwake(seconds: int): void {
        root.awakeUntil = seconds > 0 ? Date.now() + seconds * 1000 : 0;
        root.awake = true;
    }

    function sleepScreens(): void {
        root.napping = true;
        root.switchScreens(false);
    }

    onAwakeChanged: if (!root.awake)
        root.awakeUntil = 0

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

    Timer {
        running: root.awake && root.awakeUntil > 0
        interval: Math.max(1000, root.awakeUntil - Date.now())
        onTriggered: root.awake = false
    }

    IdleMonitor {
        id: nap

        property bool rested: false

        enabled: root.napping
        timeout: 1
        respectInhibitors: false

        onEnabledChanged: nap.rested = false
        onIsIdleChanged: {
            if (nap.isIdle) {
                nap.rested = true;
            } else if (nap.rested) {
                root.napping = false;
                root.switchScreens(true);
            }
        }
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
        command: ["pgrep", "-l", "-x", Plan.IDLE_DAEMONS.join("|")]

        stdout: StdioCollector {
            id: handlerOutput
        }

        onExited: root.handler = Plan.handlerOf(handlerOutput.text)
    }

    onHandlerChanged: {
        root.handlerTimes = null;
        root.handlerConfig = "";
        if (root.handler === "hypridle")
            configFinder.running = true;
    }

    Process {
        id: configFinder

        command: ["pgrep", "-a", "-x", "hypridle"]

        stdout: StdioCollector {
            id: configFinderOutput
        }

        onExited: root.handlerConfig = root.handler === "hypridle" ? Plan.hypridleConfigPath(configFinderOutput.text, Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`) : ""
    }

    FileView {
        id: handlerFile

        path: root.handlerConfig
        printErrors: false
        watchChanges: true

        onFileChanged: handlerFile.reload()
        onLoaded: root.handlerTimes = Plan.hypridleTimes(handlerFile.text())
        onLoadFailed: root.handlerTimes = null
    }

    Timer {
        interval: root.handlerRecheckMs
        running: true
        onTriggered: root.recheck()
    }

    IdleMonitor {
        timeout: root.presenceSeconds / 2
        respectInhibitors: true

        onIsIdleChanged: if (isIdle)
            root.recheck()
    }
}
