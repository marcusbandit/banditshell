pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import "load.js" as Load

WidgetCard {
    id: root

    property bool running: true
    property var lastTimes: null
    property double lastAt: 0
    property real cpu: 0
    property var memory: ({
            share: 0,
            usedGb: 0,
            totalGb: 0
        })

    function sample(): void {
        stat.reload();
        meminfo.reload();
    }

    onRunningChanged: if (root.running)
        root.lastTimes = null

    Timer {
        interval: 2000
        repeat: true
        running: root.running && root.visible
        triggeredOnStart: true
        onTriggered: root.sample()
    }

    FileView {
        id: stat

        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const at = Date.now();
            if (root.lastTimes && at - root.lastAt < 1000)
                return;
            const now = Load.cpuTimes(text());
            if (root.lastTimes && now)
                root.cpu = Load.cpuShare(root.lastTimes, now);
            root.lastTimes = now;
            root.lastAt = at;
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.memory = Load.memoryShare(text())
    }

    Row {
        width: parent.width
        spacing: Appearance.padding.card

        Gauge {
            width: (parent.width - parent.spacing) / 2
            label: "Processor"
            value: root.cpu
        }

        Gauge {
            width: (parent.width - parent.spacing) / 2
            label: "Memory"
            value: root.memory.share
            strained: root.memory.share > 0.9
        }
    }

    component Gauge: Item {
        id: gauge

        property string label: ""
        property real value: 0
        property bool strained: false

        height: ring.height

        Follow {
            id: eased

            target: gauge.value
            speed: Appearance.animation.trackSpeed
            epsilon: 0.002
        }

        ProgressRing {
            id: ring

            size: 52
            thickness: 5
            value: eased.value
            colour: gauge.strained ? Appearance.colour.warning : Appearance.colour.accent
        }

        Column {
            x: ring.width + Appearance.padding.normal
            width: parent.width - x
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                text: `${Math.round(gauge.value * 100)}%`
                font.pixelSize: Appearance.font.size.large
                font.weight: Font.DemiBold
            }

            StyledText {
                width: parent.width
                text: gauge.label
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }
        }
    }
}
