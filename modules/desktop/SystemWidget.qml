pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.config
import qs.components
import "load.js" as Load

Item {
    id: root

    property bool running: true
    property bool fromRight: false
    property real room: 0
    property real availWidth: 0
    property string expanded: ""
    property string showing: ""

    readonly property Item popoutItem: detailCard.visible ? detailCard : null

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

    implicitHeight: strip.implicitHeight

    function toggle(key: string): void {
        if (root.expanded === key) {
            root.expanded = "";
        } else {
            root.showing = key;
            root.expanded = key;
        }
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
            root.expanded = "";
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

    Row {
        id: strip

        width: parent.width
        spacing: Appearance.padding.normal

        readonly property real tileWidth: (width - spacing * (root.tileCount - 1)) / root.tileCount

        Tile {
            width: strip.tileWidth
            key: "cpu"
            label: "CPU"
            value: root.cpu
            tone: root.cpuTone
            history: root.cpuHistory
            phase: root.phase
            active: root.expanded === "cpu"
        }

        Tile {
            width: strip.tileWidth
            visible: root.hasGpu
            key: "gpu"
            label: "GPU"
            value: root.gpu
            tone: root.gpuTone
            history: root.gpuHistory
            phase: root.phase
            active: root.expanded === "gpu"
        }

        Tile {
            width: strip.tileWidth
            key: "memory"
            label: "Mem"
            value: root.memory.share
            tone: root.memoryTone
            history: root.memoryHistory
            phase: root.phase
            active: root.expanded === "memory"
        }
    }

    Follow {
        id: popoutOpen

        target: root.expanded !== "" ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    Item {
        id: detailCard

        readonly property real preferredWidth: Math.round(Appearance.font.size.small * 30)
        readonly property real sideGap: Appearance.padding.card
        readonly property bool fitsBeside: root.availWidth >= preferredWidth + sideGap
        readonly property real sideX: root.fromRight ? -(width + sideGap) : root.width + sideGap
        readonly property real clampedX: root.fromRight ? Math.max(-root.availWidth, sideX) : Math.min(root.availWidth - width + root.width, sideX)
        readonly property real openX: fitsBeside ? sideX : clampedX
        readonly property real clampedY: root.room > 0 ? Math.max(-root.y, Math.min(0, root.room - root.y - height)) : 0

        z: 10
        visible: popoutOpen.value > 0.002 && root.showing !== ""
        opacity: popoutOpen.value
        width: Math.min(preferredWidth, Math.max(root.width, root.availWidth))
        height: detailBody.implicitHeight + Appearance.padding.card * 2
        x: openX + (root.fromRight ? 1 : -1) * (1 - popoutOpen.value) * Appearance.padding.large
        y: clampedY

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surface
            stroke: Appearance.colour.separator
            strokeWidth: Appearance.stroke.line
        }

        Column {
            id: detailBody

            x: Appearance.padding.card
            y: Appearance.padding.card
            width: detailCard.width - Appearance.padding.card * 2
            spacing: Appearance.padding.normal

            Item {
                width: parent.width
                height: Math.max(detailTitle.implicitHeight, closeBtn.height)

                StyledText {
                    id: detailTitle

                    width: closeBtn.x - detailValue.implicitWidth - Appearance.padding.normal * 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.showing === "cpu" ? `Processor (${root.cores.length} cores)` : root.showing === "gpu" ? (root.gpuInfo.name || "GPU") : "Memory"
                    color: Appearance.colour.textDim
                    elide: Text.ElideRight
                }

                StyledText {
                    id: detailValue

                    anchors.right: closeBtn.left
                    anchors.rightMargin: Appearance.padding.small
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.showing === "cpu" ? `${Math.round(root.cpu * 100)}%` : root.showing === "gpu" ? `${Math.round(root.gpu * 100)}%` : `${Math.round(root.memory.share * 100)}%`
                    color: Appearance.hued ? (root.showing === "cpu" ? root.cpuTone : root.showing === "gpu" ? root.gpuTone : root.memoryTone) : Appearance.colour.text
                    font.weight: Font.DemiBold
                }

                Item {
                    id: closeBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24

                    SquircleRect {
                        anchors.fill: parent
                        pill: "object"
                        color: Appearance.colour.fill
                        opacity: closeHover.hovered ? 1 : 0
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "close"
                        size: Appearance.icon.small
                        color: Appearance.colour.textFaint
                    }

                    HoverHandler {
                        id: closeHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = ""
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
                    path: Load.areaPath(traceBox.history, traceShape.width, traceShape.height, root.historyLimit, traceBox.phase)
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

    component Tile: Item {
        id: tile

        property string key: ""
        property string label: ""
        property real value: 0
        property color tone: Appearance.colour.accent
        property var history: []
        property real phase: 1
        property bool active: false
        property bool dwelled: false

        readonly property int pad: Appearance.padding.normal
        readonly property real displayed: tile.history.length >= 2 ? Load.tipValue(tile.history, tile.phase) : tile.value

        implicitHeight: header.y + header.height + Appearance.padding.small + 46 + Appearance.padding.small

        Timer {
            id: dwellTimer

            interval: Appearance.animation.dwell
            running: tileHover.hovered && !tile.active
            onTriggered: tile.dwelled = true
        }

        Follow {
            id: hoverGlow

            target: tileHover.hovered ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        Follow {
            id: cueFade

            target: tile.dwelled || tile.active ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surface
            stroke: tile.active ? tile.tone : Appearance.colour.separator
            strokeWidth: tile.active ? Appearance.stroke.ring : (tileHover.hovered ? Appearance.stroke.line : 0)
        }

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.fill
            opacity: hoverGlow.value
        }

        Icon {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: tile.pad - 2
            anchors.topMargin: tile.pad
            name: tile.active ? "close" : (root.fromRight ? "chevron_left" : "chevron_right")
            size: Appearance.icon.small
            color: tile.active ? tile.tone : Appearance.colour.textFaint
            opacity: cueFade.value
        }

        Column {
            id: header

            x: tile.pad
            y: tile.pad
            width: tile.width - tile.pad * 2

            StyledText {
                text: tile.label
                color: Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.small
            }

            StyledText {
                text: `${Math.round(tile.displayed * 100)}%`
                color: Appearance.hued ? tile.tone : Appearance.colour.text
                font.pixelSize: Appearance.font.size.normal
                font.weight: Font.DemiBold
            }
        }

        Trace {
            x: 0
            y: header.y + header.height + Appearance.padding.small
            width: tile.width
            height: 46
            history: tile.history
            phase: tile.phase
            tone: tile.tone
            fadeLeft: tile.pad * 1.8
            fadeRight: tile.pad * 1.4
        }

        HoverHandler {
            id: tileHover

            onHoveredChanged: if (!hovered)
                tile.dwelled = false
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggle(tile.key)
        }
    }
}
