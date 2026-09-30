pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.config

Item {
    id: root

    property real level: 0
    property bool charging: false

    property string reading: `${Math.floor(Math.max(0, Math.min(1, root.level)) * 100)}%`

    property color liquid: Appearance.colour.accent
    property color well: Appearance.colour.fillStronger

    readonly property real radius: Appearance.rounding.normal

    readonly property real margin: Appearance.padding.large

    TextMetrics {
        id: widest

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.normal
        text: "100%"
    }

    TextMetrics {
        id: glyphs

        font: widest.font
        text: root.reading
    }

    readonly property real leastWidth: Math.ceil(widest.tightBoundingRect.width + root.margin * 2)

    implicitWidth: leastWidth
    implicitHeight: Math.round(leastWidth * 223 / 140)

    Follow {
        id: charge

        target: Math.max(0, Math.min(1, root.level))
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    readonly property real wavelength: root.width / 2
    readonly property real swell: root.width * 0.05

    readonly property real detune: 1.7

    readonly property real meniscus: swell

    readonly property real contact: 3

    readonly property real line: root.height * (1 - charge.value)

    property real phase: 0

    readonly property int drift: root.charging ? Appearance.anim.slow * 6 : Appearance.anim.slow * 20

    Timer {
        interval: 16
        repeat: true

        running: root.visible && charge.value > 0

        onTriggered: root.phase = (root.phase + 2 * Math.PI * (interval / root.drift)) % (2 * Math.PI)
    }

    function crest(x: real, amp: real): real {
        const k = 2 * Math.PI / root.wavelength;
        return root.line - amp * (0.75 * Math.sin(k * x + root.phase) + 0.25 * Math.sin(k * root.detune * x - 2 * root.phase + 1.1));
    }

    function surface(): var {
        const w = root.width;
        const h = root.height;
        if (w <= 0 || h <= 0 || charge.value <= 0)
            return [];

        const room = Math.min(root.line, h - root.line);
        const amp = Math.min(root.swell, room);
        const rise = Math.min(root.meniscus, room);
        const reach = Math.min(root.meniscus, w / 2);

        const pts = [];
        const n = root.contact;

        const turns = 10;
        const walk = (i, mirror) => {
            const t = i / turns * Math.PI / 2;
            const along = reach * (1 - Math.pow(Math.cos(t), 2 / n));
            const lift = rise * (1 - Math.pow(Math.sin(t), 2 / n));
            const x = mirror ? w - along : along;
            pts.push(Qt.point(x, root.crest(x, amp) - lift));
        };

        for (let i = 0; i <= turns; i++)
            walk(i, false);

        const span = w - reach * 2;
        const steps = Math.max(2, Math.round(span / 2));
        for (let i = 1; i < steps; i++) {
            const x = reach + span * i / steps;
            pts.push(Qt.point(x, root.crest(x, amp)));
        }

        for (let i = turns; i >= 0; i--)
            walk(i, true);

        pts.push(Qt.point(w, h));
        pts.push(Qt.point(0, h));
        return pts;
    }

    readonly property real markX: width - root.margin - (glyphs.tightBoundingRect.x + glyphs.tightBoundingRect.width)
    readonly property real markY: height - root.margin - mark.baselineOffset - glyphs.tightBoundingRect.y - glyphs.tightBoundingRect.height

    component Silhouette: Item {
        property color shade: root.well

        anchors.fill: parent

        SquircleRect {
            anchors.fill: parent
            radius: root.radius
            color: parent.shade
        }
    }

    Silhouette {}

    StyledText {
        id: mark

        x: root.markX
        y: root.markY
        text: root.reading
        font: widest.font
    }

    Shape {
        id: wave

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        visible: false

        ShapePath {
            fillColor: root.liquid
            strokeWidth: 0
            strokeColor: "transparent"

            PathPolyline {
                path: root.surface()
            }
        }
    }

    Silhouette {
        id: silhouette

        shade: "white"
        layer.enabled: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wave
        maskEnabled: true
        maskSource: silhouette
    }

    Item {
        id: lit

        anchors.fill: parent
        layer.enabled: true
        visible: false

        StyledText {
            x: root.markX
            y: root.markY
            text: root.reading
            font: widest.font
            color: Appearance.colour.accentText
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: lit
        maskEnabled: true
        maskSource: wave
    }
}
