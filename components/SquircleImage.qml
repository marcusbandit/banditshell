import QtQuick
import qs.config

Item {
    id: root

    property string source: ""
    property real radius: Appearance.rounding.normal
    property int fillMode: Image.PreserveAspectCrop

    readonly property bool ready: image.status === Image.Ready

    readonly property int status: image.status
    readonly property int implicitSourceWidth: image.implicitWidth
    readonly property int implicitSourceHeight: image.implicitHeight

    property real decodeWidth: root.width
    property real decodeHeight: root.height

    readonly property real aspect: image.implicitHeight > 0 ? image.implicitWidth / image.implicitHeight : 1
    readonly property bool fitted: root.fillMode === Image.PreserveAspectFit
    readonly property real drawnWidth: root.fitted ? Math.min(root.width, root.height * root.aspect) : root.width
    readonly property real drawnHeight: root.fitted ? Math.min(root.height, root.width / root.aspect) : root.height

    readonly property vector4d crop: {
        const across = image.implicitWidth;
        const down = image.implicitHeight;
        if (root.fillMode !== Image.PreserveAspectCrop || across <= 0 || down <= 0 || root.width <= 0 || root.height <= 0)
            return Qt.vector4d(0, 0, 1, 1);
        const wide = root.width / across;
        const tall = root.height / down;
        if (wide > tall) {
            const rows = Math.floor(tall / wide * down);
            return Qt.vector4d(0, Math.ceil((down - rows) / 2) / down, 1, rows / down);
        }
        const columns = Math.floor(wide / tall * across);
        return Qt.vector4d(Math.ceil((across - columns) / 2) / across, 0, columns / across, 1);
    }

    Image {
        id: image

        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        asynchronous: true
        smooth: true
        sourceSize.width: root.decodeWidth * Screen.devicePixelRatio
        sourceSize.height: root.decodeHeight * Screen.devicePixelRatio

        visible: false
    }

    ShaderEffect {
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: root.drawnWidth
        height: root.drawnHeight
        visible: root.ready

        property var source: image
        property real corner: Math.max(0, Math.min(root.radius, width / 2, height / 2))
        property real power: Appearance.rounding.power
        property vector2d extent: Qt.vector2d(width, height)
        property vector4d crop: root.crop

        fragmentShader: Qt.resolvedUrl("squircle.frag.qsb")
    }
}
