pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "activities.js" as Logic

Singleton {
    id: root

    readonly property bool enabled: Config.values.island.levels

    property var covers: []
    property bool armed: false
    property var heard: ({})
    property string heardLayout: ""

    function cover(who: var, kinds: var): void {
        root.covers = [...root.covers.filter(c => c.who !== who), {
                who: who,
                kinds: kinds
            }];
    }

    function uncover(who: var): void {
        root.covers = root.covers.filter(c => c.who !== who);
    }

    function witness(kind: string, source: string, reading: var, ceiling: real): void {
        const slot = `${kind}:${source}`;
        const before = root.heard[slot];
        root.heard[slot] = reading;
        if (!root.armed || !Logic.levelDiffers(kind, before, reading))
            return;
        if (!Logic.levelWanted(root.enabled, root.covers, kind))
            return;
        Notices.pass(Logic.levelMoment(kind, reading.value, reading.muted, ceiling));
    }

    readonly property var speakers: ({
            value: Audio.volume,
            muted: Audio.muted
        })

    readonly property var microphone: ({
            value: Audio.sourceVolume,
            muted: Audio.sourceMuted
        })

    readonly property var screens: ({
            value: Display.level,
            muted: false
        })

    readonly property var panel: {
        const device = Backlight.devices[0];
        return {
            name: device?.name ?? "",
            value: device ? Backlight.levelOf(device.name) : -1,
            muted: false
        };
    }

    onSpeakersChanged: if (Audio.ready)
        root.witness("volume", Audio.sink?.name ?? "", root.speakers, Audio.maxVolume)

    onMicrophoneChanged: if (Audio.source?.ready)
        root.witness("mic", Audio.source?.name ?? "", root.microphone, 1)

    onScreensChanged: if (Display.levelKnown)
        root.witness("brightness", "display", root.screens, 1)

    onPanelChanged: if (root.panel.value >= 0)
        root.witness("brightness", `panel:${root.panel.name}`, root.panel, 1)

    readonly property string layout: Keymap.several && Keymap.layout ? `${Keymap.index}:${Keymap.layout}` : ""

    onLayoutChanged: {
        const before = root.heardLayout;
        root.heardLayout = root.layout;
        if (!root.armed || !before || !root.layout || before === root.layout)
            return;
        const moment = Logic.layoutMoment(Keymap.layout, Keymap.name, Keymap.shared);
        if (moment && Logic.levelWanted(root.enabled, root.covers, "layout"))
            Notices.pass(moment);
    }

    Timer {
        interval: 4000
        running: true
        onTriggered: root.armed = true
    }
}
