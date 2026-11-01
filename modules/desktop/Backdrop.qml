import QtQuick
import qs.config
import "backdrop.js" as Look

Item {
    id: root

    property string source: ""
    property size screen: Qt.size(0, 0)
    property rect region: Qt.rect(0, 0, 0, 0)

    property bool lightInk: true
    property bool busy: false

    readonly property string url: root.source ? (root.source.startsWith("/") ? `file://${root.source}` : root.source) : ""
    readonly property real factor: root.screen.width > 0 ? 320 / root.screen.width : 0
    readonly property real inkOnDark: Look.luminance(Appearance.colour.paper.r * 255, Appearance.colour.paper.g * 255, Appearance.colour.paper.b * 255)
    readonly property real inkOnLight: Look.luminance(Appearance.colour.ink.r * 255, Appearance.colour.ink.g * 255, Appearance.colour.ink.b * 255)

    function measure(): void {
        if (!root.url) {
            root.lightInk = true;
            root.busy = false;
            return;
        }
        if (shape.status !== Image.Ready)
            return;
        if (probe.isImageLoaded(root.url))
            probe.requestPaint();
        else
            probe.loadImage(root.url);
    }

    onUrlChanged: settle.restart()
    onScreenChanged: settle.restart()
    onRegionChanged: settle.restart()
    onInkOnDarkChanged: settle.restart()
    onInkOnLightChanged: settle.restart()

    Timer {
        id: settle

        interval: 250
        onTriggered: root.measure()
    }

    Image {
        id: shape

        source: root.url
        sourceSize.width: 64
        asynchronous: true
        cache: false
        visible: false

        onStatusChanged: if (shape.status === Image.Ready)
            settle.restart()
    }

    Canvas {
        id: probe

        width: Math.max(1, Math.round(root.screen.width * root.factor))
        height: Math.max(1, Math.round(root.screen.height * root.factor))
        visible: false
        renderTarget: Canvas.Image

        onImageLoaded: probe.requestPaint()

        onPaint: {
            const url = root.url;
            if (!url || !probe.isImageLoaded(url))
                return;
            const fill = Look.placement(shape.implicitHeight > 0 ? shape.implicitWidth / shape.implicitHeight : 0, probe.width, probe.height);
            const spot = Look.shrunk(root.region, root.factor, probe.width, probe.height);
            const ctx = probe.getContext("2d");
            ctx.clearRect(0, 0, probe.width, probe.height);
            if (fill)
                ctx.drawImage(url, fill.x, fill.y, fill.width, fill.height);
            probe.unloadImage(url);
            if (!fill || !spot)
                return;
            const seen = Look.judge(ctx.getImageData(spot.x, spot.y, spot.width, spot.height).data, root.inkOnDark, root.inkOnLight);
            root.lightInk = seen.light;
            root.busy = seen.busy;
        }
    }
}
