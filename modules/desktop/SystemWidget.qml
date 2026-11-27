pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.config
import qs.components
import "load.js" as Load

DeskWidget {
    id: root

    property bool running: true
    property string showing: "cpu"

    property var lastTimes: null
    property var lastCores: null
    property double lastAt: 0
    property real cpu: 0
    property real cpuTemp: 0
    property string cpuTempPath: ""
    property var cores: []
    property real gpu: 0
    property var gpuInfo: ({
            share: 0,
            vramUsedGb: 0,
            vramTotalGb: 0,
            vramShare: 0,
            tempC: 0,
            name: ""
        })
    property var memory: ({
            share: 0,
            usedGb: 0,
            totalGb: 0,
            availableGb: 0,
            cachedGb: 0,
            swapUsedGb: 0,
            swapTotalGb: 0,
            swapShare: 0
        })
    property var swaps: []

    property string gpuMode: ""
    property string gpuPath: ""
    readonly property bool hasGpu: root.gpuMode !== ""
    readonly property int tileCount: root.hasGpu ? 3 : 2

    readonly property int sampleInterval: 1000
    readonly property int historyLimit: 24
    property double sampleAt: 0
    property real phase: 1
    property var cpuHistory: []
    property var cpuTempHistory: []
    property var coreHistories: []
    property var gpuHistory: []
    property var vramHistory: []
    property var gpuTempHistory: []
    property var memoryHistory: []
    property var swapHistory: []

    readonly property color cpuTone: Appearance.huedOr(Appearance.hue.processor, Appearance.colour.accent)
    readonly property color gpuTone: Appearance.huedOr(Appearance.hue.graphics, Appearance.colour.accent)
    readonly property color memoryTone: root.memory.share > 0.9 ? Appearance.colour.warning : Appearance.huedOr(Appearance.hue.memory, Appearance.colour.accent)

    readonly property real pad: Appearance.padding.card
    readonly property real column: Math.round(Appearance.font.size.small * 6.6)
    readonly property var meters: root.hasGpu ? ["cpu", "gpu", "memory"] : ["cpu", "memory"]

    key: "system"
    fallbackSize: "medium"

    onTapped: (x, y) => {
        if (root.form !== "medium")
            return;
        const step = root.column + Appearance.padding.normal;
        const at = Math.floor((x - root.pad + Appearance.padding.normal / 2) / step);
        root.showing = root.meters[Math.max(0, Math.min(root.meters.length - 1, at))];
    }

    function sample(): void {
        stat.reload();
        meminfo.reload();
        swapsFile.reload();
        if (root.cpuTempPath !== "")
            cpuTempFile.reload();
        if (root.gpuMode === "file")
            gpuFile.reload();
        else if (root.gpuMode === "nvidia" && !gpuQuery.running)
            gpuQuery.running = true;
    }

    function record(): void {
        const cap = root.historyLimit + 1;
        root.cpuHistory = Load.pushHistory(root.cpuHistory, root.cpu, cap);
        root.coreHistories = Load.pushCoreHistories(root.coreHistories, root.cores, cap);
        if (root.cpuTemp > 0)
            root.cpuTempHistory = Load.pushHistory(root.cpuTempHistory, Load.tempShare(root.cpuTemp), cap);
        root.memoryHistory = Load.pushHistory(root.memoryHistory, root.memory.share, cap);
        if (root.memory.swapTotalGb > 0)
            root.swapHistory = Load.pushHistory(root.swapHistory, root.memory.swapShare, cap);
        if (root.hasGpu) {
            root.gpuHistory = Load.pushHistory(root.gpuHistory, root.gpu, cap);
            if (root.gpuInfo.vramTotalGb > 0)
                root.vramHistory = Load.pushHistory(root.vramHistory, root.gpuInfo.vramShare, cap);
            if (root.gpuInfo.tempC > 0)
                root.gpuTempHistory = Load.pushHistory(root.gpuTempHistory, Load.tempShare(root.gpuInfo.tempC), cap);
        }
        root.sampleAt = Date.now();
        root.phase = Appearance.still ? 1 : 0;
    }

    onRunningChanged: {
        if (root.running) {
            root.lastTimes = null;
            root.lastCores = null;
        } else {
            root.close();
        }
    }

    FrameAnimation {
        running: root.running && root.visible && !Appearance.still && root.phase < 1 && root.cpuHistory.length >= 2
        onTriggered: root.phase = Math.min(1, (Date.now() - root.sampleAt) / root.sampleInterval)
    }

    Process {
        id: gpuProbe

        running: true
        command: ["sh", "-c", "for f in /sys/class/drm/card*/device/gpu_busy_percent; do [ -r \"$f\" ] && printf 'file:%s\\n' \"$f\" && exit 0; done; command -v nvidia-smi >/dev/null 2>&1 && echo nvidia"]
        stdout: StdioCollector {
            onStreamFinished: {
                const reply = text.trim();
                if (reply.startsWith("file:")) {
                    root.gpuPath = reply.slice(5);
                    root.gpuMode = "file";
                } else if (reply === "nvidia") {
                    root.gpuMode = "nvidia";
                }
            }
        }
    }

    Process {
        id: cpuTempProbe

        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case \"$(cat \"$h/name\" 2>/dev/null)\" in coretemp|k10temp|zenpower|cpu_thermal|soc_thermal) for l in \"$h\"/temp*_label; do case \"$(cat \"$l\" 2>/dev/null)\" in 'Package id 0'|Tctl|Tdie) echo \"${l%_label}_input\"; exit 0;; esac; done; [ -e \"$h/temp1_input\" ] && echo \"$h/temp1_input\" && exit 0;; esac; done; for z in /sys/class/thermal/thermal_zone*; do case \"$(cat \"$z/type\" 2>/dev/null)\" in x86_pkg_temp|k10temp|cpu*|soc*) echo \"$z/temp\"; exit 0;; esac; done; [ -e /sys/class/thermal/thermal_zone0/temp ] && echo /sys/class/thermal/thermal_zone0/temp"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuTempPath = text.trim()
        }
    }

    Timer {
        interval: root.sampleInterval
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
            if (root.lastTimes && at - root.lastAt < 200)
                return;
            const raw = text();
            const now = Load.cpuTimes(raw);
            const nowCores = Load.coreTimes(raw);
            if (root.lastTimes && now) {
                root.cpu = Load.cpuShare(root.lastTimes, now);
                if (root.lastCores && nowCores)
                    root.cores = Load.coreShares(root.lastCores, nowCores);
                root.record();
            }
            root.lastTimes = now;
            root.lastCores = nowCores;
            root.lastAt = at;
        }
    }

    FileView {
        id: cpuTempFile

        path: root.cpuTempPath
        printErrors: false
        onLoaded: {
            const milli = Number(text().trim());
            if (isFinite(milli) && milli > 0)
                root.cpuTemp = milli / 1000;
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: root.memory = Load.memoryDetail(text())
    }

    FileView {
        id: swapsFile

        path: "/proc/swaps"
        printErrors: false
        onLoaded: root.swaps = Load.swapDevices(text())
    }

    FileView {
        id: gpuFile

        path: root.gpuPath
        printErrors: false
        onLoaded: {
            const stats = Load.gpuStats(text());
            if (stats) {
                root.gpu = stats.share;
                root.gpuInfo = stats;
            }
        }
    }

    Process {
        id: gpuQuery

        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,name", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const stats = Load.gpuStats(text);
                if (stats) {
                    root.gpu = stats.share;
                    root.gpuInfo = stats;
                }
            }
        }
    }

    function labelOf(which: string): string {
        return which === "cpu" ? "CPU" : which === "gpu" ? "GPU" : "Mem";
    }

    function historyOf(which: string): var {
        return which === "cpu" ? root.cpuHistory : which === "gpu" ? root.gpuHistory : root.memoryHistory;
    }

    function toneOf(which: string): color {
        return which === "cpu" ? root.cpuTone : which === "gpu" ? root.gpuTone : root.memoryTone;
    }

    function reading(which: string): real {
        const history = root.historyOf(which);
        return history.length >= 2 ? Load.tipValue(history, root.phase) : which === "cpu" ? root.cpu : which === "gpu" ? root.gpu : root.memory.share;
    }

    small: Item {
        implicitWidth: smallRow.implicitWidth + root.pad * 2
        implicitHeight: smallRow.implicitHeight + Appearance.padding.normal * 2

        Row {
            id: smallRow

            x: root.pad
            y: Appearance.padding.normal
            spacing: Appearance.padding.large

            Repeater {
                model: root.meters

                delegate: Column {
                    id: chip

                    required property string modelData

                    spacing: 2

                    Row {
                        id: chipHead

                        spacing: Appearance.padding.small

                        StyledText {
                            anchors.baseline: chipValue.baseline
                            text: root.labelOf(chip.modelData)
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                        }

                        StyledText {
                            id: chipValue

                            text: `${Math.round(root.reading(chip.modelData) * 100)}%`
                            color: Appearance.hued ? root.toneOf(chip.modelData) : Appearance.colour.text
                            font.weight: Font.DemiBold
                        }
                    }

                    Trace {
                        width: chipHead.width
                        height: Math.round(Appearance.font.size.small * 0.9)
                        history: root.historyOf(chip.modelData)
                        phase: root.phase
                        tone: root.toneOf(chip.modelData)
                        fadeLeft: Appearance.padding.small
                        fadeRight: Appearance.padding.small
                        strokeWidth: 1.5
                        filled: false
                    }
                }
            }
        }
    }

    medium: Item {
        implicitWidth: mediumRow.implicitWidth + root.pad * 2
        implicitHeight: mediumRow.implicitHeight + root.pad * 2

        Row {
            id: mediumRow

            x: root.pad
            y: root.pad
            spacing: Appearance.padding.normal

            Repeater {
                model: root.meters

                delegate: Meter {
                    required property string modelData

                    width: root.column
                    which: modelData
                }
            }
        }
    }

    large: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 30) + root.pad * 2
        implicitHeight: largeBody.implicitHeight + root.pad * 2

        Column {
            id: largeBody

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            spacing: Appearance.padding.large

            Row {
                id: largeRow

                width: parent.width
                spacing: Appearance.padding.normal

                Repeater {
                    model: root.meters

                    delegate: Meter {
                        id: pick

                        required property string modelData

                        width: (largeRow.width - largeRow.spacing * (root.meters.length - 1)) / root.meters.length
                        which: modelData
                        chosen: root.showing === modelData

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showing = pick.modelData
                        }
                    }
                }
            }

            Column {
                visible: root.showing === "cpu"
                width: parent.width
                spacing: Appearance.padding.normal

                Grid {
                    width: parent.width
                    columns: root.cores.length > 16 ? 4 : 3
                    columnSpacing: Appearance.padding.small
                    rowSpacing: Appearance.padding.small

                    Repeater {
                        model: root.showing === "cpu" ? root.cores : []

                        delegate: Item {
                            id: coreCell

                            required property int index
                            required property var modelData

                            readonly property var hist: root.coreHistories[coreCell.index] || []
                            readonly property real displayed: hist.length >= 2 ? Load.tipValue(hist, root.phase) : coreCell.modelData.share
                            readonly property color coreTone: displayed > 0.9 ? Appearance.colour.warning : root.cpuTone

                            width: (parent.width - parent.columnSpacing * (parent.columns - 1)) / parent.columns
                            height: 54

                            SquircleRect {
                                anchors.fill: parent
                                radius: Appearance.rounding.normal
                                color: Appearance.colour.fill
                            }

                            Item {
                                id: coreHead

                                x: Appearance.padding.small
                                y: Appearance.padding.hair + 2
                                width: parent.width - Appearance.padding.small * 2
                                height: coreIdx.implicitHeight

                                StyledText {
                                    id: coreIdx

                                    text: coreCell.modelData.id < 10 ? `0${coreCell.modelData.id}` : `${coreCell.modelData.id}`
                                    color: Appearance.colour.textFaint
                                    font.pixelSize: Appearance.font.size.small
                                }

                                StyledText {
                                    anchors.right: parent.right
                                    text: `${Math.round(coreCell.displayed * 100)}%`
                                    color: coreCell.displayed > 0.5 ? coreCell.coreTone : Appearance.colour.textDim
                                    font.pixelSize: Appearance.font.size.small
                                    font.weight: Font.DemiBold
                                }
                            }

                            Trace {
                                x: 0
                                y: coreHead.y + coreHead.height + 2
                                width: parent.width
                                height: parent.height - y - 2
                                history: coreCell.hist
                                phase: root.phase
                                tone: coreCell.coreTone
                                fadeLeft: Appearance.padding.small * 1.4
                                fadeRight: Appearance.padding.small
                                strokeWidth: 1.5
                            }
                        }
                    }
                }

                GraphBlock {
                    width: parent.width
                    visible: root.cpuTemp > 0
                    label: "Temperature"
                    aside: `${Math.round(root.cpuTemp)}°C`
                    history: root.cpuTempHistory
                    tone: root.cpuTemp >= 85 ? Appearance.colour.warning : root.cpuTone
                }
            }

            Column {
                visible: root.showing === "gpu"
                width: parent.width
                spacing: Appearance.padding.normal

                GraphBlock {
                    width: parent.width
                    label: "Utilisation"
                    aside: `${Math.round(root.gpu * 100)}%`
                    history: root.gpuHistory
                    tone: root.gpuTone
                }

                GraphBlock {
                    width: parent.width
                    visible: root.gpuInfo.vramTotalGb > 0
                    label: "VRAM"
                    aside: `${root.gpuInfo.vramUsedGb.toFixed(1)} / ${root.gpuInfo.vramTotalGb.toFixed(1)} GB`
                    history: root.vramHistory
                    tone: root.gpuInfo.vramShare > 0.9 ? Appearance.colour.warning : root.gpuTone
                }

                GraphBlock {
                    width: parent.width
                    visible: root.gpuInfo.tempC > 0
                    label: "Temperature"
                    aside: `${root.gpuInfo.tempC}°C`
                    history: root.gpuTempHistory
                    tone: root.gpuInfo.tempC >= 85 ? Appearance.colour.warning : root.gpuTone
                }
            }

            Column {
                visible: root.showing === "memory"
                width: parent.width
                spacing: Appearance.padding.normal

                GraphBlock {
                    width: parent.width
                    label: "RAM"
                    aside: `${root.memory.usedGb.toFixed(1)} / ${root.memory.totalGb.toFixed(1)} GB`
                    history: root.memoryHistory
                    tone: root.memoryTone
                }

                DetailRow {
                    width: parent.width
                    label: "Available"
                    value: `${root.memory.availableGb.toFixed(1)} GB`
                }

                DetailRow {
                    width: parent.width
                    label: "Cached"
                    value: `${root.memory.cachedGb.toFixed(1)} GB`
                }

                GraphBlock {
                    width: parent.width
                    visible: root.memory.swapTotalGb > 0
                    label: "Swap"
                    aside: `${root.memory.swapUsedGb.toFixed(1)} / ${root.memory.swapTotalGb.toFixed(1)} GB`
                    history: root.swapHistory
                    tone: root.memory.swapShare > 0.8 ? Appearance.colour.warning : Appearance.colour.textDim
                }

                Repeater {
                    model: root.showing === "memory" ? root.swaps : []

                    delegate: DetailRow {
                        required property var modelData

                        width: parent.width
                        label: modelData.name
                        value: `${modelData.usedGb.toFixed(1)} / ${modelData.totalGb.toFixed(1)} GB`
                    }
                }
            }
        }
    }

    component Trace: Item {
        id: traceBox

        property var history: []
        property real phase: 1
        property color tone: Appearance.colour.accent
        property real fadeLeft: Appearance.padding.normal * 1.8
        property real fadeRight: Appearance.padding.normal * 1.4
        property real strokeWidth: 2
        property bool filled: true

        layer.enabled: true
        layer.effect: ShaderEffect {
            readonly property vector4d fades: Qt.vector4d(traceBox.fadeLeft, traceBox.fadeRight, width, 0)

            fragmentShader: Qt.resolvedUrl("../../components/edgefade.frag.qsb")
        }

        Shape {
            id: traceShape

            x: 0
            y: 2
            width: traceBox.width
            height: Math.max(2, traceBox.height - 2)
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"

                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: traceShape.height

                    GradientStop {
                        position: 0
                        color: Appearance.withAlpha(traceBox.tone, 0.34)
                    }

                    GradientStop {
                        position: 0.65
                        color: Appearance.withAlpha(traceBox.tone, 0.1)
                    }

                    GradientStop {
                        position: 1
                        color: Appearance.withAlpha(traceBox.tone, 0)
                    }
                }

                PathSvg {
                    path: traceBox.filled ? Load.areaPath(traceBox.history, traceShape.width, traceShape.height, root.historyLimit, traceBox.phase) : ""
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: traceBox.tone
                strokeWidth: traceBox.strokeWidth
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: Load.linePath(traceBox.history, traceShape.width, traceShape.height, root.historyLimit, traceBox.phase)
                }
            }
        }
    }

    component GraphBlock: Item {
        id: block

        property string label: ""
        property string aside: ""
        property var history: []
        property color tone: Appearance.colour.accent

        implicitHeight: blockHead.y + blockHead.height + Appearance.padding.hair + 42 + Appearance.padding.hair

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
        }

        Item {
            id: blockHead

            x: Appearance.padding.normal
            y: Appearance.padding.small
            width: parent.width - Appearance.padding.normal * 2
            height: Math.max(blockLabel.implicitHeight, blockAside.implicitHeight)

            StyledText {
                id: blockLabel

                text: block.label
                color: Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.small
            }

            StyledText {
                id: blockAside

                anchors.right: parent.right
                text: block.aside
                color: Appearance.hued ? block.tone : Appearance.colour.text
                font.pixelSize: Appearance.font.size.small
                font.weight: Font.DemiBold
            }
        }

        Trace {
            x: 0
            y: blockHead.y + blockHead.height + Appearance.padding.hair
            width: parent.width
            height: 42
            history: block.history
            phase: root.phase
            tone: block.tone
        }
    }

    component DetailRow: Item {
        id: infoRow

        property string label: ""
        property string value: ""

        height: Math.max(rowLabel.implicitHeight, rowValue.implicitHeight)

        StyledText {
            id: rowLabel

            text: infoRow.label
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
        }

        StyledText {
            id: rowValue

            anchors.right: parent.right
            text: infoRow.value
            color: Appearance.colour.text
            font.pixelSize: Appearance.font.size.small
        }
    }

    component Meter: Item {
        id: meterView

        property string which: ""
        property bool chosen: false

        readonly property real inset: Appearance.padding.small

        implicitHeight: meterHead.y + meterHead.height + Appearance.padding.hair + 46 + meterView.inset

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
            opacity: meterView.chosen ? 1 : 0
        }

        Column {
            id: meterHead

            x: meterView.inset
            y: meterView.inset

            StyledText {
                text: root.labelOf(meterView.which)
                color: Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.small
            }

            StyledText {
                text: `${Math.round(root.reading(meterView.which) * 100)}%`
                color: Appearance.hued ? root.toneOf(meterView.which) : Appearance.colour.text
                font.pixelSize: Appearance.font.size.normal
                font.weight: Font.DemiBold
            }
        }

        Trace {
            y: meterHead.y + meterHead.height + Appearance.padding.hair
            width: meterView.width
            height: 46
            history: root.historyOf(meterView.which)
            phase: root.phase
            tone: root.toneOf(meterView.which)
            fadeLeft: meterView.inset * 1.8
            fadeRight: meterView.inset * 1.4
        }
    }
}
