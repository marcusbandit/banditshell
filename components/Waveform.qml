import QtQuick
import qs.config

Item {
    id: root

    property var levels: []
    property bool running: true
    property real pitch: 4
    property color colour: Appearance.colour.accent
    property int mode: 0
    property real flow: 0
    property real caret: 0
    property real fill: 0
    property real floor: 0.12
    property int detail: 2
    property real fadeWidth: 0.12
    property real fadeFloor: 0.25

    readonly property int slots: 128

    property int count: 0
    property real head: -2
    property real gap: 40
    property double heardAt: 0
    property var pending: []
    property bool wiped: true

    function reset(): void {
        root.count = 0;
        root.head = -2;
        root.pending = [];
        root.wiped = true;
        strip.requestPaint();
    }

    function take(value: real): void {
        const at = Date.now();
        const since = at - root.heardAt;
        if (root.heardAt > 0 && since > 5 && since < 400)
            root.gap = root.gap * 0.8 + since * 0.2;
        root.heardAt = at;
        root.pending = [...root.pending, {
                slot: root.count % root.slots,
                value: Math.max(0, Math.min(1, value))
            }];
        root.count += 1;
        strip.requestPaint();
    }

    onLevelsChanged: if (root.levels.length > 0)
        root.take(root.levels[root.levels.length - 1])

    Component.onCompleted: {
        const history = root.levels.slice(-root.slots);
        root.pending = history.map((v, i) => ({
                    slot: i,
                    value: Math.max(0, Math.min(1, v))
                }));
        root.count = history.length;
        root.head = root.count - 2;
        strip.requestPaint();
    }

    FrameAnimation {
        running: root.running && root.mode === 0 && root.count > 0

        onTriggered: {
            const lag = root.count - 1 - root.head;
            const hurry = 1 + Math.max(0, lag - 2.5) * 0.6;
            const next = root.head + frameTime * 1000 / Math.max(10, root.gap) * hurry;
            root.head = Math.max(root.count - 6, Math.min(root.count - 2, next));
        }
    }

    Canvas {
        id: strip

        width: root.slots
        height: 1
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate

        onPaint: {
            const ctx = strip.getContext("2d");
            if (root.wiped) {
                ctx.fillStyle = "black";
                ctx.fillRect(0, 0, root.slots, 1);
                root.wiped = false;
            }
            for (const p of root.pending) {
                ctx.fillStyle = Qt.rgba(p.value, p.value, p.value, 1);
                ctx.fillRect(p.slot, 0, 1, 1);
            }
            root.pending = [];
        }
    }

    ShaderEffectSource {
        id: texture

        sourceItem: strip
        hideSource: true
        smooth: false
        live: true
        textureSize: Qt.size(root.slots, 1)
    }

    ShaderEffect {
        anchors.fill: parent

        property var levels: texture
        readonly property vector4d size: Qt.vector4d(width, height, root.slots, Math.max(1, root.pitch))
        readonly property color colour: root.colour
        readonly property vector4d motion: Qt.vector4d(root.head, root.mode, root.flow, root.caret)
        readonly property vector4d shape: Qt.vector4d(root.fill, root.floor, 0, 0)
        readonly property vector4d edges: Qt.vector4d(root.fadeWidth, root.fadeFloor, Math.max(1, Math.min(4, root.detail)), 0)

        fragmentShader: Qt.resolvedUrl("waveform.frag.qsb")
    }
}
