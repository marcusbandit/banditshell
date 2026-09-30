import QtQuick
import QtQuick.Effects
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

    Image {
        id: image

        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        asynchronous: true
        smooth: true
        sourceSize.width: root.decodeWidth * Screen.devicePixelRatio
        sourceSize.height: root.decodeHeight * Screen.devicePixelRatio

        layer.enabled: true
        visible: false
    }

    SquircleRect {
        id: mask

        anchors.centerIn: parent
        width: root.drawnWidth
        height: root.drawnHeight
        radius: root.radius

        color: "white"
        layer.enabled: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: image
        maskEnabled: true
        maskSource: mask
        visible: root.ready
    }
}
