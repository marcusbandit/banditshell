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

    readonly property real inkOnDark: Look.luminance(Appearance.colour.paper.r * 255, Appearance.colour.paper.g * 255, Appearance.colour.paper.b * 255)
    readonly property real inkOnLight: Look.luminance(Appearance.colour.ink.r * 255, Appearance.colour.ink.g * 255, Appearance.colour.ink.b * 255)

    function measure(): void {
        if (!root.source) {
            root.lightInk = true;
            root.busy = false;
            return;
        }
        if (picture.status === Image.Ready)
            probe.requestPaint();
    }

    onSourceChanged: settle.restart()
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
        id: picture

        source: root.source ? (root.source.startsWith("/") ? `file://${root.source}` : root.source) : ""
        sourceSize.width: 256
        asynchronous: true
        cache: false
        visible: false

        onStatusChanged: if (picture.status === Image.Ready)
            settle.restart()
    }

    Canvas {
        id: probe

        width: 24
        height: 24
        visible: false
        renderTarget: Canvas.Image

        onPaint: {
            const spot = Look.cover(picture.implicitWidth, picture.implicitHeight, root.screen.width, root.screen.height, root.region);
            if (!spot)
                return;
            const ctx = probe.getContext("2d");
            ctx.clearRect(0, 0, probe.width, probe.height);
            ctx.drawImage(picture, spot.x, spot.y, spot.width, spot.height, 0, 0, probe.width, probe.height);
            const seen = Look.judge(ctx.getImageData(0, 0, probe.width, probe.height).data, root.inkOnDark, root.inkOnLight);
            root.lightInk = seen.light;
            root.busy = seen.busy;
        }
    }
}
