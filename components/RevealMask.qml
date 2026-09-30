import QtQuick

ShaderEffect {
    id: root

    property var source

    property real progress: 1
    property real aspect: 1

    property real softness: 0.14

    property real wobble: 0.32

    property real seed: 0

    property point origin: Qt.point(0.5, 0.5)

    fragmentShader: Qt.resolvedUrl("reveal.frag.qsb")
}
