import QtQuick
import QtQuick.Effects

Item {
    id: root

    property string source: ""
    property real softBlur: 6
    property real frostBlur: 48

    readonly property bool ready: picture.status === Image.Ready && root.width > 0 && root.height > 0
    readonly property size fine: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))
    readonly property size grain: Qt.size(Math.max(1, Math.round(root.width / 4)), Math.max(1, Math.round(root.height / 4)))
    readonly property Item soft: softTexture
    readonly property Item frost: frostTexture

    Image {
        id: picture

        width: root.width
        height: root.height
        source: root.source ? (root.source.startsWith("/") ? `file://${root.source}` : root.source) : ""
        sourceSize: root.fine
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        smooth: true
        visible: false
    }

    MultiEffect {
        id: softBlur

        width: root.width
        height: root.height
        source: picture
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: Math.max(1, Math.round(root.softBlur))
        blur: 1
        visible: false
    }

    MultiEffect {
        id: frostBlur

        width: root.width
        height: root.height
        source: picture
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: Math.max(1, Math.round(root.frostBlur))
        blur: 1
        blurMultiplier: 1
        visible: false
    }

    ShaderEffectSource {
        id: softTexture

        width: root.width
        height: root.height
        sourceItem: softBlur
        textureSize: root.fine
        smooth: true
        visible: false
    }

    ShaderEffectSource {
        id: frostTexture

        width: root.width
        height: root.height
        sourceItem: frostBlur
        textureSize: root.grain
        smooth: true
        visible: false
    }
}
