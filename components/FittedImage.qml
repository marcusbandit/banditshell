import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

Item {
    id: root

    property string source: ""
    property color colour: Appearance.colour.text

    property bool tint: true

    readonly property bool ready: image.status === Image.Ready

    property var box: AppIcons.fitFor(source) ?? [0, 0, 1, 1, 0]

    readonly property real span: Math.max(box[2], box[3], 0.05)

    readonly property real optical: 0.86
    readonly property real factor: Math.min(optical / span, 2.5)

    readonly property real discFill: Math.PI / 4
    readonly property real solidAt: root.discFill * 0.95
    readonly property bool solid: box.length > 4 && box[4] > root.solidAt
    readonly property bool tinted: tint && !solid

    implicitWidth: Appearance.font.iconSize
    implicitHeight: implicitWidth

    onSourceChanged: {
        root.box = AppIcons.fitFor(source) ?? [0, 0, 1, 1, 0];
        if (source && !AppIcons.fitFor(source))
            probe.measure();
    }

    Image {
        id: image

        width: root.width * root.factor
        height: root.height * root.factor
        x: root.width / 2 - (root.box[0] + root.box[2] / 2) * width
        y: root.height / 2 - (root.box[1] + root.box[3] / 2) * height

        source: root.source
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        visible: !root.tinted && root.ready

        onStatusChanged: if (status === Image.Ready && root.source && !AppIcons.fitFor(root.source))
            probe.measure()
    }

    MultiEffect {
        anchors.fill: image
        source: image
        visible: root.tinted && root.ready

        brightness: 1
        colorization: 1
        colorizationColor: root.colour
    }

    Canvas {
        id: probe

        width: 64
        height: 64
        visible: false
        renderTarget: Canvas.Image

        function measure(): void {
            if (!root.source)
                return;
            if (isImageLoaded(root.source))
                requestPaint();
            else
                loadImage(root.source);
        }

        onImageLoaded: requestPaint()

        onPaint: {
            if (!isImageLoaded(root.source))
                return;

            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(root.source, 0, 0, width, height);

            const data = ctx.getImageData(0, 0, width, height).data;
            let x0 = width, y0 = height, x1 = -1, y1 = -1, opaque = 0;
            for (let y = 0; y < height; y++)
                for (let x = 0; x < width; x++) {
                    if (data[(y * width + x) * 4 + 3] > 200)
                        opaque++;

                    if (data[(y * width + x) * 4 + 3] > 24) {
                        if (x < x0)
                            x0 = x;
                        if (x > x1)
                            x1 = x;
                        if (y < y0)
                            y0 = y;
                        if (y > y1)
                            y1 = y;
                    }
                }

            if (x1 < x0 || y1 < y0)
                return;

            const w = x1 - x0 + 1;
            const h = y1 - y0 + 1;
            const measured = [x0 / width, y0 / height, w / width, h / height, opaque / (w * h)];
            root.box = measured;
            AppIcons.recordFit(root.source, measured);
        }
    }
}
