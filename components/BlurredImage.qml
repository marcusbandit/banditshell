import QtQuick
import QtQuick.Effects
import qs.config

Item {
    id: root

    property string source: ""
    property real radius: Appearance.rounding.large
    property real blur: 1
    property real saturation: 0.35
    property real brightness: 0

    property real tame: 0
    property real luminance: 0
    readonly property real light: 0.35

    property real inset: 0.14

    readonly property bool ready: picture.status === Image.Ready
    readonly property int status: picture.status

    Image {
        id: picture

        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize.width: 96
        sourceSize.height: 96
        visible: false
    }

    onSourceChanged: {
        root.luminance = 0;
        if (root.tame > 0)
            probe.measure();
    }

    Canvas {
        id: probe

        width: 8
        height: 8
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
            if (!root.source || !isImageLoaded(root.source))
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(root.source, 0, 0, width, height);
            const data = ctx.getImageData(0, 0, width, height).data;
            unloadImage(root.source);
            let sum = 0;
            for (let i = 0; i < data.length; i += 4)
                sum += (0.2126 * data[i] + 0.7152 * data[i + 1] + 0.0722 * data[i + 2]) / 255;
            root.luminance = sum / (data.length / 4);
        }
    }

    MultiEffect {
        id: blurred

        anchors.fill: parent
        source: picture
        visible: false
        autoPaddingEnabled: false

        blurEnabled: true
        blur: root.blur
        blurMax: 64
        blurMultiplier: 1
        saturation: root.saturation
        brightness: Math.max(-1, root.brightness - root.tame * Math.max(0, root.luminance - root.light))

        layer.enabled: true
        layer.smooth: true
    }

    ShaderEffect {
        anchors.fill: parent
        visible: root.ready

        property var source: blurred
        property real corner: Math.max(0, Math.min(root.radius, width / 2, height / 2))
        property real power: Appearance.rounding.power
        property vector2d extent: Qt.vector2d(width, height)
        property vector4d crop: Qt.vector4d(root.inset, root.inset, 1 - root.inset * 2, 1 - root.inset * 2)

        fragmentShader: Qt.resolvedUrl("squircle.frag.qsb")
    }
}
